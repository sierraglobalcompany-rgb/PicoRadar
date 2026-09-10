import argparse
import copy
import importlib.util
import json
import shutil
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
COMPILER_PATH = REPO_ROOT / "scripts" / "compile_viaje_r2_data.py"

spec = importlib.util.spec_from_file_location("viaje_r2_compiler", COMPILER_PATH)
compiler = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(compiler)


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _seed_output(seed_root: Path, output_root: Path) -> None:
    for relative in (
        "mobile/assets/datasets/restrictions/restrictions_v1.json",
        "mobile/assets/catalogs/colombia_trip_municipalities_v1.json",
    ):
        target = output_root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(seed_root / relative, target)


def _reviewed_decision(source_package: Path) -> dict:
    source = _read_json(
        source_package / "data/staging/pico_colombia_source_v1.json"
    )
    source_coverage_id = "co-source:antioquia:medellin:private_car"
    source_coverage = next(
        coverage
        for jurisdiction in source["jurisdictions"]
        for coverage in jurisdiction["coverages"]
        if (
            f"{jurisdiction['sourceJurisdictionKey']}:"
            f"{coverage['sourceVehicleType']}"
        )
        == source_coverage_id
    )
    source_url = source_coverage["sourceUrls"][0]
    rule = {
        "id": "NON_PRODUCTION_FIXTURE-medellin-monday",
        "priority": 1000,
        "effect": "restrict",
        "validFrom": "2026-08-03T00:00:00",
        "validUntil": "2026-12-31T23:59:59",
        "registrationOrigins": ["local", "foreign", "unknown"],
        "weekdays": [1],
        "digitPosition": "lastNumeric",
        "digits": [5, 8],
        "timeWindows": [{"startMinute": 300, "endMinute": 1200}],
        "appliesOnHolidays": False,
        "sourceUrl": source_url,
        "verifiedAt": "2026-09-06T00:00:00Z",
    }
    runtime_coverage = {
        "jurisdictionId": "co-ant-medellin",
        "jurisdictionName": "Medellin",
        "vehicleKind": "car",
        "serviceType": "private",
        "verifiedAt": "2026-09-06T00:00:00Z",
        "staleAfter": "2027-01-02T00:00:00Z",
        "sourceUrls": [source_url],
        "rules": [rule],
    }
    recurrence_source = compiler._recurrence_source_value(source_coverage)
    return {
        "sourceCoverageId": source_coverage_id,
        "sourceRef": source_coverage["sourceRef"],
        "evidenceKind": "weekly_recurrence",
        "sourceRecordIds": [],
        "originalValue": {
            "sourceCoverageSha256": compiler._canonical_sha256(source_coverage),
            "sourceRecordsSha256": compiler._canonical_sha256([]),
            "sourceRecurrenceSha256": compiler._canonical_sha256(recurrence_source),
        },
        "interpretedValue": {
            "runtimeCoverageSha256": compiler._canonical_sha256(runtime_coverage),
            "ruleEvidence": [
                {
                    "ruleId": rule["id"],
                    "sourceWeekdays": [1],
                    "reviewedSemantics": {
                        field: copy.deepcopy(rule.get(field))
                        for field in compiler.RULE_SEMANTIC_FIELDS
                    },
                }
            ],
        },
        "officialSourceUrl": source_url,
        "evidenceSummary": "Synthetic reviewed recurrence for bridge tests only.",
        "consultedAt": "2026-09-06T00:00:00Z",
        "legalValidity": {
            "status": "complete",
            "validFrom": rule["validFrom"],
            "validUntil": rule["validUntil"],
            "sourceTimestamp": "2026-08-03T00:00:00Z",
        },
        "decision": "verified_executable",
        "reviewer": "test-reviewer",
        "snapshotAction": "update",
        "blockers": [],
        "runtimeCoverage": runtime_coverage,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-package", required=True, type=Path)
    parser.add_argument("--seed-repo-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()

    _seed_output(args.seed_repo_root, args.output_root)
    decision_path = args.output_root / "reviewed_decisions.json"
    decision_path.write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "reviewVersion": "bridge-test-v1",
                "reviewedAt": "2026-09-06T00:00:00Z",
                "reviewer": "test-reviewer",
                "decisions": [_reviewed_decision(args.source_package)],
            },
            ensure_ascii=False,
            sort_keys=True,
        ),
        encoding="utf-8",
    )
    report = compiler.compile_release(
        args.source_package,
        args.output_root,
        reviewed_decisions_path=decision_path,
    )
    if report["restrictions"]["newRulesPublished"] != 1:
        raise RuntimeError("Bridge fixture did not publish exactly one TEST rule")


if __name__ == "__main__":
    main()
