<?php

namespace App\Services;

use App\Models\GeographicUnit;
use App\Models\ServiceProvider;
use App\Models\ServiceProviderImport;
use App\Models\ServiceProviderImportRow;
use App\Models\User;
use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use SplFileObject;

final class ServiceProviderBulkImportService
{
    private const MAX_ROWS = 5000;

    private const FIELDS = [
        'service_provider_id', 'category', 'department_code', 'municipality_code',
        'name', 'address', 'latitude', 'longitude', 'source_url', 'verified_at',
        'valid_until', 'contact_url',
    ];

    public function __construct(
        private readonly SafeXlsxReader $xlsx,
        private readonly ServiceProviderCatalogService $catalog,
        private readonly DatasetAuditLogger $audit,
    ) {}

    public function analyze(string $path, string $originalName, string $format, User $actor): ServiceProviderImport
    {
        Gate::forUser($actor)->authorize('service_providers.edit');
        $format = strtolower($format);
        if (! in_array($format, ['csv', 'xlsx'], true) || ! is_file($path) ||
            filesize($path) === false || filesize($path) > ((int) config('datasets.max_upload_kb') * 1024)) {
            throw new DomainException('El archivo debe ser CSV o XLSX y respetar el límite de carga.');
        }
        $sha = hash_file('sha256', $path);
        if (! is_string($sha)) {
            throw new DomainException('No fue posible calcular el hash del archivo.');
        }
        $existing = ServiceProviderImport::query()->where('sha256', $sha)->first();
        if ($existing) {
            return $existing;
        }

        $rows = $this->readRows($path, $format);
        if ($rows === [] || count($rows) > self::MAX_ROWS) {
            throw new DomainException('El archivo no contiene filas importables o supera 5.000 filas.');
        }

        $privatePath = "service-provider-imports/$sha.$format";
        $bytes = file_get_contents($path);
        if (! is_string($bytes) || Storage::disk('local')->put($privatePath, $bytes) === false) {
            throw new DomainException('No fue posible guardar el archivo en staging privado.');
        }

        return DB::transaction(function () use ($sha, $originalName, $format, $privatePath, $rows, $actor): ServiceProviderImport {
            $existing = ServiceProviderImport::query()->where('sha256', $sha)->lockForUpdate()->first();
            if ($existing) {
                return $existing;
            }

            $import = ServiceProviderImport::query()->create([
                'sha256' => $sha,
                'original_name' => basename(str_replace('\\', '/', $originalName)),
                'format' => $format,
                'private_path' => $privatePath,
                'status' => 'analyzed',
                'created_by_id' => $actor->id,
                'expires_at' => now()->addDays(7),
            ]);
            $normalizedRows = [];
            foreach ($rows as $raw) {
                $normalizedRows[] = $this->classify($raw);
            }
            $this->markFileDuplicates($normalizedRows);

            $counts = [];
            foreach ($normalizedRows as $index => $result) {
                $counts[$result['status']] = ($counts[$result['status']] ?? 0) + 1;
                $import->rows()->create([
                    'row_number' => $index + 2,
                    'status' => $result['status'],
                    'publishable' => $result['publishable'],
                    'service_provider_id' => $result['provider_id'],
                    'normalized' => $result['normalized'],
                    'errors' => $result['errors'],
                    'raw' => $result['raw'],
                ]);
            }
            $import->update([
                'row_count' => count($normalizedRows),
                'report' => ['counts' => $counts, 'syntheticFixturesAllowed' => true],
            ]);
            $this->audit->log($actor, 'service_provider_import.analyzed', $import, [
                'file_sha' => $sha,
                'format' => $format,
                'counts' => $counts,
            ]);

            return $import->refresh();
        });
    }

    /** @param list<int> $rowIds @return array{created:int,updated:int,unchanged:int,provider_ids:list<int>} */
    public function confirm(ServiceProviderImport $import, array $rowIds, User $actor): array
    {
        Gate::forUser($actor)->authorize('service_providers.edit');
        if ($rowIds === []) {
            throw new DomainException('Selecciona al menos una fila revisada.');
        }
        $rowIds = array_values(array_unique(array_map('intval', $rowIds)));

        return DB::transaction(function () use ($import, $rowIds, $actor): array {
            $locked = ServiceProviderImport::query()->lockForUpdate()->findOrFail($import->id);
            if ($locked->status === 'confirmed') {
                return $locked->report['confirmation'] ?? ['created' => 0, 'updated' => 0, 'unchanged' => 0, 'provider_ids' => []];
            }
            if ($locked->status !== 'analyzed' || ! $locked->expires_at?->isAfter(now())) {
                throw new DomainException('El staging venció o ya no se puede confirmar.');
            }

            $rows = ServiceProviderImportRow::query()
                ->where('service_provider_import_id', $locked->id)
                ->whereIn('id', $rowIds)
                ->lockForUpdate()
                ->get();
            if ($rows->count() !== count($rowIds) ||
                $rows->contains(fn (ServiceProviderImportRow $row): bool => ! $row->publishable)) {
                throw new DomainException('La selección incluye filas inválidas o ajenas a este lote.');
            }

            $totals = ['created' => 0, 'updated' => 0, 'unchanged' => 0];
            $providerIds = [];
            foreach ($rows as $row) {
                $fresh = $this->classify($row->raw);
                $expected = $row->normalized ?? [];
                if (! $fresh['publishable'] ||
                    $fresh['status'] !== $row->status ||
                    ($fresh['provider_id'] ?? null) !== ($expected['existing_provider_id'] ?? null)) {
                    throw new DomainException('El catálogo o la fuente cambió tras el análisis; vuelve a analizar el archivo.');
                }

                if ($row->status === 'NUEVA') {
                    $provider = $this->catalog->create([...$fresh['attributes'], 'status' => 'draft'], $actor);
                    $totals['created']++;
                } elseif ($row->status === 'EXISTENTE_CON_CAMBIOS') {
                    $provider = ServiceProvider::query()->lockForUpdate()->findOrFail($fresh['provider_id']);
                    if ($provider->status !== 'draft') {
                        throw new DomainException('La importación solo puede actualizar fichas draft.');
                    }
                    $provider = $this->catalog->update($provider, [...$fresh['attributes'], 'status' => 'draft'], $actor);
                    $totals['updated']++;
                } elseif ($row->status === 'SIN_CAMBIOS') {
                    $provider = $fresh['provider_id']
                        ? ServiceProvider::query()->findOrFail($fresh['provider_id'])
                        : null;
                    $totals['unchanged']++;
                } else {
                    throw new DomainException('La fila ambigua no se puede confirmar.');
                }

                if ($provider) {
                    $row->service_provider_id = $provider->id;
                    $row->save();
                    $providerIds[] = $provider->id;
                }
            }

            $summary = [...$totals, 'provider_ids' => array_values(array_unique($providerIds))];
            $report = $locked->report ?? [];
            $report['confirmation'] = $summary;
            $locked->update([
                'status' => 'confirmed',
                'confirmed_by_id' => $actor->id,
                'confirmed_at' => now(),
                'report' => $report,
            ]);
            $this->audit->log($actor, 'service_provider_import.confirmed', $locked, [
                'file_sha' => $locked->sha256,
                'actor_id' => $actor->id,
                ...$totals,
                'provider_ids' => array_values(array_unique($providerIds)),
            ]);

            return $summary;
        });
    }

    /** @return list<array<string,mixed>> */
    private function readRows(string $path, string $format): array
    {
        if ($format === 'csv') {
            $file = new SplFileObject($path, 'r');
            $file->setFlags(SplFileObject::READ_CSV | SplFileObject::SKIP_EMPTY | SplFileObject::DROP_NEW_LINE);
            $table = iterator_to_array($file, false);
        } else {
            $workbook = $this->xlsx->read($path);
            $table = $workbook['rows'][$workbook['sheets'][0]] ?? [];
        }
        if ($table === []) {
            throw new DomainException('El archivo está vacío.');
        }

        $header = array_map(static fn (mixed $value): string => strtolower(trim(preg_replace('/^\xEF\xBB\xBF/', '', (string) $value))), $table[0]);
        if (array_diff($header, self::FIELDS) !== [] || count($header) !== count(array_unique($header)) ||
            ! in_array('category', $header, true) || ! in_array('department_code', $header, true) ||
            ! in_array('municipality_code', $header, true) || ! in_array('name', $header, true)) {
            throw new DomainException('Los encabezados no son válidos o contienen columnas desconocidas/duplicadas.');
        }

        $rows = [];
        foreach (array_slice($table, 1) as $line) {
            $values = array_map(static fn (mixed $value): string => trim((string) $value), $line);
            if (count($values) === 1 && $values[0] === '') {
                continue;
            }
            if (count($values) > count($header)) {
                throw new DomainException('Una fila contiene más valores que encabezados.');
            }
            $values = array_pad($values, count($header), '');
            $rows[] = array_combine($header, array_slice($values, 0, count($header)));
        }

        return $rows;
    }

    /** @param array<string,mixed> $raw @return array{status:string,publishable:bool,provider_id:?int,normalized:array<string,mixed>,attributes:array<string,mixed>,errors:list<string>,raw:array<string,mixed>} */
    private function classify(array $raw): array
    {
        $errors = [];
        foreach (self::FIELDS as $field) {
            $value = trim((string) ($raw[$field] ?? ''));
            if (! in_array($field, ['latitude', 'longitude', 'service_provider_id'], true) &&
                preg_match('/^[\s\x00-\x20]*[=+\-@]/u', $value)) {
                $errors[] = "La columna $field contiene una expresión no permitida.";
            }
        }

        $category = trim((string) ($raw['category'] ?? ''));
        $departmentCode = trim((string) ($raw['department_code'] ?? ''));
        $municipalityCode = trim((string) ($raw['municipality_code'] ?? ''));
        $name = trim((string) ($raw['name'] ?? ''));
        if (! in_array($category, ServiceProvider::CATEGORIES, true)) {
            $errors[] = 'La categoría no está en el catálogo permitido.';
        }
        if (! preg_match('/^\d{2}$/', $departmentCode) || ! preg_match('/^\d{5}$/', $municipalityCode) ||
            substr($municipalityCode, 0, 2) !== $departmentCode) {
            $errors[] = 'Los códigos DIVIPOLA deben ser válidos y corresponder al departamento.';
        } else {
            $department = GeographicUnit::query()->where('level', 'department')->where('code', $departmentCode)->where('is_active', true)->first();
            $municipality = GeographicUnit::query()->where('level', 'municipality')->where('code', $municipalityCode)->where('is_active', true)->first();
            if (! $department || ! $municipality || $municipality->parent_id !== $department->id) {
                $errors[] = 'El municipio DIVIPOLA no existe, está inactivo o pertenece a otro departamento.';
            }
        }
        if ($name === '' || mb_strlen($name) > 160) {
            $errors[] = 'El nombre es obligatorio y admite hasta 160 caracteres.';
        }
        $address = trim((string) ($raw['address'] ?? ''));
        if (mb_strlen($address) > 240) {
            $errors[] = 'La dirección admite hasta 240 caracteres.';
        }

        $latitude = trim((string) ($raw['latitude'] ?? ''));
        $longitude = trim((string) ($raw['longitude'] ?? ''));
        if (($latitude === '') !== ($longitude === '')) {
            $errors[] = 'Latitud y longitud deben venir juntas.';
        }
        if (($latitude !== '' || $longitude !== '') &&
            (! is_numeric($latitude) || ! is_numeric($longitude) ||
                ! is_finite((float) $latitude) || ! is_finite((float) $longitude) ||
                (float) $latitude < -5 || (float) $latitude > 14 ||
                (float) $longitude < -82 || (float) $longitude > -66)) {
            $errors[] = 'Las coordenadas deben ser un par dentro del rango de Colombia.';
        }

        $sourceUrl = trim((string) ($raw['source_url'] ?? ''));
        if (! $this->isSafeHttpsUrl($sourceUrl)) {
            $errors[] = 'La fuente debe ser HTTPS, tener host válido y no incluir credenciales.';
        }
        $verifiedText = trim((string) ($raw['verified_at'] ?? ''));
        $verifiedAt = null;
        try {
            if ($verifiedText === '') {
                throw new \InvalidArgumentException;
            }
            $verifiedAt = CarbonImmutable::parse($verifiedText);
            if ($verifiedAt->isAfter(now())) {
                $errors[] = 'La fecha de verificación no puede estar en el futuro.';
            }
        } catch (\Throwable) {
            $errors[] = 'La fecha de verificación no es válida.';
        }

        $validUntilText = trim((string) ($raw['valid_until'] ?? ''));
        $validUntil = null;
        try {
            if ($validUntilText === '') {
                throw new \InvalidArgumentException;
            }
            $validUntil = CarbonImmutable::parse($validUntilText, 'America/Bogota')->toDateString();
            if ($validUntil < now()->setTimezone('America/Bogota')->toDateString()) {
                $errors[] = 'La vigencia ya terminó.';
            }
        } catch (\Throwable) {
            $errors[] = 'La fecha de vigencia no es válida.';
        }

        $contactUrl = trim((string) ($raw['contact_url'] ?? ''));
        if ($contactUrl !== '' && ! $this->isSafeContactUrl($contactUrl)) {
            $errors[] = 'El contacto debe ser HTTPS, tel: o mailto: seguro.';
        }
        $explicitId = trim((string) ($raw['service_provider_id'] ?? ''));
        if ($explicitId !== '' && filter_var($explicitId, FILTER_VALIDATE_INT) === false) {
            $errors[] = 'service_provider_id debe ser un entero.';
        }

        $attributes = [
            'category' => $category,
            'department_code' => $departmentCode,
            'municipality_code' => $municipalityCode,
            'name' => $name,
            'address' => $address === '' ? null : $address,
            'latitude' => $latitude === '' ? null : (float) $latitude,
            'longitude' => $longitude === '' ? null : (float) $longitude,
            'source_url' => $sourceUrl === '' ? null : $sourceUrl,
            'verified_at' => $verifiedAt?->toDateTimeString(),
            'valid_until' => $validUntil,
            'contact_url' => $contactUrl === '' ? null : $contactUrl,
        ];

        $provider = null;
        $nameKey = $this->normalizedName($name);
        $status = 'NUEVA';
        if ($explicitId !== '' && filter_var($explicitId, FILTER_VALIDATE_INT) !== false) {
            $provider = ServiceProvider::query()->find((int) $explicitId);
            if (! $provider || $provider->category !== $category ||
                $provider->department_code !== $departmentCode ||
                $provider->municipality_code !== $municipalityCode) {
                $errors[] = 'El ID no identifica una ficha del mismo tipo y municipio.';
                $status = 'ERROR_AMBIGUO';
            }
        } elseif (in_array($category, ServiceProvider::CATEGORIES, true) &&
            preg_match('/^\d{2}$/', $departmentCode) && preg_match('/^\d{5}$/', $municipalityCode) && $name !== '') {
            $matches = ServiceProvider::query()
                ->where('category', $category)
                ->where('department_code', $departmentCode)
                ->where('municipality_code', $municipalityCode)
                ->get()
                ->filter(fn (ServiceProvider $candidate): bool => $this->normalizedName($candidate->name) === $nameKey)
                ->values();
            if ($matches->count() > 1) {
                $errors[] = 'Hay varias fichas con la misma clave lógica; requiere revisión manual.';
                $status = 'ERROR_AMBIGUO';
            } else {
                $provider = $matches->first();
            }
        }

        if ($provider !== null && $status !== 'ERROR_AMBIGUO') {
            $status = $this->sameAttributes($provider, $attributes) ? 'SIN_CAMBIOS' : 'EXISTENTE_CON_CAMBIOS';
        }
        if ($provider?->status === 'published' && $status === 'EXISTENTE_CON_CAMBIOS') {
            $errors[] = 'Una ficha published nunca se modifica mediante importación.';
        }
        $publishable = $errors === [] && $status !== 'ERROR_AMBIGUO';
        $normalized = [
            'existing_provider_id' => $provider?->id,
            'classification' => $status,
            'attributes' => $attributes,
        ];

        return [
            'status' => $status,
            'publishable' => $publishable,
            'provider_id' => $provider?->id,
            'normalized' => $normalized,
            'attributes' => $attributes,
            'errors' => array_values(array_unique($errors)),
            'raw' => $raw,
        ];
    }

    /** @param list<array<string,mixed>> $rows */
    private function markFileDuplicates(array &$rows): void
    {
        $seen = [];
        foreach ($rows as $index => &$row) {
            $attrs = $row['attributes'];
            $key = implode('|', [$attrs['category'], $attrs['department_code'], $attrs['municipality_code'], $this->normalizedName($attrs['name'])]);
            if ($attrs['category'] === '' || $attrs['department_code'] === '' ||
                $attrs['municipality_code'] === '' || $attrs['name'] === '') {
                continue;
            }
            if (! isset($seen[$key])) {
                $seen[$key] = $index;
                continue;
            }
            $first = $seen[$key];
            if ($this->sameAttributeArrays($rows[$first]['attributes'], $attrs)) {
                $row['status'] = 'SIN_CAMBIOS';
                $row['publishable'] = false;
                $row['normalized']['classification'] = 'SIN_CAMBIOS';
                $row['normalized']['duplicate_of_row'] = $first + 2;
                $row['errors'][] = 'Duplicado exacto dentro del archivo; se conserva una sola fila.';
                continue;
            }
            foreach ([$first, $index] as $duplicateIndex) {
                $rows[$duplicateIndex]['status'] = 'ERROR_AMBIGUO';
                $rows[$duplicateIndex]['publishable'] = false;
                $rows[$duplicateIndex]['normalized']['classification'] = 'ERROR_AMBIGUO';
                $rows[$duplicateIndex]['errors'][] = 'La misma clave lógica aparece con datos distintos dentro del archivo.';
            }
        }
        unset($row);
    }

    private function sameAttributes(ServiceProvider $provider, array $attributes): bool
    {
        return $this->sameAttributeArrays($this->attributesFor($provider), $attributes);
    }

    private function sameAttributeArrays(array $left, array $right): bool
    {
        foreach (['category', 'department_code', 'municipality_code', 'name', 'address', 'latitude', 'longitude', 'source_url', 'verified_at', 'valid_until', 'contact_url'] as $field) {
            if ($this->canonicalValue($field, $left[$field] ?? null) !== $this->canonicalValue($field, $right[$field] ?? null)) {
                return false;
            }
        }

        return true;
    }

    private function attributesFor(ServiceProvider $provider): array
    {
        return [
            'category' => $provider->category,
            'department_code' => $provider->department_code,
            'municipality_code' => $provider->municipality_code,
            'name' => $provider->name,
            'address' => $provider->address,
            'latitude' => $provider->latitude,
            'longitude' => $provider->longitude,
            'source_url' => $provider->source_url,
            'verified_at' => $provider->verified_at?->toDateTimeString(),
            'valid_until' => $provider->valid_until?->toDateString(),
            'contact_url' => $provider->contact_url,
        ];
    }

    private function canonicalValue(string $field, mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        if (in_array($field, ['latitude', 'longitude'], true)) {
            return number_format((float) $value, 7, '.', '');
        }

        return (string) $value;
    }

    private function normalizedName(string $value): string
    {
        return preg_replace('/\s+/u', ' ', mb_strtolower(Str::ascii(trim($value)))) ?? '';
    }

    private function isSafeHttpsUrl(string $value): bool
    {
        $parts = parse_url($value);
        $host = is_array($parts) ? strtolower((string) ($parts['host'] ?? '')) : '';

        return filter_var($value, FILTER_VALIDATE_URL) !== false &&
            is_array($parts) &&
            strtolower((string) ($parts['scheme'] ?? '')) === 'https' &&
            $host !== '' && str_contains($host, '.') && ! isset($parts['user']) &&
            ! isset($parts['pass']) && ! filter_var($host, FILTER_VALIDATE_IP) &&
            ! in_array($host, ['localhost', 'localhost.localdomain'], true) &&
            ! str_ends_with($host, '.local');
    }

    private function isSafeContactUrl(string $value): bool
    {
        if (preg_match('/^tel:\+?[0-9(). -]{5,30}$/i', $value)) {
            return true;
        }
        if (preg_match('/^mailto:[^@\s]+@[^@\s]+\.[^@\s]+$/i', $value)) {
            return true;
        }

        return $this->isSafeHttpsUrl($value);
    }
}