<section class="coverage-card rounded-lg border border-slate-200 bg-white p-5" data-coverage-index="{{ $coverageIndex }}">
    <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
            <p class="text-xs font-semibold uppercase text-teal-700">Cobertura</p>
            <h2 class="text-xl font-semibold">Vehículo y servicio</h2>
            @if($schemaVersion === 2)
                <p class="text-xs font-medium text-slate-600">Editar cobertura schema2</p>
            <p class="mt-1 text-sm text-slate-600">Completitud: <strong>{{ ($coverage['coverage_completeness'] ?? 'partial') === 'complete' ? 'complete · requiere QA espacial' : 'partial' }}</strong></p>
            @endif
        </div>
        <button class="remove-coverage min-h-12 rounded-md border border-red-200 px-3 text-sm font-medium text-red-700" type="button">Quitar cobertura</button>
    </div>
    <div class="mt-4 grid gap-4 md:grid-cols-2">
        @if($schemaVersion === 2)
            <label class="text-sm font-medium">Vehículo y servicio
                <select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="coverages[{{ $coverageIndex }}][pair]" required>
                    @foreach($pairOptions as $pair => $label)
                        <option value="{{ $pair }}" @selected(($coverage['pair'] ?? (($coverage['vehicle_kind'] ?? 'car').'|'.($coverage['service_type'] ?? 'private'))) === $pair)>{{ $label }}</option>
                    @endforeach
                </select>
            </label>
        @else
            <label class="text-sm font-medium">Tipo de vehículo
                <select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="coverages[{{ $coverageIndex }}][vehicle_kind]" required><option value="car" @selected(($coverage['vehicle_kind'] ?? '') === 'car')>Carro</option><option value="motorcycle" @selected(($coverage['vehicle_kind'] ?? '') === 'motorcycle')>Moto</option></select>
            </label>
            <label class="text-sm font-medium">Servicio
                <select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="coverages[{{ $coverageIndex }}][service_type]" required><option value="private" @selected(($coverage['service_type'] ?? '') === 'private')>Particular</option><option value="taxi" @selected(($coverage['service_type'] ?? '') === 'taxi')>Taxi</option></select>
            </label>
        @endif
        <label class="text-sm font-medium">Fecha real de revisión<input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" type="datetime-local" name="coverages[{{ $coverageIndex }}][verified_at]" value="{{ $coverage['verified_at'] ?? '' }}" required></label>
        <label class="text-sm font-medium">Revisar nuevamente antes de<input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" type="datetime-local" name="coverages[{{ $coverageIndex }}][stale_after]" value="{{ $coverage['stale_after'] ?? '' }}" required></label>
    </div>
    <label class="mt-4 block text-sm font-medium">Fuentes HTTPS de la cobertura <span class="font-normal text-slate-500">(una por línea)</span><textarea class="mt-1 min-h-24 w-full rounded-md border border-slate-300 p-3" name="coverages[{{ $coverageIndex }}][source_urls]" required>{{ $coverage['source_urls'] ?? '' }}</textarea></label>
    <div class="mt-5 flex flex-wrap items-center justify-between gap-3 border-t border-slate-200 pt-5">
        <div><p class="text-xs font-semibold uppercase text-teal-700">Reglas</p><p class="text-sm text-slate-600">Cada regla tiene vigencia, horario, placa aplicable y fuente propia.</p></div>
        <button class="add-rule min-h-12 rounded-md border border-slate-300 px-4 text-sm font-medium" type="button">Agregar regla</button>
    </div>
    <div class="rule-list mt-4 space-y-4">
        @foreach(($coverage['rules'] ?? []) as $ruleIndex => $rule)
            @include('admin.restrictions.partials.rule-fields', ['coverageIndex' => $coverageIndex, 'ruleIndex' => $ruleIndex, 'rule' => $rule, 'schemaVersion' => $schemaVersion])
        @endforeach
    </div>
    @if($schemaVersion === 2)
        <label class="mt-4 flex min-h-12 items-start gap-3 rounded-md bg-amber-50 px-3 py-3 text-sm text-amber-950">
            <input type="checkbox" class="mt-1" name="coverages[{{ $coverageIndex }}][suspend_consultation]" value="1" @checked(!empty($coverage['suspend_consultation']))>
            <span><strong>Suspender consulta de esta modalidad</strong> (solo cobertura ya existente). Publica <code>partial</code> sin reglas y la app responde <strong>desconocido</strong>, nunca “puede circular”. Requiere revisión independiente. Para reactivar, recupera o vuelve a cargar las reglas respaldadas por la fuente.</span>
        </label>
    @endif
    <label class="mt-4 flex min-h-12 items-center gap-3 rounded-md bg-amber-50 px-3 text-sm text-amber-950"><input type="checkbox" name="coverages[{{ $coverageIndex }}][confirmed_no_rules]" value="1" @checked(!empty($coverage['confirmed_no_rules']))>Confirmo que la fuente revisada no publica restricciones para esta cobertura. No marques esta opción al suspender la consulta.</label>
</section>
