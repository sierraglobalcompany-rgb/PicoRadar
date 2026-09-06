import hashlib
import importlib.util
import json
import shutil
import tempfile
import unittest
from datetime import datetime, timedelta
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


def evaluate(payload, jurisdiction_id, vehicle_kind, service_type, plate, when):
    jurisdiction = next(
        (row for row in payload["jurisdictions"] if row["id"] == jurisdiction_id),
        None,
    )
    if jurisdiction is None:
        return "unknown"
    coverage = next(
        (
            row
            for row in jurisdiction["coverages"]
            if row["vehicleKind"] == vehicle_kind
            and row["serviceType"] == service_type
        ),
        None,
    )
    if coverage is None:
        return "unknown"
    if when > datetime.fromisoformat(coverage["staleAfter"].replace("Z", "+00:00")):
        return "stale"

    digit = int(next(character for character in plate if character.isdigit()))
    for rule in coverage["rules"]:
        for window in rule["timeWindows"]:
            anchor = when
            minute = when.hour * 60 + when.minute
            if window["startMinute"] > window["endMinute"] and minute < window["endMinute"]:
                anchor -= timedelta(days=1)
            anchor_minute = anchor.hour * 60 + anchor.minute
            in_window = (
                window["startMinute"] <= anchor_minute < window["endMinute"]
                if window["startMinute"] <= window["endMinute"]
                else anchor_minute >= window["startMinute"]
                or anchor_minute < window["endMinute"]
            )
            if not in_window:
                continue
            if not (
                datetime.fromisoformat(rule["validFrom"]) <= anchor.replace(tzinfo=None)
                <= datetime.fromisoformat(rule["validUntil"])
            ):
                continue
            if rule.get("weekdays") and anchor.isoweekday() not in rule["weekdays"]:
                continue
            if digit in rule["digits"]:
                return "restricted"
    return "allowed"


@unittest.skipUnless(SOURCE_PACKAGE.is_dir(), "VIAJE-R2 source package unavailable")
class ReleaseCompilerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.output_root = Path(self.temp.name)
        restriction_target = (
            self.output_root
            / "mobile/assets/datasets/restrictions/restrictions_v1.json"
        )
        restriction_target.parent.mkdir(parents=True)
        shutil.copyfile(
            REPO_ROOT / "mobile/assets/datasets/restrictions/restrictions_v1.json",
            restriction_target,
        )
        catalog_target = (
            self.output_root
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
        path.write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "reviewVersion": "test-v1",
                    "reviewedAt": "2026-09-06T00:00:00Z",
                    "reviewer": "test-reviewer",
                    "decisions": [decision],
                }
            ),
            encoding="utf-8",
        )
        return path

    def complete_pasto_decision(self):
        source_url = "https://www.pasto.gov.co/official-test-source"
        return {
            "sourceCoverageId": "co-source:narino:pasto:private_car",
            "sourceRef": {
                "sheet": "Resumen_ciudades",
                "row": 56,
                "columns": "3:19",
            },
            "sourceRecordIds": [],
            "originalValue": {"sourceVehicleType": "private_car"},
            "interpretedValue": {
                "scope": "synthetic complete test decision",
                "holidayPolicy": "does_not_apply",
                "registrationScope": "all_origins",
            },
            "officialSourceUrl": source_url,
            "evidenceSummary": "Synthetic official evidence used only by the test.",
            "consultedAt": "2026-09-06",
            "legalValidity": {
                "validFrom": "2026-09-07T00:00:00",
                "validUntil": "2026-09-07T23:59:59",
                "sourceTimestamp": "2026-09-06T00:00:00Z",
            },
            "decision": "verified_executable",
            "reviewer": "test-reviewer",
            "snapshotAction": "add",
            "runtimeCoverage": {
                "jurisdictionId": "co-nar-pasto",
                "jurisdictionName": "Pasto",
                "vehicleKind": "car",
                "serviceType": "private",
                "verifiedAt": "2026-09-06T00:00:00Z",
                "staleAfter": "2026-09-08T02:00:00Z",
                "sourceUrls": [source_url],
                "rules": [
                    {
                        "id": "pasto-car-private-test-mon",
                        "priority": 1000,
                        "effect": "restrict",
                        "validFrom": "2026-09-07T00:00:00",
                        "validUntil": "2026-09-07T23:59:59",
                        "weekdays": [1],
                        "digitPosition": "firstNumeric",
                        "digits": [1],
                        "timeWindows": [{"startMinute": 1320, "endMinute": 120}],
                        "appliesOnHolidays": False,
                        "sourceUrl": source_url,
                        "verifiedAt": "2026-09-06T00:00:00Z",
                    }
                ],
            },
        }

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
        self.assertEqual(
            evaluate(
                before,
                "co-nar-pasto",
                "car",
                "private",
                "A1",
                datetime.fromisoformat("2026-09-07T22:00:00+00:00"),
            ),
            "unknown",
        )
        self.assertEqual(
            evaluate(
                after,
                "co-nar-pasto",
                "car",
                "private",
                "A1",
                datetime.fromisoformat("2026-09-07T22:00:00+00:00"),
            ),
            "restricted",
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
        self.assertIn("runtime_coverage_missing_staleAfter", reviewed["quarantineReasons"])

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
                "sourceRecordIds": [],
            }
        )
        decision["runtimeCoverage"].update(
            {
                "jurisdictionId": "co-cal-manizales",
                "jurisdictionName": "Manizales",
                "serviceType": "taxi",
            }
        )
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

    def test_time_boundaries_next_day_and_staleness_are_preserved(self):
        path = self.decision_path(self.complete_pasto_decision())
        compiler.compile_release(
            SOURCE_PACKAGE, self.output_root, reviewed_decisions_path=path
        )
        payload = read_json(
            self.output_root
            / "mobile/assets/datasets/restrictions/restrictions_v1.json"
        )
        args = (payload, "co-nar-pasto", "car", "private", "A1")
        self.assertEqual(
            evaluate(*args, datetime.fromisoformat("2026-09-07T21:59:00+00:00")),
            "allowed",
        )
        self.assertEqual(
            evaluate(*args, datetime.fromisoformat("2026-09-07T22:00:00+00:00")),
            "restricted",
        )
        self.assertEqual(
            evaluate(*args, datetime.fromisoformat("2026-09-08T01:59:00+00:00")),
            "restricted",
        )
        self.assertEqual(
            evaluate(*args, datetime.fromisoformat("2026-09-08T02:00:00+00:00")),
            "allowed",
        )
        self.assertEqual(
            evaluate(*args, datetime.fromisoformat("2026-09-08T02:01:00+00:00")),
            "stale",
        )

    def test_reviewed_compile_is_byte_identical_on_second_run(self):
        path = self.decision_path(self.complete_pasto_decision())
        compiler.compile_release(
            SOURCE_PACKAGE, self.output_root, reviewed_decisions_path=path
        )
        outputs = [
            self.output_root / item
            for item in (
                *compiler.OUTPUT_PATHS,
                "mobile/assets/datasets/restrictions/restrictions_v1.json",
            )
        ]
        first = {output: sha256(output) for output in outputs}

        compiler.compile_release(
            SOURCE_PACKAGE, self.output_root, reviewed_decisions_path=path
        )

        self.assertEqual(first, {output: sha256(output) for output in outputs})

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
