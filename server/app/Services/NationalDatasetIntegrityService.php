<?php

namespace App\Services;

use App\Enums\DatasetReleaseStatus;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Throwable;

final class NationalDatasetIntegrityService
{
    private const DATASET_KEYS = ['restrictions', 'service_providers'];
    private const MAX_MANIFEST_BYTES = 1_048_576;

    /** @return array{checked_at: Carbon, rows: list<array<string, mixed>>} */
    public function verify(): array
    {
        $datasets = Dataset::query()
            ->whereIn('key', self::DATASET_KEYS)
            ->get()
            ->keyBy('key');

        return [
            'checked_at' => now(),
            'rows' => array_map(
                fn (string $key): array => $this->verifyDataset($key, $datasets->get($key)),
                self::DATASET_KEYS,
            ),
        ];
    }

    /** @return array<string, mixed> */
    private function verifyDataset(string $key, ?Dataset $dataset): array
    {
        $row = [
            'key' => $key,
            'label' => $key === 'restrictions' ? 'Restricciones nacionales' : 'Directorio de servicios',
            'version' => $dataset?->current_version,
            'expires_at' => null,
            'status' => 'NO_VERIFICADO',
            'reason' => 'No se ejecutó una comprobación para esta solicitud.',
            'dataset_id' => $dataset?->id,
        ];

        if (! $dataset) {
            return $this->withState($row, 'DATASET_AUSENTE', 'No existe un registro de este dataset en el servidor.');
        }
        if (! $dataset->enabled) {
            return $this->withState($row, 'OFF', 'El dataset está deshabilitado; la versión apuntada es histórica.');
        }
        if (! $dataset->current_version) {
            return $this->withState($row, 'SIN_RELEASE', 'El dataset habilitado no apunta a una versión actual.');
        }

        $release = $dataset->releases()
            ->where('version', $dataset->current_version)
            ->first();
        if (! $release instanceof DatasetRelease
            || (int) $release->dataset_id !== (int) $dataset->id
            || $release->status !== DatasetReleaseStatus::Published
            || ! is_string($release->asset_path)
            || $release->asset_path === ''
            || ! is_string($release->sha256)
            || ! preg_match('/^[a-f0-9]{64}$/D', $release->sha256)) {
            return $this->withState($row, 'RELEASE_INVALIDO', 'El release apuntado no cumple el contrato publicado.');
        }

        $row['version'] = $release->version;
        $row['expires_at'] = $release->expires_at;
        try {
            $disk = Storage::disk((string) config('datasets.published_disk'));
            if (! $disk->exists($release->asset_path)) {
                return $this->withState($row, 'ASSET_NO_DISPONIBLE', 'El objeto publicado no está disponible en el almacenamiento configurado.');
            }
            $stream = $disk->readStream($release->asset_path);
        } catch (Throwable) {
            return $this->withState($row, 'ERROR_LECTURA', 'No fue posible leer el objeto publicado.');
        }

        if (! is_resource($stream)) {
            return $this->withState($row, 'ERROR_LECTURA', 'No fue posible abrir el objeto publicado para lectura.');
        }

        try {
            $context = hash_init('sha256');
            $bytesRead = hash_update_stream($context, $stream);
            if (! is_int($bytesRead) || $bytesRead < 0 || ! feof($stream)) {
                return $this->withState($row, 'ERROR_LECTURA', 'La lectura del objeto publicado quedó incompleta.');
            }
            $assetHash = hash_final($context);
        } catch (Throwable) {
            return $this->withState($row, 'ERROR_LECTURA', 'No fue posible completar la lectura del objeto publicado.');
        } finally {
            fclose($stream);
        }

        if (! hash_equals($release->sha256, $assetHash)) {
            return $this->withState($row, 'HASH_INCORRECTO', 'Los bytes almacenados no coinciden con el SHA-256 del release.');
        }

        $manifestResult = $this->readManifest($disk, (string) config('datasets.manifest_path'));
        if ($manifestResult['error'] !== null) {
            return $this->withState($row, $manifestResult['error'], $manifestResult['reason']);
        }

        if (! $this->manifestMatches($manifestResult['manifest'], $key, $dataset, $release)) {
            return $this->withState($row, 'MANIFEST_NO_COINCIDE', 'El manifiesto publicado no coincide con el release, la URL o la revisión apuntados.');
        }

        if ($release->expires_at !== null && $release->expires_at->lessThanOrEqualTo(now())) {
            return $this->withState($row, 'VENCIDO', 'La fecha de expiración registrada para este release ya transcurrió.');
        }

        return $this->withState($row, 'INTEGRIDAD_LOCAL_OK', 'Integridad técnica de servidor comprobada; no acredita legalidad, entrega OTA ni datos del dispositivo.');
    }

    /** @return array{manifest: ?object, error: ?string, reason: string} */
    private function readManifest($disk, string $path): array
    {
        try {
            if (! $disk->exists($path)) {
                return ['manifest' => null, 'error' => 'MANIFEST_NO_COINCIDE', 'reason' => 'No existe el manifiesto configurado en el almacenamiento publicado.'];
            }
            $stream = $disk->readStream($path);
        } catch (Throwable) {
            return ['manifest' => null, 'error' => 'ERROR_LECTURA', 'reason' => 'No fue posible leer el manifiesto publicado.'];
        }

        if (! is_resource($stream)) {
            return ['manifest' => null, 'error' => 'ERROR_LECTURA', 'reason' => 'No fue posible abrir el manifiesto publicado para lectura.'];
        }

        try {
            $contents = stream_get_contents($stream, self::MAX_MANIFEST_BYTES + 1);
        } catch (Throwable) {
            return ['manifest' => null, 'error' => 'ERROR_LECTURA', 'reason' => 'La lectura del manifiesto publicado falló.'];
        } finally {
            fclose($stream);
        }

        if (! is_string($contents) || strlen($contents) > self::MAX_MANIFEST_BYTES) {
            return ['manifest' => null, 'error' => 'ERROR_LECTURA', 'reason' => 'El manifiesto no se pudo leer dentro del límite permitido.'];
        }

        try {
            $manifest = json_decode($contents, false, 512, JSON_THROW_ON_ERROR);
        } catch (Throwable) {
            return ['manifest' => null, 'error' => 'MANIFEST_NO_COINCIDE', 'reason' => 'El manifiesto no contiene JSON válido.'];
        }

        if (! is_object($manifest)
            || ($manifest->schemaVersion ?? null) !== 1
            || ! isset($manifest->datasets)
            || ! is_object($manifest->datasets)) {
            return ['manifest' => null, 'error' => 'MANIFEST_NO_COINCIDE', 'reason' => 'El manifiesto no cumple el esquema publicado esperado.'];
        }

        return ['manifest' => $manifest, 'error' => null, 'reason' => ''];
    }

    private function manifestMatches(object $manifest, string $key, Dataset $dataset, DatasetRelease $release): bool
    {
        $entry = $manifest->datasets->{$key} ?? null;
        if (! is_object($entry)
            || ($entry->version ?? null) !== $release->version
            || ($entry->sha256 ?? null) !== $release->sha256
            || ($entry->publicationRevision ?? null) !== (int) $dataset->publication_revision
            || ($entry->url ?? null) !== $this->publicUrl($release->asset_path)) {
            return false;
        }

        $hasManifestExpiry = property_exists($entry, 'expiresAt');
        if ($release->expires_at === null) {
            return ! $hasManifestExpiry;
        }
        if (! $hasManifestExpiry || ! is_string($entry->expiresAt) || $entry->expiresAt === '') {
            return false;
        }

        try {
            $manifestExpiry = Carbon::parse($entry->expiresAt);
        } catch (Throwable) {
            return false;
        }

        return $manifestExpiry->equalTo($release->expires_at);
    }

    private function publicUrl(string $assetPath): string
    {
        return rtrim((string) config('datasets.public_base_url'), '/').'/'.ltrim($assetPath, '/');
    }

    /** @param array<string, mixed> $row @return array<string, mixed> */
    private function withState(array $row, string $status, string $reason): array
    {
        $row['status'] = $status;
        $row['reason'] = $reason;

        return $row;
    }
}
