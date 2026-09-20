<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Dataset;
use App\Models\Jurisdiction;
use App\Models\RestrictionImport;
use App\Models\RestrictionPublication;
use App\Models\RestrictionRuleVersion;
use App\Services\RestrictionFormPayloadBuilder;
use App\Services\RestrictionImportService;
use App\Services\RestrictionPublicationService;
use App\Services\RestrictionRuleVersionService;
use DomainException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\StreamedResponse;

class RestrictionRuleController extends Controller
{
    public function index(Request $request)
    {
        Gate::authorize('datasets.view');

        return view('admin.restrictions.index', [
            'operator' => $request->user(),
            'jurisdictions' => Jurisdiction::query()->where('enabled', true)->with(['restrictionRuleVersions' => fn ($query) => $query->latest('version')])->orderBy('name')->get(),
            'dataset' => Dataset::query()->where('key', 'restrictions')->first(),
        ]);
    }

    public function create(Request $request)
    {
        Gate::authorize('datasets.edit');

        return view('admin.restrictions.form', ['operator' => $request->user(), 'jurisdictions' => Jurisdiction::query()->where('enabled', true)->orderBy('name')->get(), 'version' => null]);
    }

    public function store(Request $request, RestrictionRuleVersionService $service, RestrictionFormPayloadBuilder $builder): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $data = $request->validate([
            'jurisdiction_id' => ['required', 'integer', 'exists:jurisdictions,id'],
            'coverages' => ['required', 'array', 'min:1', 'max:8'],
            'coverages.*' => ['required', 'array'],
            'coverages.*.rules' => ['present', 'array', 'max:1000'],
        ]);
        $jurisdiction = Jurisdiction::query()->where('enabled', true)->findOrFail($data['jurisdiction_id']);
        try {
            $payload = $builder->build($jurisdiction, ['coverages' => $request->input('coverages')]);
        } catch (DomainException $error) {
            throw ValidationException::withMessages(['coverages' => $error->getMessage()]);
        }
        $version = $service->createDraft($jurisdiction, $payload, $request->user());

        return redirect()->route('admin.restrictions.edit', $version);
    }

    public function edit(Request $request, RestrictionRuleVersion $version)
    {
        Gate::authorize('datasets.view');

        return view('admin.restrictions.form', ['operator' => $request->user(), 'jurisdictions' => collect([$version->jurisdiction]), 'version' => $version, 'editable' => Gate::allows('datasets.edit')]);
    }

    public function update(Request $request, RestrictionRuleVersion $version, RestrictionRuleVersionService $service, RestrictionFormPayloadBuilder $builder): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $request->validate([
            'coverages' => ['required', 'array', 'min:1', 'max:8'],
            'coverages.*' => ['required', 'array'],
            'coverages.*.rules' => ['present', 'array', 'max:1000'],
        ]);
        try {
            $payload = $builder->build($version->jurisdiction, ['coverages' => $request->input('coverages')]);
            $service->updateDraft($version, $payload, $request->user());
        } catch (DomainException $error) {
            return back()->withInput()->withErrors(['coverages' => $error->getMessage()]);
        }

        return back();
    }

    public function duplicate(Request $request, RestrictionRuleVersion $version, RestrictionRuleVersionService $service): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $copy = $service->duplicate($version, $request->user());

        return redirect()->route('admin.restrictions.edit', $copy);
    }

    public function validateVersion(Request $request, RestrictionRuleVersion $version, RestrictionRuleVersionService $service): RedirectResponse
    {
        Gate::authorize('datasets.review');
        try {
            $service->validate($version, $request->user());
        } catch (DomainException $error) {
            return back()->withErrors(['version' => $error->getMessage()]);
        }

        return back();
    }

    public function archive(Request $request, RestrictionRuleVersion $version, RestrictionRuleVersionService $service): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $service->archive($version, $request->user());

        return back();
    }

    public function importForm(Request $request)
    {
        Gate::authorize('datasets.edit');

        return view('admin.restrictions.import', ['operator' => $request->user(), 'imports' => RestrictionImport::query()->latest('id')->limit(20)->get()]);
    }

    public function analyzeImport(Request $request, RestrictionImportService $service): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $request->validate(['file' => ['required', 'file', 'max:'.config('datasets.max_upload_kb')], 'sheet' => ['nullable', 'string', 'max:128']]);
        $file = $request->file('file');
        $format = strtolower($file->getClientOriginalExtension());
        try {
            $import = $service->analyze($file->getRealPath(), $file->getClientOriginalName(), $format, $request->string('sheet')->trim()->value() ?: null, $request->user());
        } catch (DomainException $error) {
            throw ValidationException::withMessages(['file' => $error->getMessage()]);
        }

        return redirect()->route('admin.restrictions.imports.review', $import);
    }

    public function reviewImport(Request $request, RestrictionImport $import)
    {
        Gate::authorize('datasets.edit');

        return view('admin.restrictions.import-review', ['operator' => $request->user(), 'import' => $import->load(['rows.jurisdiction'])]);
    }

    public function confirmImport(Request $request, RestrictionImport $import, RestrictionImportService $service): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $data = $request->validate(['rows' => ['required', 'array', 'min:1'], 'rows.*' => ['integer']]);
        try {
            $service->confirm($import, array_map('intval', $data['rows']), $request->user());
        } catch (DomainException $error) {
            return back()->withErrors(['rows' => $error->getMessage()]);
        }

        return redirect()->route('admin.restrictions.index');
    }

    public function publicationPreview(Request $request)
    {
        Gate::authorize('datasets.review');
        $data = $request->validate(['versions' => ['required', 'array', 'min:1'], 'versions.*' => ['integer', 'exists:restriction_rule_versions,id']]);
        $dataset = Dataset::query()->where('key', 'restrictions')->firstOrFail();

        return view('admin.restrictions.publish', [
            'operator' => $request->user(),
            'dataset' => $dataset,
            'versions' => RestrictionRuleVersion::query()->with('jurisdiction')->whereIn('id', $data['versions'])->get(),
        ]);
    }

    public function publish(Request $request, RestrictionPublicationService $service): RedirectResponse
    {
        Gate::authorize('datasets.review');
        $data = $request->validate(['versions' => ['required', 'array', 'min:1'], 'versions.*' => ['integer'], 'publication_revision' => ['required', 'integer', 'min:0']]);
        try {
            $service->publish(array_map('intval', $data['versions']), (int) $data['publication_revision'], $request->user());
        } catch (DomainException $error) {
            return back()->withErrors(['publication' => $error->getMessage()]);
        }

        return redirect()->route('admin.restrictions.history');
    }

    public function history(Request $request)
    {
        Gate::authorize('datasets.view');

        return view('admin.restrictions.history', [
            'operator' => $request->user(),
            'publications' => RestrictionPublication::query()->with(['datasetRelease', 'actor', 'items.jurisdiction', 'items.ruleVersion'])->latest('id')->paginate(30),
            'dataset' => Dataset::query()->where('key', 'restrictions')->first(),
        ]);
    }

    public function rollback(Request $request, RestrictionRuleVersion $version, RestrictionPublicationService $service): RedirectResponse
    {
        Gate::authorize('datasets.review');
        $data = $request->validate(['publication_revision' => ['required', 'integer', 'min:0']]);
        try {
            $service->rollbackCity($version, (int) $data['publication_revision'], $request->user());
        } catch (DomainException $error) {
            return back()->withErrors(['rollback' => $error->getMessage()]);
        }

        return redirect()->route('admin.restrictions.history');
    }

    public function template(): Response
    {
        Gate::authorize('datasets.edit');
        $headers = ['jurisdiction_id', 'jurisdiction_name', 'vehicle_kind', 'service_type', 'rule_id', 'priority', 'effect', 'valid_from', 'valid_until', 'weekdays', 'date_parity', 'digit_position', 'digits', 'time_windows', 'applies_on_holidays', 'source_url', 'verified_at', 'stale_after', 'publish'];

        return response(implode(',', $headers)."\n", 200, ['Content-Type' => 'text/csv; charset=UTF-8', 'Content-Disposition' => 'attachment; filename="restriction-rules-template.csv"']);
    }

    public function report(RestrictionImport $import): StreamedResponse
    {
        Gate::authorize('datasets.view');

        return response()->streamDownload(function () use ($import): void {
            $stream = fopen('php://output', 'wb');
            fputcsv($stream, ['row', 'state', 'publishable', 'jurisdiction', 'errors'], ',', '"', '');
            foreach ($import->rows()->with('jurisdiction')->orderBy('row_number')->cursor() as $row) {
                $values = [$row->row_number, $row->state, $row->publishable ? 'yes' : 'no', $row->jurisdiction?->key ?? '', implode(' | ', $row->errors ?? [])];
                fputcsv($stream, array_map($this->spreadsheetSafe(...), $values), ',', '"', '');
            }
            fclose($stream);
        }, "restriction-import-{$import->id}-report.csv", ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    private function spreadsheetSafe(mixed $value): string
    {
        $value = (string) $value;

        return preg_match('/^[=+\-@\t\r]/', $value) ? "'$value" : $value;
    }
}
