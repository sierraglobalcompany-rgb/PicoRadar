<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['ansv_camera_import_id', 'camera_id', 'source_row_identity', 'codigo_solicitud', 'codigo_unico', 'operation_status', 'department', 'municipality', 'address', 'lat', 'lon', 'traffic_authority', 'jurisdiction_label', 'raw_infraction_codes', 'raw_speed', 'reported_speed_kmh', 'technology', 'installation_type', 'equipment_name', 'approval_date', 'operation_started_on', 'operation_initial_ends_on', 'operation_extension_ends_on', 'valid_colombia_coordinates', 'active_public_candidate', 'review_state', 'review_reasons', 'source_delta', 'raw'])]
class AnsvCameraImportRow extends Model
{
    protected function casts(): array
    {
        return ['raw_infraction_codes' => 'array', 'approval_date' => 'date', 'operation_started_on' => 'date', 'operation_initial_ends_on' => 'date', 'operation_extension_ends_on' => 'date', 'valid_colombia_coordinates' => 'boolean', 'active_public_candidate' => 'boolean', 'review_reasons' => 'array', 'source_delta' => 'array', 'raw' => 'array'];
    }

    public function import(): BelongsTo
    {
        return $this->belongsTo(AnsvCameraImport::class, 'ansv_camera_import_id');
    }

    public function camera(): BelongsTo
    {
        return $this->belongsTo(Camera::class);
    }
}
