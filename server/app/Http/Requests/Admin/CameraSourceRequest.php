<?php

namespace App\Http\Requests\Admin;

use App\Enums\CameraSourceType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class CameraSourceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return Gate::allows('camera_sources.edit');
    }

    public function rules(): array
    {
        return ['key' => [$this->isMethod('post') ? 'required' : 'sometimes', 'string', 'max:64', 'regex:/^[a-z0-9_-]+$/', Rule::unique('camera_sources', 'key')->ignore($this->route('source'))], 'title' => ['required', 'string', 'max:255'], 'authority' => ['required', 'string', 'max:255'], 'url' => ['required', 'url', 'max:2048'], 'source_type' => ['required', Rule::enum(CameraSourceType::class)], 'is_active' => ['required', 'boolean'], 'verified_at' => ['nullable', 'date', 'before_or_equal:now'], 'notes' => ['nullable', 'string', 'max:4000'], 'updated_at' => ['sometimes', 'date']];
    }
}
