<?php

declare(strict_types=1);

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\CameraCsvImport;
use App\Models\CameraSource;
use App\Models\Jurisdiction;
use App\Services\CameraCsvImportService;
use App\Services\CameraCsvParser;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;
use InvalidArgumentException;

final class CameraCsvImportController extends Controller
{
    public function index(Request $request)
    {
        Gate::authorize('cameras.view');

        return view('admin.camera-imports.index', [
            'operator' => $request->user(),
            'batches' => CameraCsvImport::query()
                ->with(['source', 'jurisdiction'])
                ->latest('id')->paginate(20),
        ]);
    }

    public function create(Request $request)
    {
        Gate::authorize('cameras.edit');

        return view('admin.camera-imports.create', [
            'operator' => $request->user(),
            'sources' => CameraSource::query()->where('is_active', true)
                ->whereNotNull('verified_at')->orderBy('title')->get(),
            'jurisdictions' => Jurisdiction::query()->where('enabled', true)
                ->orderBy('name')->get(),
        ]);
    }

    public function store(Request $request, CameraCsvImportService $imports): RedirectResponse
    {
        Gate::authorize('cameras.edit');
        $data = $request->validate([
            'source_id' => ['required', 'integer', Rule::exists('camera_sources', 'id')->where('is_active', 1)->whereNotNull('verified_at')],
            'jurisdiction_id' => ['required', 'integer', Rule::exists('jurisdictions', 'id')->where('enabled', 1)],
            'mode' => ['required', Rule::in(['snapshot', 'delta'])],
            'csv' => ['required', 'file', 'max:5120'],
        ]);
        try {
            $batch = $imports->create(
                $request->file('csv'),
                CameraSource::query()->findOrFail($data['source_id']),
                Jurisdiction::query()->findOrFail($data['jurisdiction_id']),
                $data['mode'], $request->user()
            );
        } catch (InvalidArgumentException $error) {
            return back()->withErrors(['csv' => $error->getMessage()])->withInput($request->except('csv'));
        }

        return redirect()->route('admin.camera-csv-imports.show', $batch)
            ->with('status', 'CSV analyzed. No camera has been changed.');
    }

    public function show(Request $request, CameraCsvImport $batch, CameraCsvImportService $imports)
    {
        Gate::authorize('cameras.view');
        $data = $imports->load($batch);
        $comparison = null;
        if ($request->filled('compare')) {
            $other = CameraCsvImport::query()
                ->whereKey($request->integer('compare'))
                ->where('source_id', $batch->source_id)
                ->where('jurisdiction_id', $batch->jurisdiction_id)
                ->firstOrFail();
            $old = $imports->load($other);
            $a = collect($data['preview']['rows'])->mapWithKeys(
                fn (array $row): array => isset($row['values']['external_id'])
                    ? [$row['values']['external_id'] => $row['values']]
                    : []
            );
            $z = collect($old['preview']['rows'])->mapWithKeys(
                fn (array $row): array => isset($row['values']['external_id'])
                    ? [$row['values']['external_id'] => $row['values']]
                    : []
            );
            $comparison = [
                'other' => $other,
                'new' => $a->keys()->diff($z->keys())->count(),
                'missing_advisory' => $z->keys()->diff($a->keys())->count(),
                'changed' => $a->keys()->intersect($z->keys())->filter(
                    fn ($key): bool => $a[$key] !== $z[$key]
                )->count(),
            ];
        }

        return view('admin.camera-imports.show', [
            'operator' => $request->user(),
            'batch' => $batch->load(['source', 'jurisdiction']),
            'analysis' => $data['preview'],
            'compareOptions' => CameraCsvImport::query()
                ->whereKeyNot($batch->id)
                ->where('source_id', $batch->source_id)
                ->where('jurisdiction_id', $batch->jurisdiction_id)
                ->latest('id')->limit(30)->get(['id', 'created_at']),
            'comparison' => $comparison,
        ]);
    }

    public function apply(Request $request, CameraCsvImport $batch, CameraCsvImportService $imports): RedirectResponse
    {
        Gate::authorize('cameras.edit');
        Gate::authorize('cameras.review');
        $validated = $request->validate([
            'analysis_sha256' => ['required', 'string', 'regex:/^[a-f0-9]{64}$/D'],
            'records' => ['required', 'array', 'min:1', 'max:2000'],
            'records.*' => ['required', 'integer', 'min:2'],
        ]);

        $outcome = $imports->apply($batch, $validated['records'], $validated['analysis_sha256'], $request->user());

        return redirect()->route('admin.camera-csv-imports.show', $batch)->with(
            'status',
            $outcome['already_applied']
                ? 'This CSV batch was already applied; no duplicate work.'
                : 'Applied: '.$outcome['created'].' drafts created, '.$outcome['updated'].' drafts updated. Nothing published.'
        );
    }

    public function template(Request $request)
    {
        Gate::authorize('cameras.edit');
        $header = 'external_id,municipality_code,lat,lon,type,name,direction,bearing,corridor,speed_limit,notes'."\r\n";

        return response($header, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="picoradar-camera-template.csv"',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    public function report(Request $request, CameraCsvImport $batch, CameraCsvImportService $imports)
    {
        Gate::authorize('cameras.view');
        $analysis = $imports->load($batch)['preview'];
        $stream = fopen('php://temp', 'w+');
        if ($stream === false) {
            abort(500);
        }
        fputcsv($stream, ['record', 'status', 'external_id', 'municipality_code', 'lat', 'lon', 'type', 'errors'], ',', '"', '');
        foreach ($analysis['rows'] as $row) {
            $values = $row['values'];
            $cells = [
                (string) $row['record'],
                $row['status'],
                $values['external_id'] ?? '',
                isset($values['municipality_code']) ? "'".$values['municipality_code'] : '',
                $values['lat'] ?? '',
                $values['lon'] ?? '',
                $values['type'] ?? '',
                implode('; ', $row['errors']),
            ];
            $safeCells = array_map(
                static fn ($v): string => CameraCsvParser::spreadsheetSafe((string) $v),
                $cells
            );
            // Numeric-only external IDs are TEXTUAL identities. Preserve
            // leading zeroes and long IDs in spreadsheet applications.
            if (preg_match('/^\\d+$/D', (string) $cells[2])) {
                $safeCells[2] = "'".$cells[2];
            }
            // Latitude and longitude are already validated and normalized by
            // CameraCsvParser. Preserve canonical signed decimals as numbers
            // while still escaping formula-looking free-text/identity cells.
            foreach ([4, 5] as $coordinateIndex) {
                $coordinate = (string) $cells[$coordinateIndex];
                if (preg_match('/^-?\\d+\\.\\d{7}$/D', $coordinate)) {
                    $safeCells[$coordinateIndex] = $coordinate;
                }
            }
            fputcsv($stream, $safeCells, ',', '"', '');
        }
        rewind($stream);
        $csv = stream_get_contents($stream);
        fclose($stream);

        return response($csv, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="camera-import-'.$batch->id.'-report.csv"',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}
