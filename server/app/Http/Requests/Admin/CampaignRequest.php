<?php

namespace App\Http\Requests\Admin;

use App\Enums\CampaignScope;
use App\Services\CampaignAccess;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CampaignRequest extends FormRequest
{
    public function authorize(): bool
    {
        app(CampaignAccess::class)->authorizeEdit($this->user());

        return true;
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        $imageRequired = $this->isMethod('post') ? 'required' : 'nullable';

        return [
            'sponsor_id' => [
                'required',
                'integer',
                Rule::exists('sponsors', 'id')->where('status', 'active'),
            ],
            'eyebrow' => ['required', 'string', 'max:80'],
            'title' => ['required', 'string', 'max:120'],
            'subtitle' => ['required', 'string', 'max:240'],
            'cta_text' => ['required', 'string', 'max:64'],
            'cta_url' => ['required', 'url:https', 'max:2048'],
            'placement' => ['required', Rule::in([config('campaigns.placement')])],
            'priority' => ['required', 'integer', 'between:0,1000'],
            'scope' => ['required', Rule::enum(CampaignScope::class)],
            'geographic_unit_id' => ['nullable', 'integer', 'exists:geographic_units,id'],
            'starts_at' => ['required', 'date'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
            'image' => [
                $imageRequired,
                'file',
                'mimes:jpg,jpeg,png,webp',
                'max:'.(int) ceil(config('campaigns.max_image_bytes') / 1024),
                'dimensions:min_width='.config('campaigns.min_image_width')
                    .',min_height='.config('campaigns.min_image_height')
                    .',max_width='.config('campaigns.max_image_width')
                    .',max_height='.config('campaigns.max_image_height'),
            ],
        ];
    }
}
