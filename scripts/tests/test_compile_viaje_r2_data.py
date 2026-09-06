import hashlib
import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_PACKAGE = REPO_ROOT.parent / "VIAJE_R2" / "source-package"
COMPILER_PATH = REPO_ROOT / "scripts" / "compile_viaje_r2_data.py"

spec = importlib.util.spec_from_file_location("viaje_r2_compiler", COMPILER_PATH)
compiler = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(compiler)


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_sha256(value):
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


@unittest.skipUnless(SOURCE_PACKAGE.is_dir(), "VIAJE-R2 source package unavailable")
class ReleaseCompilerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.output_root = Path(self.temp.name)
        self.seed_output_root(self.output_root)

    def seed_output_root(self, output_root):
        restriction_target = (
            output_root
            / "mobile/assets/datasets/restrictions/restrictions_v1.json"
        )
        restriction_target.parent.mkdir(parents=True)
        shutil.copyfile(
            REPO_ROOT / "mobile/assets/datasets/restrictions/restrictions_v1.json",
            restriction_target,
        )
        catalog_target = (
            output_root
            / "mobile/assets/catalogs/colombia_trip_municipalities_v1.json"
        )
        catalog_target.parent.mkdir(parents=True)
        shutil.copyfile(
            REPO_ROOT
            / "mobile/assets/catalogs/colombia_trip_municipalities_v1.json",
            catalog_target,
        )

    def tearDown(self):
        self.temp.cleanup()

    def decision_path(self, decision):
        path = self.output_root / "reviewed_decisions.json"
        decisions = decision if isinstance(decision, list) else [decision]
        path.write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "reviewVersion": "test-v1",
                    "reviewedAt": "2026-09-06T00:00:00Z",
                    "reviewer": "test-reviewer",
                    "decisions": decisions,
                }
            ),
            encoding="utf-8",
        )
        return path

    def complete_pasto_decision(self):
        source_url = (
            "https://www.pasto.gov.co/index.php/decretos-2026?"
            "download=3115701%3Adec-0122-24-jul-2026"
        )
        runtime_coverage = {
            "jurisdictionId": "co-nar-pasto",
            "jurisdictionName": "Pasto",
            "vehicleKind": "car",
            "serviceType": "private",
            "verifiedAt": "2026-09-06T00:00:00Z",
            "staleAfter": "2026-09-02T00:00:00Z",
            "sourceUrls": [source_url],
            "rules": [
                {
                    "id": "pasto-car-private-test-2026-09-01",
                    "priority": 1000,
                    "effect": "restrict",
                    "validFrom": "2026-09-01T00:00:00",
                    "validUntil": "2026-09-01T23:59:59",
                    "registrationOrigins": ["local", "foreign", "unknown"],
                    "weekdays": [2],
                    "digitPosition": "lastNumeric",
                    "digits": [4, 5],
                    "timeWindows": [{"startMinute": 450, "endMinute": 1140}],
                    "appliesOnHolidays": False,
                    "sourceUrl": source_url,
                    "verifiedAt": "2026-09-06T00:00:00Z",
                }
            ],
        }
        decision = {
            "sourceCoverageId": "co-source:narino:pasto:private_car",
            "sourceRef": {
                "sheet": "Resumen_ciudades",
                "row": 56,
                "columns": "3:19",
            },
            "sourceRecordIds": ["pico-calendar-row-0095"],
            "originalValue": {},
            "interpretedValue": {},
            "officialSourceUrl": source_url,
            "evidenceSummary": "Synthetic official evidence used only by the test.",
            "consultedAt": "2026-09-06T00:00:00Z",
            "legalValidity": {
                "status": "complete",
                "validFrom": "2026-09-01T00:00:00",
                "validUntil": "2026-09-01T23:59:59",
                "sourceTimestamp": "2026-07-24T00:00:00Z",
            },
            "decision": "verified_executable",
            "reviewer": "test-reviewer",
            "snapshotAction": "add",
            "blockers": [],
            "runtimeCoverage": runtime_coverage,
        }
        self.refresh_evidence_hashes(decision)
        return decision

    def refresh_evidence_hashes(self, decision):
        source = read_json(
            SOURCE_PACKAGE / "data/staging/pico_colombia_source_v1.json"
        )
        source_coverage = next(
            coverage
            for jurisdiction in source["jurisdictions"]
            for coverage in jurisdiction["coverages"]
            if (
                f"{jurisdiction['sourceJurisdictionKey']}:"
                f"{coverage['sourceVehicleType']}"
            )
            == decision["sourceCoverageId"]
        )
        dated_by_id = {
            row["sourceRecordId"]: row for row in source["datedSchedules"]
        }
        source_records = [
            dated_by_id[source_id] for source_id in decision["sourceRecordIds"]
        ]
        decision["originalValue"] = {
            "sourceCoverageSha256": canonical_sha256(source_coverage),
            "sourceRecordsSha256": canonical_sha256(source_records),
        }
        decision["interpretedValue"] = {
            "runtimeCoverageSha256": canonical_sha256(
                decision["runtimeCoverage"]
            ),
            "ruleEvidence": [
                {
                    "ruleId": rule["id"],
                    "sourceRecordId": decision["sourceRecordIds"][index],
                }
                for index, rule in enumerate(decision["runtimeCoverage"]["rules"])
                if index < len(decision["sourceRecordIds"])
            ],
        }

    def reviewed_ledger_row(self, source_coverage_id):
        ledger = read_json(
            self.output_root
            / "data/releases/viaje_r2/restriction_decision_ledger_v1.json"
        )
        return next(
            row
            for row in ledger["coverageDecisions"]
            if row["sourceCoverageId"] == source_coverage_id
        )

    def test_complete_review_publishes_and_preserves_existing_snapshot(self):
        path = self.decision_path(self.complete_pasto_decision())
        restriction_path = (
            self.output_root
            / "mobile/assets/datasets/restrictions/restrictions_v1.json"
        )
        before = read_json(restriction_path)

        report = compiler.compile_release(
            SOURCE_PACKAGE, self.output_root, reviewed_decisions_path=path
        )

        after = read_json(restriction_path)
        self.assertEqual(report["restrictions"]["newRulesPublished"], 1)
        self.assertEqual(report["restrictions"]["snapshotDiff"]["added"], 1)
        self.assertEqual(
            [row for row in before["jurisdictions"] if row["id"] != "co-nar-pasto"],
            [row for row in after["jurisdictions"] if row["id"] != "co-nar-pasto"],
        )

    def test_incomplete_verified_decision_remains_quarantined(self):
        decision = self.complete_pasto_decision()
        del decision["runtimeCoverage"]["staleAfter"]
        path = self.decision_path(decision)
        restriction_path = (
            self.output_root
            / "mobile/assets/datasets/restrictions/restrictions_v1.json"
        )
        before = restriction_path.read_bytes()

        compiler.compile_release(
            SOURCE_PACKAGE, self.output_root, reviewed_decisions_path=path
        )

        ledger = read_json(
            self.output_root
            / "data/releases/viaje_r2/restriction_decision_ledger_v1.json"
        )
        reviewed = next(
            row
            for row in ledger["coverageDecisions"]
            if row["sourceCoverageId"]
            == "co-source:narino:pasto:private_car"
        )
        self.assertEqual(restriction_path.read_bytes(), before)
        self.assertEqual(reviewed["reviewDecision"], "needs_evidence")
        self.assertIn("runtime_stale_after_invalid", reviewed["quarantineReasons"])

    def test_verified_decision_requires_complete_traceable_official_evidence(self):
        cases = (
            (
                "legal status",
                lambda row: row["legalValidity"].update(status="incomplete"),
                "legal_validity_status_not_complete",
            ),
            (
                "blockers",
                lambda row: row.update(blockers=["legal_semantics_not_verified"]),
                "review_blockers_present",
            ),
            (
                "consultedAt",
                lambda row: row.update(consultedAt="not-a-date"),
                "review_consulted_at_not_utc",
            ),
            (
                "empty source records",
                lambda row: row.update(sourceRecordIds=[]),
                "review_source_record_ids_required",
            ),
            (
                "uncorrelated source record",
                lambda row: row.update(sourceRecordIds=["pico-calendar-row-0096"]),
                "review_source_record_not_correlated",
            ),
            (
                "unofficial domain",
                lambda row: row.update(
                    officialSourceUrl="https://example.com/not-official"
                ),
                "review_official_source_domain_not_allowed",
            ),
            (
                "unlinked official URL",
                lambda row: row.update(
                    officialSourceUrl="https://www.pasto.gov.co/not-in-source"
                ),
                "review_official_source_not_in_source_records",
            ),
            (
                "coverage evidence hash",
                lambda row: row["originalValue"].update(
                    sourceCoverageSha256="0" * 64
                ),
                "review_source_coverage_hash_mismatch",
            ),
            (
                "record evidence hash",
                lambda row: row["originalValue"].update(
                    sourceRecordsSha256="0" * 64
                ),
                "review_source_records_hash_mismatch",
            ),
            (
                "runtime interpretation hash",
                lambda row: row["interpretedValue"].update(
                    runtimeCoverageSha256="0" * 64
                ),
                "review_runtime_coverage_hash_mismatch",
            ),
        )
        restriction_path = (
            self.output_root
            / "mobile/assets/datasets/restrictions/restrictions_v1.json"
        )
        before = restriction_path.read_bytes()
        for label, mutate, expected_reason in cases:
            with self.subTest(label=label):
                decision = self.complete_pasto_decision()
                mutate(decision)
                path = self.decision_path(decision)
                report = compiler.compile_release(
                    SOURCE_PACKAGE, self.output_root, reviewed_decisions_path=path
                )
                reviewed = self.reviewed_ledger_row(decision["sourceCoverageId"])
                self.assertEqual(report["restrictions"]["newRulesPublished"], 0)
                self.assertEqual(restriction_path.read_bytes(), before)
                self.assertIn(expected_reason, reviewed["quarantineReasons"])

    def test_rejects_every_mobile_importer_incompatible_rule_shape(self):
        cases = (
            ("priority type", lambda rule: rule.update(priority="1000"), "runtime_rule_priority_invalid"),
            ("priority bool", lambda rule: rule.update(priority=True), "runtime_rule_priority_invalid"),
            ("effect enum", lambda rule: rule.update(effect="deny"), "runtime_rule_effect_invalid"),
            ("effect type", lambda rule: rule.update(effect=[]), "runtime_rule_effect_invalid"),
            ("weekday range", lambda rule: rule.update(weekdays=[0]), "runtime_rule_weekdays_invalid"),
            ("weekday bool", lambda rule: rule.update(weekdays=[True]), "runtime_rule_weekdays_invalid"),
            ("weekday type", lambda rule: rule.update(weekdays="2"), "runtime_rule_weekdays_invalid"),
            ("date parity enum", lambda rule: rule.update(dateParity="daily"), "runtime_rule_date_parity_invalid"),
            ("date parity type", lambda rule: rule.update(dateParity=[]), "runtime_rule_date_parity_invalid"),
            ("registration enum", lambda rule: rule.update(registrationOrigins=["other"]), "runtime_rule_registration_origins_invalid"),
            ("registration type", lambda rule: rule.update(registrationOrigins="local"), "runtime_rule_registration_origins_invalid"),
            ("digit enum", lambda rule: rule.update(digitPosition="middle"), "runtime_rule_digit_position_invalid"),
            ("digit position type", lambda rule: rule.update(digitPosition=[]), "runtime_rule_digit_position_invalid"),
            ("digit bool", lambda rule: rule.update(digits=[True]), "runtime_rule_digits_invalid"),
            ("digits type", lambda rule: rule.update(digits="4"), "runtime_rule_digits_invalid"),
            ("digit conditional", lambda rule: rule.pop("digitPosition"), "runtime_rule_digit_position_required"),
            ("start minute", lambda rule: rule.update(timeWindows=[{"startMinute": 1440, "endMinute": 1}]), "runtime_rule_window_invalid"),
            ("end minute", lambda rule: rule.update(timeWindows=[{"startMinute": 0, "endMinute": 1440}]), "runtime_rule_window_invalid"),
            ("equal window", lambda rule: rule.update(timeWindows=[{"startMinute": 5, "endMinute": 5}]), "runtime_rule_window_invalid"),
            ("window bool", lambda rule: rule.update(timeWindows=[{"startMinute": False, "endMinute": 5}]), "runtime_rule_window_invalid"),
            ("holiday type", lambda rule: rule.update(appliesOnHolidays="false"), "runtime_rule_holiday_policy_invalid"),
            ("valid from", lambda rule: rule.update(validFrom="not-a-date"), "runtime_rule_validity_invalid"),
            ("valid until", lambda rule: rule.update(validUntil="not-a-date"), "runtime_rule_validity_invalid"),
            ("reversed dates", lambda rule: rule.update(validUntil="2026-08-31T23:59:59"), "runtime_rule_validity_invalid"),
            ("rule URL", lambda rule: rule.update(sourceUrl="http://www.pasto.gov.co/source"), "runtime_rule_source_url_invalid"),
            ("verified date", lambda rule: rule.update(verifiedAt="not-a-date"), "runtime_rule_verified_at_invalid"),
        )
        for label, mutate, expected_reason in cases:
            with self.subTest(label=label):
                decision = self.complete_pasto_decision()
                mutate(decision["runtimeCoverage"]["rules"][0])
                path = self.decision_path(decision)
                report = compiler.compile_release(
                    SOURCE_PACKAGE, self.output_root, reviewed_decisions_path=path
                )
                reviewed = self.reviewed_ledger_row(decision["sourceCoverageId"])
                self.assertEqual(report["restrictions"]["newRulesPublished"], 0)
                self.assertIn(expected_reason, reviewed["quarantineReasons"])

    def test_rejects_mobile_importer_incompatible_coverage_shape(self):
        cases = (
            ("vehicle kind", lambda row: row.update(vehicleKind="truck"), "runtime_vehicle_kind_invalid"),
            ("vehicle kind type", lambda row: row.update(vehicleKind=[]), "runtime_vehicle_kind_invalid"),
            ("service type", lambda row: row.update(serviceType="public"), "runtime_service_type_invalid"),
            ("service type type", lambda row: row.update(serviceType=[]), "runtime_service_type_invalid"),
            ("verified date", lambda row: row.update(verifiedAt="not-a-date"), "runtime_verified_at_invalid"),
            ("stale date", lambda row: row.update(staleAfter="not-a-date"), "runtime_stale_after_invalid"),
            ("source URL list", lambda row: row.update(sourceUrls="https://www.pasto.gov.co"), "runtime_source_urls_invalid"),
            ("rules list", lambda row: row.update(rules={}), "runtime_rules_invalid"),
            ("empty rules", lambda row: row.update(rules=[]), "runtime_rules_missing"),
        )
        for label, mutate, expected_reason in cases:
            with self.subTest(label=label):
                decision = self.complete_pasto_decision()
                mutate(decision["runtimeCoverage"])
                path = self.decision_path(decision)
                report = compiler.compile_release(
                    SOURCE_PACKAGE, self.output_root, reviewed_decisions_path=path
                )
                reviewed = self.reviewed_ledger_row(decision["sourceCoverageId"])
                self.assertEqual(report["restrictions"]["newRulesPublished"], 0)
                self.assertIn(expected_reason, reviewed["quarantineReasons"])

    def test_runtime_interpretation_must_match_linked_source_record(self):
        decision = self.complete_pasto_decision()
        decision["runtimeCoverage"]["rules"][0]["digits"] = [1, 2]
        self.refresh_evidence_hashes(decision)
        path = self.decision_path(decision)

        report = compiler.compile_release(
            SOURCE_PACKAGE, self.output_root, reviewed_decisions_path=path
        )

        reviewed = self.reviewed_ledger_row(decision["sourceCoverageId"])
        self.assertEqual(report["restrictions"]["newRulesPublished"], 0)
        self.assertIn("review_rule_evidence_mismatch", reviewed["quarantineReasons"])

    def test_final_dataset_rejects_cross_coverage_rule_id_collision(self):
        private = self.complete_pasto_decision()
        motorcycle = self.complete_pasto_decision()
        motorcycle.update(
            {
                "sourceCoverageId": "co-source:narino:pasto:motorcycle",
                "sourceRef": {
                    "sheet": "Resumen_ciudades",
                    "row": 56,
                    "columns": "20:36",
                },
                "sourceRecordIds": ["pico-calendar-row-0096"],
            }
        )
        motorcycle["runtimeCoverage"]["vehicleKind"] = "motorcycle"
        self.refresh_evidence_hashes(motorcycle)
        path = self.decision_path([private, motorcycle])
        restriction_path = (
            self.output_root
            / "mobile/assets/datasets/restrictions/restrictions_v1.json"
        )
        before = restriction_path.read_bytes()

        report = compiler.compile_release(
            SOURCE_PACKAGE, self.output_root, reviewed_decisions_path=path
        )

        self.assertEqual(report["restrictions"]["newRulesPublished"], 0)
        self.assertEqual(restriction_path.read_bytes(), before)
        for source_id in (
            private["sourceCoverageId"],
            motorcycle["sourceCoverageId"],
        ):
            reviewed = self.reviewed_ledger_row(source_id)
            self.assertIn("runtime_rule_id_duplicate", reviewed["quarantineReasons"])

    def test_no_publicar_record_cannot_be_overridden_by_verified_decision(self):
        decision = self.complete_pasto_decision()
        decision.update(
            {
                "sourceCoverageId": "co-source:caldas:manizales:taxi",
                "sourceRef": {
                    "sheet": "Resumen_ciudades",
                    "row": 41,
                    "columns": "37:53",
                },
                "sourceRecordIds": ["pico-calendar-row-0065"],
            }
        )
        decision["runtimeCoverage"].update(
            {
                "jurisdictionId": "co-cal-manizales",
                "jurisdictionName": "Manizales",
                "serviceType": "taxi",
            }
        )
        self.refresh_evidence_hashes(decision)
        path = self.decision_path(decision)

        report = compiler.compile_release(
            SOURCE_PACKAGE, self.output_root, reviewed_decisions_path=path
        )

        ledger = read_json(
            self.output_root
            / "data/releases/viaje_r2/restriction_decision_ledger_v1.json"
        )
        reviewed = next(
            row
            for row in ledger["coverageDecisions"]
            if row["sourceCoverageId"] == "co-source:caldas:manizales:taxi"
        )
        self.assertEqual(report["restrictions"]["newRulesPublished"], 0)
        self.assertFalse(reviewed["publishable"])
        self.assertIn("source_explicit_no_publish", reviewed["quarantineReasons"])

    def test_snapshot_action_must_match_real_before_after_change(self):
        decision = self.complete_pasto_decision()
        decision["snapshotAction"] = "maintain"
        path = self.decision_path(decision)

        report = compiler.compile_release(
            SOURCE_PACKAGE, self.output_root, reviewed_decisions_path=path
        )

        reviewed = self.reviewed_ledger_row(decision["sourceCoverageId"])
        self.assertEqual(report["restrictions"]["newRulesPublished"], 0)
        self.assertEqual(
            report["restrictions"]["snapshotDiff"],
            {"added": 0, "updated": 0, "maintained": 0, "removed": 0},
        )
        self.assertIn(
            "snapshot_action_mismatch_expected_add", reviewed["quarantineReasons"]
        )

    def test_reviewed_compile_is_byte_identical_from_same_snapshot(self):
        with tempfile.TemporaryDirectory() as second_temp:
            second_root = Path(second_temp)
            self.seed_output_root(second_root)
            decision = self.complete_pasto_decision()
            first_path = self.decision_path(decision)
            second_path = second_root / "reviewed_decisions.json"
            shutil.copyfile(first_path, second_path)

            compiler.compile_release(
                SOURCE_PACKAGE,
                self.output_root,
                reviewed_decisions_path=first_path,
            )
            compiler.compile_release(
                SOURCE_PACKAGE,
                second_root,
                reviewed_decisions_path=second_path,
            )

            relative_outputs = (
                *compiler.OUTPUT_PATHS,
                "mobile/assets/datasets/restrictions/restrictions_v1.json",
            )
            self.assertEqual(
                {item: sha256(self.output_root / item) for item in relative_outputs},
                {item: sha256(second_root / item) for item in relative_outputs},
            )

    def test_quarantines_every_restriction_without_changing_bundled_bytes(self):
        restriction_path = (
            self.output_root
            / "mobile/assets/datasets/restrictions/restrictions_v1.json"
        )
        before = restriction_path.read_bytes()

        compiler.compile_release(SOURCE_PACKAGE, self.output_root)

        ledger = read_json(
            self.output_root
            / "data/releases/viaje_r2/restriction_decision_ledger_v1.json"
        )
        self.assertEqual(restriction_path.read_bytes(), before)
        self.assertEqual(ledger["newRuntimeRulesPublished"], 0)
        self.assertEqual(len(ledger["coverageDecisions"]), 219)
        self.assertEqual(len(ledger["datedScheduleDecisions"]), 261)
        self.assertTrue(
            all(row["decision"] == "quarantined" for row in ledger["coverageDecisions"])
        )
        self.assertTrue(
            all(
                row["decision"] == "quarantined"
                for row in ledger["datedScheduleDecisions"]
            )
        )
        explicit_holds = [
            row
            for row in ledger["datedScheduleDecisions"]
            if "source_explicit_no_publish" in row["quarantineReasons"]
        ]
        self.assertEqual(len(explicit_holds), 74)
        required_reasons = {
            "legal_validity_unverified",
            "holiday_policy_unverified",
            "freshness_unverified",
            "registration_scope_unverified",
        }
        for row in ledger["coverageDecisions"]:
            self.assertTrue(required_reasons.issubset(row["quarantineReasons"]))

    def test_restriction_ledger_preserves_every_source_row_value(self):
        compiler.compile_release(SOURCE_PACKAGE, self.output_root)
        source = read_json(
            SOURCE_PACKAGE / "data/staging/pico_colombia_source_v1.json"
        )
        ledger = read_json(
            self.output_root
            / "data/releases/viaje_r2/restriction_decision_ledger_v1.json"
        )

        coverage_decisions = {
            row["sourceCoverageId"]: row for row in ledger["coverageDecisions"]
        }
        for jurisdiction in source["jurisdictions"]:
            for coverage in jurisdiction["coverages"]:
                source_id = (
                    f"{jurisdiction['sourceJurisdictionKey']}:"
                    f"{coverage['sourceVehicleType']}"
                )
                self.assertEqual(
                    coverage_decisions[source_id]["sourceProjection"], coverage
                )

        dated_decisions = {
            row["sourceRecordId"]: row
            for row in ledger["datedScheduleDecisions"]
        }
        for source_row in source["datedSchedules"]:
            self.assertEqual(
                dated_decisions[source_row["sourceRecordId"]]["sourceProjection"],
                source_row,
            )

        rotation_decisions = {
            row["sourceJurisdictionKey"]: row
            for row in ledger["rotationValidityDecisions"]
        }
        self.assertEqual(len(rotation_decisions), 73)
        self.assertEqual(
            set(rotation_decisions),
            {
                row["sourceJurisdictionKey"]
                for row in source["rotationsAndValidity"]
            },
        )
        for source_row in source["rotationsAndValidity"]:
            decision = rotation_decisions[source_row["sourceJurisdictionKey"]]
            self.assertEqual(decision["sourceProjection"], source_row)
            self.assertEqual(decision["sourceRef"], source_row["sourceRef"])
            self.assertEqual(decision["decision"], "informational_only")
            self.assertFalse(decision["publishable"])
            self.assertFalse(decision["runtimePublished"])

    def test_maps_only_the_five_reviewed_geography_aliases(self):
        compiler.compile_release(SOURCE_PACKAGE, self.output_root)
        ledger = read_json(
            self.output_root
            / "data/releases/viaje_r2/restriction_decision_ledger_v1.json"
        )
        expected = {
            "co-source:bogota-d-c:bogota": ("11001", "co-dc-bogota"),
            "co-source:bolivar:cartagena": ("13001", "co-bol-cartagena"),
            "co-source:cordoba:santa-cruz-de-lorica": ("23417", None),
            "co-source:norte-de-santander:cucuta": ("54001", "co-nds-cucuta"),
            "co-source:valle-del-cauca:cali": ("76001", "co-vac-cali"),
        }
        by_jurisdiction = {}
        for row in ledger["coverageDecisions"]:
            by_jurisdiction.setdefault(row["sourceJurisdictionKey"], row)
        for source_key, (divipola, app_id) in expected.items():
            self.assertEqual(by_jurisdiction[source_key]["divipolaCode"], divipola)
            self.assertEqual(
                by_jurisdiction[source_key]["appJurisdictionId"], app_id
            )

        lookup = compiler._geography_lookup(self.output_root)
        wrong_identity = compiler._mapped_geography(
            {
                "sourceJurisdictionKey": "co-source:bolivar:cartagena",
                "department": "Bolívar",
                "city": "Cartagena equivocada",
            },
            lookup,
        )
        self.assertEqual(
            wrong_identity, {"divipolaCode": None, "appJurisdictionId": None}
        )

    def test_emits_physical_inventory_without_prices_or_charge_events(self):
        compiler.compile_release(SOURCE_PACKAGE, self.output_root)

        asset = read_json(
            self.output_root / "mobile/assets/catalogs/tolls_inventory_v1.json"
        )
        ledger = read_json(
            self.output_root / "data/releases/viaje_r2/toll_decision_ledger_v1.json"
        )
        self.assertEqual(asset["datasetKey"], "tolls_inventory")
        self.assertEqual(asset["inventoryScope"], "physical_station_inventory_only")
        self.assertFalse(asset["liveTariffsAvailable"])
        self.assertEqual(len(asset["records"]), 184)
        self.assertEqual(len({row["id"] for row in asset["records"]}), 184)
        tariffs = [
            value
            for row in asset["records"]
            for value in row["tariffsBySourceCategoryCOP"].values()
        ]
        self.assertEqual(len(tariffs), 1288)
        self.assertTrue(all(value is None for value in tariffs))
        self.assertTrue(
            all(row["recordKind"] == "physical_station" for row in asset["records"])
        )
        self.assertTrue(
            all(row["chargeEventStatus"] == "unverified" for row in asset["records"])
        )
        self.assertEqual(len(ledger["recordDecisions"]), 184)
        self.assertTrue(
            all(
                row["decision"] == "informational_only"
                for row in ledger["recordDecisions"]
            )
        )
        self.assertEqual(ledger["activeChargesPublished"], 0)

    def test_manifest_hashes_payloads_and_marks_local_simulation(self):
        compiler.compile_release(SOURCE_PACKAGE, self.output_root)

        manifest = read_json(
            self.output_root / "data/releases/viaje_r2/local_test/manifest.json"
        )
        report = read_json(
            self.output_root / "data/releases/viaje_r2/local_test/compile_report.json"
        )
        restrictions = (
            self.output_root
            / "mobile/assets/datasets/restrictions/restrictions_v1.json"
        )
        tolls = self.output_root / "mobile/assets/catalogs/tolls_inventory_v1.json"
        self.assertEqual(manifest["distribution"], "local_simulation_only")
        self.assertFalse(manifest["serverPublished"])
        self.assertEqual(
            manifest["datasets"]["restrictions"]["sha256"], sha256(restrictions)
        )
        self.assertEqual(
            manifest["datasets"]["tolls_inventory"]["sha256"], sha256(tolls)
        )
        self.assertEqual(
            manifest["datasets"]["tolls_inventory"]["sourceTimestamp"],
            "2026-09-05T00:00:00Z",
        )
        self.assertEqual(
            manifest["datasets"]["restrictions"]["publicationRevision"], 1
        )
        self.assertEqual(
            manifest["datasets"]["tolls_inventory"]["publicationRevision"], 1
        )
        self.assertFalse(report["serverPublished"])
        self.assertEqual(report["restrictions"]["newRulesPublished"], 0)
        self.assertEqual(report["tolls"]["activeChargesPublished"], 0)

    def test_second_compile_is_byte_identical(self):
        compiler.compile_release(SOURCE_PACKAGE, self.output_root)
        outputs = [self.output_root / path for path in compiler.OUTPUT_PATHS]
        first = {path: sha256(path) for path in outputs}

        compiler.compile_release(SOURCE_PACKAGE, self.output_root)

        self.assertEqual(first, {path: sha256(path) for path in outputs})


class CheckedInReleaseTests(unittest.TestCase):
    def test_checked_in_release_has_exact_accounting(self):
        asset = read_json(REPO_ROOT / "mobile/assets/catalogs/tolls_inventory_v1.json")
        reviewed = read_json(
            REPO_ROOT
            / "data/releases/viaje_r2/reviewed_restriction_decisions_v1.json"
        )
        restrictions = read_json(
            REPO_ROOT
            / "data/releases/viaje_r2/restriction_decision_ledger_v1.json"
        )
        report = read_json(
            REPO_ROOT / "data/releases/viaje_r2/local_test/compile_report.json"
        )
        self.assertEqual(len(asset["records"]), 184)
        self.assertEqual(len(restrictions["coverageDecisions"]), 219)
        self.assertEqual(len(restrictions["datedScheduleDecisions"]), 261)
        self.assertEqual(len(restrictions["rotationValidityDecisions"]), 73)
        self.assertEqual(len(reviewed["decisions"]), 6)
        self.assertTrue(
            all(row["decision"] == "needs_evidence" for row in reviewed["decisions"])
        )
        self.assertEqual(restrictions["reviewedDecisionCount"], 6)
        self.assertEqual(restrictions["newRuntimeRulesPublished"], 0)
        self.assertEqual(report["tariffCellsNull"], 1288)
        self.assertEqual(report["restrictions"]["verifiedExecutableDecisions"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
