# PicoRadar RC1 — parche del panel schema2 (evidencia de código)

BASE HEAD: `15948a50332589ff3d1fb3157b6976809fe5a680` · TREE: `8e0b8cd1de0607e9baeeffcfac93c8f141afb67f`.

SHA-256 del parche raw: `038524ce89b02c169fb244a049f84352aa4be3bf73ce26a8a98dfc729b2ac19d`.

Código **pendiente de ejecución PHPUnit**: PHP lint y git diff --check PASS local. El parche pertenece a ZIP `PICORADAR_RC1_SCHEMA2_ADMIN_PATCH_Y_ORDEN.zip`. No aplicado al código remoto; ejecutar en clon aislado después de `git apply --check`.

```diff
diff --git a/server/app/Http/Controllers/Admin/RestrictionRuleController.php b/server/app/Http/Controllers/Admin/RestrictionRuleController.php
index 6c61b60..7bca4dd 100644
--- a/server/app/Http/Controllers/Admin/RestrictionRuleController.php
+++ b/server/app/Http/Controllers/Admin/RestrictionRuleController.php
@@ -112,12 +112,26 @@ public function edit(Request $request, RestrictionRuleVersion $version)
     {
         Gate::authorize('datasets.view');
 
-        return view('admin.restrictions.form', ['operator' => $request->user(), 'jurisdictions' => collect([$version->jurisdiction]), 'version' => $version, 'editable' => Gate::allows('datasets.edit')]);
+        return view('admin.restrictions.form', [
+            'operator' => $request->user(),
+            'jurisdictions' => collect([$version->jurisdiction]),
+            'version' => $version,
+            'editable' => Gate::allows('datasets.edit')
+                && $version->status === \App\Enums\RestrictionRuleVersionStatus::Draft
+                && ($version->payload['schemaVersion'] ?? 1) === 1,
+        ]);
     }
 
     public function update(Request $request, RestrictionRuleVersion $version, RestrictionRuleVersionService $service, RestrictionFormPayloadBuilder $builder): RedirectResponse
     {
         Gate::authorize('datasets.edit');
+        // This legacy form cannot round-trip schema2 coverage/conditions safely.
+        // Preserve the draft unchanged; schema2 edits use the JSON import path.
+        if (($version->payload['schemaVersion'] ?? 1) !== 1) {
+            return back()->withErrors([
+                'version' => 'Este borrador schema2 no se puede editar con el formulario legado. Importa un JSON schema2 para conservar coberturas y condiciones.',
+            ]);
+        }
         $request->validate([
             'coverages' => ['required', 'array', 'min:1', 'max:8'],
             'coverages.*' => ['required', 'array'],
diff --git a/server/resources/views/admin/restrictions/form.blade.php b/server/resources/views/admin/restrictions/form.blade.php
index 96ddb5a..49d9480 100644
--- a/server/resources/views/admin/restrictions/form.blade.php
+++ b/server/resources/views/admin/restrictions/form.blade.php
@@ -149,7 +149,13 @@ function addRule(card) {
 });
 </script>
 @else
-<div class="mt-6 rounded-lg border border-slate-200 bg-white p-5"><p class="font-medium">Esta versión no se puede editar.</p><p class="mt-1 text-sm text-slate-600">Duplica la versión para crear un nuevo borrador sin alterar el historial.</p><details class="mt-4"><summary class="cursor-pointer font-medium">Ver contrato técnico publicado</summary><pre class="mt-3 max-h-[36rem] overflow-auto rounded bg-slate-950 p-3 text-xs text-slate-100">{{ json_encode($version->payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) }}</pre></details></div>
+<div class="mt-6 rounded-lg border border-slate-200 bg-white p-5"><p class="font-medium">Esta versión no se puede editar con este formulario.</p>
+@if(($version->payload['schemaVersion'] ?? 1) === 2)
+    <p class="mt-1 text-sm text-slate-600">Este borrador usa el contrato schema2. Para cambiar modalidades, cobertura o condiciones sin perder información, <a class="font-medium underline" href="{{ route('admin.restrictions.import') }}">importa un JSON schema2</a> y revísalo antes de publicarlo.</p>
+@else
+    <p class="mt-1 text-sm text-slate-600">Duplica la versión para crear un nuevo borrador sin alterar el historial.</p>
+@endif
+<details class="mt-4"><summary class="cursor-pointer font-medium">Ver contrato técnico conservado</summary><pre class="mt-3 max-h-[36rem] overflow-auto rounded bg-slate-950 p-3 text-xs text-slate-100">{{ json_encode($version->payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) }}</pre></details></div>
 @endif
 
 @if($version)
diff --git a/server/tests/Feature/RestrictionRouteIntegrationTest.php b/server/tests/Feature/RestrictionRouteIntegrationTest.php
index 27d5697..91b5026 100644
--- a/server/tests/Feature/RestrictionRouteIntegrationTest.php
+++ b/server/tests/Feature/RestrictionRouteIntegrationTest.php
@@ -108,4 +108,50 @@ public function test_editor_creates_a_city_draft_with_human_fields_instead_of_js
             ->assertSee('Horarios')
             ->assertDontSee('Contrato JSON');
     }
+
+    public function test_schema2_draft_cannot_be_downgraded_by_legacy_form(): void
+    {
+        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
+        $country = GeographicUnit::query()->create([
+            'key' => 'co', 'level' => GeographicUnitLevel::Country, 'code' => 'CO',
+            'name' => 'Colombia', 'normalized_name' => 'colombia',
+            'source_system' => 'synthetic', 'source_version' => 'test-v1',
+        ]);
+        $jurisdiction = Jurisdiction::query()->create([
+            'key' => 'synthetic-city', 'name' => 'Ciudad sintética',
+            'kind' => JurisdictionKind::City,
+            'primary_geographic_unit_id' => $country->id, 'enabled' => true,
+        ]);
+        $payload = [
+            'schemaVersion' => 2, 'id' => 'synthetic-city', 'name' => 'Ciudad sintética',
+            'coverages' => [[
+                'vehicleKind' => 'truck', 'serviceType' => 'public_cargo',
+                'coverageCompleteness' => 'partial',
+                'verifiedAt' => '2026-11-13T10:00:00-05:00',
+                'staleAfter' => '2026-11-20T23:59:59-05:00',
+                'sourceUrls' => ['https://example.test/municipal'],
+                'rules' => [],
+            ]],
+        ];
+        $version = RestrictionRuleVersion::query()->create([
+            'jurisdiction_id' => $jurisdiction->id, 'version' => 1,
+            'status' => \App\Enums\RestrictionRuleVersionStatus::Draft,
+            'payload' => $payload, 'payload_sha256' => hash('sha256', json_encode($payload)),
+            'base_publication_revision' => 0,
+            'created_by_id' => $editor->id, 'updated_by_id' => $editor->id,
+        ]);
+        $this->actingAs($editor)->get(route('admin.restrictions.edit', $version))
+            ->assertOk()
+            ->assertSee('importa un JSON schema2')
+            ->assertDontSee('name="coverages[0][vehicle_kind]"', false);
+
+        $this->actingAs($editor)->put(route('admin.restrictions.update', $version), [
+            'coverages' => [[
+                'vehicle_kind' => 'car', 'service_type' => 'private',
+                'rules' => [],
+            ]],
+        ])->assertSessionHasErrors('version');
+        $version->refresh();
+        $this->assertSame($payload, $version->payload);
+    }
 }

```