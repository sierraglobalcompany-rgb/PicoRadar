<?php

namespace App\Services;

use App\Enums\CameraType;
use App\Models\Camera;
use App\Models\CameraImportItem;
use App\Models\GeographicUnit;
use App\Models\User;
use Carbon\CarbonInterface;
use DomainException;
use Illuminate\Support\Facades\DB;

/** Resolves review items without any B03 lifecycle action. */
class CameraImportResolutionService
{
    public function __construct(private readonly DatasetAuditLogger $audit) {}

    public function resolve(CameraImportItem $item, CarbonInterface $expectedUpdatedAt, string $action, array $input, ?User $actor = null): CameraImportItem
    {
        return DB::transaction(function () use ($item, $expectedUpdatedAt, $action, $input, $actor): CameraImportItem {
            $current = CameraImportItem::query()->lockForUpdate()->findOrFail($item->id);
            if (! $current->updated_at?->equalTo($expectedUpdatedAt)) {
                throw new DomainException('This import item changed after the resolution form was opened. Reload before resolving it.');
            }
            if (! in_array($current->status, ['blocked', 'ready'], true)) {
                throw new DomainException('This import item cannot be resolved in its current state.');
            }
            $run = $current->run()->firstOrFail();
            $resolution = ['action' => $action];
            if ($action === 'skip') {
                $current->forceFill(['status' => 'skipped']);
            } elseif ($action === 'allow_create') {
                $resolution['reason'] = $this->reason($input, true);
                $current->forceFill(['classification' => 'create_ready', 'status' => 'ready']);
            } elseif ($action === 'link_existing') {
                $camera = Camera::query()->findOrFail((int) ($input['camera_id'] ?? 0));
                if ($camera->source_id !== $run->source_id || $camera->jurisdiction_id !== $run->default_jurisdiction_id) {
                    throw new DomainException('The selected camera is not compatible with this import item.');
                }
                $resolution['cameraId'] = $camera->camera_id;
                $current->forceFill(['matched_camera_id' => $camera->id, 'classification' => 'noop', 'status' => 'ready']);
            } elseif ($action === 'municipality_override') {
                $unit = GeographicUnit::query()->whereKey((int) ($input['geographic_unit_id'] ?? 0))->where('level', 'municipality')->firstOrFail();
                if (! $run->defaultJurisdiction?->geographicUnits()->whereKey($unit->id)->exists()) {
                    throw new DomainException('The municipality is outside the import jurisdiction coverage.');
                }
                $payload = $current->normalized_payload;
                $payload['municipality_code'] = $unit->code;
                $payload['municipality_name'] = $unit->name;
                $resolution['geographicUnitId'] = $unit->id;
                $current->forceFill(['normalized_payload' => $payload, 'classification' => 'create_ready', 'status' => 'ready']);
            } elseif ($action === 'type_override') {
                $type = (string) ($input['type'] ?? '');
                if (! in_array($type, array_map(fn (CameraType $case) => $case->value, CameraType::cases()), true)) {
                    throw new DomainException('The selected camera type is invalid.');
                }
                $payload = $current->normalized_payload;
                $payload['type'] = $type;
                $resolution['type'] = $type;
                $current->forceFill(['normalized_payload' => $payload, 'classification' => 'create_ready', 'status' => 'ready']);
            } elseif ($action === 'choose_canonical_file_row') {
                $selected = CameraImportItem::query()->where('run_id', $run->id)->where('analysis_generation', $run->analysis_generation)->where('external_id', $current->external_id)->where('row_number', (int) ($input['row_number'] ?? 0))->lockForUpdate()->firstOrFail();
                $selected->forceFill(['classification' => 'create_ready', 'status' => 'ready', 'errors' => null, 'resolution' => ['action' => $action], 'resolved_by_id' => $actor?->id, 'resolved_at' => now()])->save();
                CameraImportItem::query()->where('run_id', $run->id)->where('analysis_generation', $run->analysis_generation)->where('external_id', $current->external_id)->whereKeyNot($selected->id)->update(['classification' => 'duplicate_review', 'status' => 'blocked']);

                return $selected;
            } else {
                throw new DomainException('Unsupported import resolution action.');
            }
            $current->forceFill(['resolution' => $resolution, 'resolved_by_id' => $actor?->id, 'resolved_at' => now()])->save();
            $this->audit->log($actor, 'camera_import.item_resolved', $current, ['runId' => $run->id, 'rowNumber' => $current->row_number, 'action' => $action]);

            return $current;
        });
    }

    public function skip(CameraImportItem $item, CarbonInterface $expectedUpdatedAt, ?User $actor = null): CameraImportItem
    {
        return $this->resolve($item, $expectedUpdatedAt, 'skip', [], $actor);
    }

    private function reason(array $input, bool $required): ?string
    {
        $reason = trim(strip_tags((string) ($input['reason'] ?? '')));
        if (($required && $reason === '') || mb_strlen($reason) > 1000) {
            throw new DomainException('A non-empty plain-text reason of at most 1000 characters is required.');
        }

        return $reason ?: null;
    }
}
