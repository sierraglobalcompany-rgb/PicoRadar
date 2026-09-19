<?php

namespace App\Console\Commands;

use App\Enums\PartnerInquiryStatus;
use App\Models\PartnerInquiry;
use Illuminate\Console\Command;

class PurgePartnerInquiriesCommand extends Command
{
    protected $signature = 'partner-inquiries:purge';

    protected $description = 'Delete unapproved partner inquiries after the configured retention period';

    public function handle(): int
    {
        $days = max(180, (int) config('partner_inquiries.retention_days', 180));
        $deleted = PartnerInquiry::query()
            ->where('status', '!=', PartnerInquiryStatus::Approved)
            ->where('created_at', '<', now()->subDays($days))
            ->delete();
        $this->info("Purged {$deleted} unapproved partner inquiries.");

        return self::SUCCESS;
    }
}
