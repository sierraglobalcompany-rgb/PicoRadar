<?php

namespace App\Http\Requests\Admin;

use App\Enums\CameraType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class CameraRequest extends FormRequest
{
    public function authorize(): bool
    {
        return Gate::allows('cameras.edit');
    }

    public function rules(): array
    {
        $externalId = Rule::unique('cameras', 'external_id')->where(fn ($query) => $query->where('source_id', $this->input('source_id')))->ignore($this->route('camera'));

        return ['jurisdiction_id' => ['required', Rule::exists('jurisdictions', 'id')], 'geographic_unit_id' => ['required', Rule::exists('geographic_units', 'id')], 'source_id' => ['required', Rule::exists('camera_sources', 'id')], 'external_id' => ['nullable', 'string', 'max:255', $externalId], 'name' => ['nullable', 'string', 'max:255'], 'lat' => ['required', 'numeric', 'between:-90,90'], 'lon' => ['required', 'numeric', 'between:-180,180'], 'type' => ['required', Rule::enum(CameraType::class)], 'direction' => ['nullable', 'string', 'max:255'], 'bearing' => ['nullable', 'integer', 'between:0,359'], 'corridor' => ['nullable', 'string', 'max:255'], 'speed_limit' => ['nullable', 'integer', 'between:1,200'], 'notes' => ['nullable', 'string', 'max:4000'], 'updated_at' => ['sometimes', 'date']];
    }
}
