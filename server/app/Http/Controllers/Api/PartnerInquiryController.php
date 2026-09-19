<?php

namespace App\Http\Controllers\Api;

use App\Enums\PartnerInquiryStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\PartnerInquiryRequest;
use App\Models\PartnerInquiry;
use App\Services\PartnerInquiryReadiness;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class PartnerInquiryController extends Controller
{
    public function __invoke(PartnerInquiryRequest $request, PartnerInquiryReadiness $readiness): JsonResponse
    {
        if (! $readiness->ready()) {
            return response()->json(['error' => ['code' => 'not_configured']], 503);
        }

        $idempotencyKey = trim((string) $request->header('Idempotency-Key'));
        if (! preg_match('/^[A-Za-z0-9._:-]{16,128}$/', $idempotencyKey)) {
            return response()->json(['error' => ['code' => 'validation_failed']], 422);
        }

        $payload = $this->normalizedPayload($request->validated());
        $idempotencyHash = hash('sha256', $idempotencyKey);
        $fingerprint = hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
        $existing = PartnerInquiry::query()->where('idempotency_hash', $idempotencyHash)->first();
        if ($existing !== null) {
            return $this->existingResponse($existing, $fingerprint);
        }

        try {
            $inquiry = DB::transaction(fn (): PartnerInquiry => PartnerInquiry::query()->create([
                'public_id' => 'pi_'.bin2hex(random_bytes(12)),
                'idempotency_hash' => $idempotencyHash,
                'request_fingerprint' => $fingerprint,
                ...$payload,
                'consented_at' => now(),
                'status' => PartnerInquiryStatus::Pending,
            ]));
        } catch (UniqueConstraintViolationException) {
            $inquiry = PartnerInquiry::query()->where('idempotency_hash', $idempotencyHash)->firstOrFail();

            return $this->existingResponse($inquiry, $fingerprint);
        }

        return $this->response($inquiry, 201);
    }

    /** @param array<string, mixed> $validated
     * @return array<string, string|null>
     */
    private function normalizedPayload(array $validated): array
    {
        return [
            'business_name' => trim($validated['businessName']),
            'contact_name' => trim($validated['contactName']),
            'email' => strtolower(trim($validated['email'])),
            'phone' => trim($validated['phone']),
            'city' => trim($validated['city']),
            'category' => $validated['category'],
            'message' => ($message = trim((string) ($validated['message'] ?? ''))) === '' ? null : $message,
            'consent_version' => $validated['consentVersion'],
        ];
    }

    private function existingResponse(PartnerInquiry $inquiry, string $fingerprint): JsonResponse
    {
        if (! hash_equals($inquiry->request_fingerprint, $fingerprint)) {
            return response()->json(['error' => ['code' => 'idempotency_conflict']], 409);
        }

        return $this->response($inquiry, 200);
    }

    private function response(PartnerInquiry $inquiry, int $status): JsonResponse
    {
        return response()->json(['data' => [
            'id' => $inquiry->public_id,
            'status' => $inquiry->status->value,
        ]], $status);
    }
}
