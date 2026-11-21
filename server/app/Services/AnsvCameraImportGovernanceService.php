<?php

namespace App\Services;

use App\Enums\CameraStatus;
use App\Enums\OperatorRole;
use App\Models\AnsvCameraImport;
use App\Models\AnsvCameraImportRow;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;

class AnsvCameraImportGovernanceService
{
    public function __construct(
        private readonly CameraRegistryService $registry,
        private readonly CameraVerificationService $verification,
        private readonly DatasetAuditLogger $audit,
    ) {}

    public function approve(AnsvCameraImport $import, User $reviewer, string $notes = ''): AnsvCameraImport
    {
        $this->assertReviewer($reviewer);
        $notes = $this->notes($notes);
        $criticalReasons = $this->criticalReviewGateReasons($import);
        if ($criticalReasons !== []) {
            throw new DomainException('ANSV import has unresolved critical review gates: '.implode(', ', $criticalReasons));
        }

        return DB::transaction(function () use ($import, $reviewer, $notes, $criticalReasons): AnsvCameraImport {
            $current = AnsvCameraImport::lockForUpdate()->findOrFail($import->id);
            if ($current->status === 'approved') {
                return $current;
            }
            if (! in_array($current->status, ['analyzed', 'review_required'], true)) {
                throw new DomainException('ANSV import cannot be approved from this state.');
            }
            $current->forceFill([
                'status' => 'approved',
                'approved_at' => now(),
                'approved_by_id' => $reviewer->id,
                'rejected_at' => null,
                'rejected_by_id' => null,
                'review_notes' => $notes,
            ])->save();
            $this->audit->log($reviewer, 'ansv_camera_import.approved', $current, [
                'snapshotSha' => $current->snapshot_sha,
                'criticalReviewGates' => $criticalReasons,
            ]);

            return $current;
        });
    }

    public function reject(AnsvCameraImport $import, User $reviewer, string $notes): AnsvCameraImport
    {
        $this->assertReviewer($reviewer);
        $notes = $this->notes($notes);

        return DB::transaction(function () use ($import, $reviewer, $notes): AnsvCameraImport {
            $current = AnsvCameraImport::lockForUpdate()->findOrFail($import->id);
            if ($current->status === 'rejected') {
                return $current;
            }
            if (! in_array($current->status, ['analyzed', 'review_required'], true)) {
                throw new DomainException('ANSV import cannot be rejected from this state.');
            }
            $current->forceFill([
                'status' => 'rejected',
                'rejected_at' => now(),
                'rejected_by_id' => $reviewer->id,
                'review_notes' => $notes,
            ])->save();
            $this->audit->log($reviewer, 'ansv_camera_import.rejected', $current, [
                'snapshotSha' => $current->snapshot_sha,
            ]);

            return $current;
        });
    }

    /** @return array{submitted:int, skipped:int} */
    public function submitCandidates(AnsvCameraImport $import, User $operator): array
    {
        $this->assertOperator($operator);
        $this->assertApproved($import);
        $submitted = 0;
        $skipped = 0;
        foreach ($this->candidateRows($import) as $row) {
            $camera = $row->camera;
            if ($camera === null || ! in_array($camera->status, [CameraStatus::Draft, CameraStatus::Rejected], true)) {
                $skipped++;

                continue;
            }
            $this->registry->submit($camera, $operator);
            $camera->refresh()->forceFill(['updated_by_id' => $operator->id])->save();
            $submitted++;
        }

        return ['submitted' => $submitted, 'skipped' => $skipped];
    }

    /** @return array{verified:int, skipped:int} */
    public function verifyCandidates(AnsvCameraImport $import, User $reviewer): array
    {
        $this->assertReviewer($reviewer);
        $this->assertApproved($import);
        $verified = 0;
        $skipped = 0;
        foreach ($this->candidateRows($import) as $row) {
            $camera = $row->camera;
            if ($camera === null || $camera->status !== CameraStatus::InReview) {
                $skipped++;

                continue;
            }
            if (in_array($reviewer->id, array_filter([$camera->created_by_id, $camera->updated_by_id]), true)) {
                throw new DomainException('Four-eyes review requires a different reviewer.');
            }
            $this->verification->verify($camera, false, $reviewer, 'ANSV import governance review '.$import->snapshot_sha);
            $verified++;
        }

        return ['verified' => $verified, 'skipped' => $skipped];
    }

    /** @return array{activated:int, skipped:int} */
    public function activateCandidates(AnsvCameraImport $import, User $reviewer): array
    {
        $this->assertReviewer($reviewer);
        $this->assertApproved($import);
        $activated = 0;
        $skipped = 0;
        foreach ($this->candidateRows($import) as $row) {
            $camera = $row->camera;
            if ($camera === null || ! in_array($camera->status, [CameraStatus::Verified, CameraStatus::Inactive], true)) {
                $skipped++;

                continue;
            }
            $this->verification->activate($camera, $reviewer);
            $activated++;
        }

        return ['activated' => $activated, 'skipped' => $skipped];
    }

    /** @return list<string> */
    public function criticalReviewGateReasons(AnsvCameraImport $import): array
    {
        $report = $import->report ?? [];
        $gates = $report['reviewGates'] ?? [];
        $critical = [];
        foreach (['unknownOperationStatusCount', 'duplicateIdentityCount', 'invalidCoordinateCount', 'activeDateAnomalyCount'] as $gate) {
            if ((int) ($gates[$gate] ?? 0) > 0) {
                $critical[] = $gate;
            }
        }
        if ((bool) ($gates['emptySource'] ?? false)) {
            $critical[] = 'emptySource';
        }
        if ((bool) ($gates['missingCriticalColumns'] ?? false)) {
            $critical[] = 'missingCriticalColumns';
        }
        if ((bool) ($gates['sourceConfigurationReviewRequired'] ?? false)) {
            $critical[] = 'sourceConfigurationReviewRequired';
        }
        if ($import->rows()->where('review_state', 'REVIEW_REQUIRED')->where('active_public_candidate', true)->exists()) {
            $critical[] = 'activeRowsReviewRequired';
        }

        return array_values(array_unique($critical));
    }

    private function assertApproved(AnsvCameraImport $import): void
    {
        if ($import->fresh()->status !== 'approved') {
            throw new DomainException('ANSV import must be approved before camera lifecycle actions.');
        }
    }

    /** @return iterable<AnsvCameraImportRow> */
    private function candidateRows(AnsvCameraImport $import): iterable
    {
        return $import->rows()
            ->with('camera')
            ->where('active_public_candidate', true)
            ->where('review_state', 'OK')
            ->orderBy('id')
            ->cursor();
    }

    private function assertOperator(User $user): void
    {
        if (! $user->isActive() || ! in_array($user->role, [OperatorRole::Editor, OperatorRole::Admin, OperatorRole::SuperAdmin], true)) {
            throw new DomainException('Operator role cannot submit ANSV import candidates.');
        }
    }

    private function assertReviewer(User $user): void
    {
        if (! $user->isActive() || ! in_array($user->role, [OperatorRole::Reviewer, OperatorRole::Admin, OperatorRole::SuperAdmin], true)) {
            throw new DomainException('Reviewer role cannot approve ANSV import candidates.');
        }
    }

    private function notes(string $notes): string
    {
        $notes = trim(strip_tags($notes));
        if (mb_strlen($notes) > 1000) {
            throw new DomainException('Review notes must be at most 1000 characters.');
        }

        return $notes;
    }
}
