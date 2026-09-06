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
        self.assertEqual(report["tariffCellsNull"], 1288)


if __name__ == "__main__":
    unittest.main(verbosity=2)
