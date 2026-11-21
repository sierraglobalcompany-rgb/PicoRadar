<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Gate;

class CameraVerificationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return Gate::allows('cameras.review');
    }

    public function rules(): array
    {
        return ['speed_limit_verified' => ['nullable', 'boolean'], 'notes' => ['nullable', 'string', 'max:1000']];
    }
}
