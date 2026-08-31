<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Gate;

class LifecycleReasonRequest extends FormRequest
{
    public function authorize(): bool
    {
        return Gate::allows($this->route()?->getName() === 'admin.cameras.reopen' ? 'cameras.reopen' : 'cameras.review');
    }

    public function rules(): array
    {
        return ['reason' => ['required', 'string', 'max:1000']];
    }
}
