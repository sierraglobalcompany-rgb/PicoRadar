<?php

namespace App\Http\Requests\Admin;

use App\Services\CampaignAccess;
use Illuminate\Foundation\Http\FormRequest;

class SponsorRequest extends FormRequest
{
    public function authorize(): bool
    {
        app(CampaignAccess::class)->authorizeEdit($this->user());

        return true;
    }

    /** @return array<string, list<string>> */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'contact_name' => ['nullable', 'string', 'max:255'],
            'contact_email' => ['nullable', 'email:rfc', 'max:320'],
            'contact_phone' => ['nullable', 'string', 'max:64'],
            'notes' => ['nullable', 'string', 'max:4000'],
        ];
    }
}
