<?php

namespace App\Http\Controllers\Admin;

use App\Enums\PartnerInquiryStatus;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\PartnerInquiry;
use App\Services\DatasetAuditLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class PartnerInquiryController extends Controller
{
    public function index(Request $request): View
    {
        Gate::authorize('partner_inquiries.view');
        $query = PartnerInquiry::query();
        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        return view('admin.partner-inquiries.index', [
            'operator' => $request->user(),
            'inquiries' => $query->latest('id')->paginate(50)->withQueryString(),
            'statuses' => PartnerInquiryStatus::cases(),
        ]);
    }

    public function audit(Request $request): View
    {
        Gate::authorize('partner_inquiries.view');

        return view('admin.partner-inquiries.audit', [
            'operator' => $request->user(),
            'logs' => AuditLog::query()
                ->with('actor')
                ->where('subject_type', PartnerInquiry::class)
                ->latest('id')
                ->paginate(50),
        ]);
    }

    public function updateStatus(
        Request $request,
        PartnerInquiry $inquiry,
        DatasetAuditLogger $audit,
    ): RedirectResponse {
        Gate::authorize('partner_inquiries.update');
        $validated = $request->validate([
            'status' => ['required', Rule::enum(PartnerInquiryStatus::class)],
        ]);
        $from = $inquiry->status;
        $to = PartnerInquiryStatus::from($validated['status']);
        if ($from !== $to) {
            $inquiry->status = $to;
            $inquiry->save();
            $audit->log($request->user(), 'partner_inquiry.status_changed', $inquiry, [
                'from' => $from->value,
                'publicId' => $inquiry->public_id,
                'to' => $to->value,
            ]);
        }

        return back();
    }
}
