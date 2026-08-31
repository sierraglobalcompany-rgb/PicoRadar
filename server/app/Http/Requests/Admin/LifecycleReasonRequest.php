<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Gate;

class LifecycleReasonRequest extends FormRequest
{
    public function authorize(): bool
    {
        return Gate::allows(in_array($this->route()?->getName(), ['admin.cameras.reject'], true) ? 'cameras.review' : 'cameras.edit');
    }

    public function rules(): array
    {
        return ['reason' => ['required', 'string', 'max:1000']];
    }
}
