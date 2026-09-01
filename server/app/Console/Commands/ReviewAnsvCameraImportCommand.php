<?php

namespace App\Console\Commands;

use App\Models\AnsvCameraImport;
use App\Models\User;
use App\Services\AnsvCameraImportGovernanceService;
use Illuminate\Console\Command;

class ReviewAnsvCameraImportCommand extends Command
{
    protected $signature = 'picoradar:ansv:cameras:review {import : ANSV import ID} {--approve} {--reject} {--submit} {--verify} {--activate} {--operator-id=} {--reviewer-id=} {--notes=} {--json}';

    protected $description = 'Approve and move ANSV camera imports through the B03 camera lifecycle.';

    public function handle(AnsvCameraImportGovernanceService $governance): int
    {
        $import = AnsvCameraImport::query()->findOrFail((int) $this->argument('import'));
        $reviewer = $this->user((string) $this->option('reviewer-id'));
        $operator = $this->option('operator-id') ? $this->user((string) $this->option('operator-id')) : $reviewer;
        $summary = [
            'schema' => 'picoradar.ansv-camera-import-review.v1',
            'importId' => $import->id,
            'snapshotSha' => $import->snapshot_sha,
        ];

        if ($this->option('approve')) {
            $import = $governance->approve($import, $reviewer, (string) $this->option('notes'));
            $summary['approved'] = true;
        }
        if ($this->option('reject')) {
            $import = $governance->reject($import, $reviewer, (string) $this->option('notes'));
            $summary['rejected'] = true;
        }
        if ($this->option('submit')) {
            $summary['submit'] = $governance->submitCandidates($import, $operator);
        }
        if ($this->option('verify')) {
            $summary['verify'] = $governance->verifyCandidates($import, $reviewer);
        }
        if ($this->option('activate')) {
            $summary['activate'] = $governance->activateCandidates($import, $reviewer);
        }
        $summary['status'] = $import->fresh()->status;

        $output = json_encode($summary, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
        $this->line((bool) $this->option('json') ? $output : "ANSV import {$import->id}: {$summary['status']}");

        return self::SUCCESS;
    }

    private function user(string $id): User
    {
        if ($id === '') {
            throw new \DomainException('A reviewer ID is required.');
        }

        return User::query()->findOrFail((int) $id);
    }
}
