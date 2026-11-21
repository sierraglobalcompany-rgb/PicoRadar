<?php

namespace App\Services;

class PartnerInquiryReadiness
{
    public function ready(): bool
    {
        $appUrl = parse_url((string) config('app.url'));
        $privacyUrl = parse_url((string) config('partner_inquiries.privacy_url'));
        $localOverride = app()->environment(['local', 'testing'])
            && (bool) config('partner_inquiries.allow_insecure_local');
        $localHttp = $localOverride
            && ($appUrl['scheme'] ?? null) === 'http'
            && in_array(strtolower((string) ($appUrl['host'] ?? '')), ['localhost', '127.0.0.1', '::1', '[::1]'], true);

        return (bool) config('partner_inquiries.enabled')
            && (bool) config('partner_inquiries.admin_inbox_enabled')
            && trim((string) config('partner_inquiries.privacy_version')) !== ''
            && isset($privacyUrl['scheme'], $privacyUrl['host'])
            && $privacyUrl['scheme'] === 'https'
            && isset($appUrl['scheme'], $appUrl['host'])
            && ($appUrl['scheme'] === 'https' || $localHttp);
    }
}
