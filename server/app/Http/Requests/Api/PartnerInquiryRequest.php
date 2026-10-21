<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PartnerInquiryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'businessName' => ['required', 'string', 'min:2', 'max:120'],
            'contactName' => ['required', 'string', 'min:2', 'max:120'],
            'email' => ['required', 'string', 'email:rfc', 'max:254'],
            'phone' => ['required', 'string', 'regex:/^[0-9+() .-]{7,24}$/'],
            'city' => ['required', 'string', 'min:2', 'max:120'],
            'category' => ['required', Rule::in(['automotor', 'insurance', 'appraisal', 'workshop', 'cda', 'other'])],
            'message' => ['nullable', 'string', 'max:1000'],
            'consentAccepted' => ['required', 'accepted'],
            'consentVersion' => ['required', 'string', Rule::in([(string) config('partner_inquiries.privacy_version')])],
            'plate' => ['prohibited'],
            'gps' => ['prohibited'],
            'latitude' => ['prohibited'],
            'longitude' => ['prohibited'],
            'documents' => ['prohibited'],
            'attachments' => ['prohibited'],
        ];
    }
}
