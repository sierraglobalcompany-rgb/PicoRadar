#!/usr/bin/env python3
"""Compile audited VIAJE-R2 staging data into conservative local artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import unicodedata
from pathlib import Path


RELEASE_VERSION = "2026.09.05-viaje-r2"
GENERATED_AT = "2026-09-05T00:00:00Z"
APPROVED_SOURCE_HASHES = {
    "pico_colombia_source_v1.json": (
        "fb104432e37d9ad5a9ee44bbbc0546d48e68486b1dc333e0f1d373548d1ad6cf"
    ),
    "tolls_inventory_v1.json": (
        "f0201c940f921064598e498b5f5e609686d3e5bfeb99531c79804d3f9d1ee74a"
    ),
    "publication_holds.json": (
        "86112ec582297a8b6f898213c57ebb04ba7593031431db2ae4dfe997f4964c90"
    ),
}
OUTPUT_PATHS = (
    "mobile/assets/catalogs/tolls_inventory_v1.json",
    "data/releases/viaje_r2/restriction_decision_ledger_v1.json",
    "data/releases/viaje_r2/toll_decision_ledger_v1.json",
    "data/releases/viaje_r2/local_test/manifest.json",
    "data/releases/viaje_r2/local_test/compile_report.json",
)
COMMON_RESTRICTION_REASONS = (
    "legal_validity_unverified",
    "holiday_policy_unverified",
    "freshness_unverified",
    "registration_scope_unverified",
)


def _read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"JSON object required: {path}")
    return value


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: Path) -> str:
    return _sha256_bytes(path.read_bytes())


def _write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
        allow_nan=False,
    ).encode("utf-8") + b"\n"
    path.write_bytes(encoded)


def _normalized(value: object) -> str:
    text = "".join(
        character
        for character in unicodedata.normalize("NFKD", str(value or ""))
        if not unicodedata.combining(character)
    ).lower()
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def _unique_reasons(*groups: object) -> list[str]:
    result = []
    for group in groups:
        values = group if isinstance(group, (list, tuple)) else (group,)
        for value in values:
            if isinstance(value, str) and value and value not in result:
                result.append(value)
    return sorted(result)


def _verify_staging(source_package: Path) -> None:
    review = _read_json(source_package / "data/staging/MANIFEST_REVIEW.json")
    reviewed = {entry["path"]: entry for entry in review.get("files", [])}
    if review.get("runtimeImportAllowed") is not False:
        raise ValueError("Staging package must remain review-only")
    for name, approved_hash in APPROVED_SOURCE_HASHES.items():
        path = source_package / "data/staging" / name
        actual_hash = _sha256_file(path)
        if actual_hash != approved_hash:
            raise ValueError(f"Unapproved staging bytes for {name}: {actual_hash}")
        entry = reviewed.get(name)
        if not entry or entry.get("sha256") != actual_hash:
            raise ValueError(f"Review manifest mismatch for {name}")


def _geography_lookup(repo_root: Path) -> dict[tuple[str, str], dict]:
    catalog = _read_json(
        repo_root / "mobile/assets/catalogs/colombia_trip_municipalities_v1.json"
    )
    matches: dict[tuple[str, str], list[dict]] = {}
    for record in catalog.get("records", []):
        key = (_normalized(record.get("department")), _normalized(record.get("municipality")))
        matches.setdefault(key, []).append(record)
    return {
        key: records[0]
        for key, records in matches.items()
        if len(records) == 1
    }


def _mapped_geography(city: dict, lookup: dict[tuple[str, str], dict]) -> dict:
    record = lookup.get((_normalized(city.get("department")), _normalized(city.get("city"))))
    if record is None:
        return {"divipolaCode": None, "appJurisdictionId": None}
    return {
        "divipolaCode": record.get("code"),
        "appJurisdictionId": record.get("jurisdictionId"),
    }


def _restriction_ledger(pico: dict, repo_root: Path, restriction_hash: str) -> dict:
    geography = _geography_lookup(repo_root)
    coverage_decisions = []
    mapped_ids = set()
    for city in pico.get("jurisdictions", []):
        mapped = _mapped_geography(city, geography)
        if mapped["appJurisdictionId"]:
            mapped_ids.add(mapped["appJurisdictionId"])
        for coverage in city.get("coverages", []):
            coverage_decisions.append(
                {
                    "sourceCoverageId": (
                        f"{city['sourceJurisdictionKey']}:{coverage['sourceVehicleType']}"
                    ),
                    "sourceJurisdictionKey": city["sourceJurisdictionKey"],
                    "department": city["department"],
                    "city": city["city"],
                    **mapped,
                    "sourceVehicleType": coverage["sourceVehicleType"],
                    "appVehicleKindCandidate": coverage.get("appVehicleKindCandidate"),
                    "appServiceTypeCandidate": coverage.get("appServiceTypeCandidate"),
                    "sourceDisposition": coverage["sourceDisposition"],
                    "sourceStatusRaw": coverage.get("sourceStatusRaw"),
                    "decision": "quarantined",
                    "publishable": False,
                    "quarantineReasons": _unique_reasons(
                        COMMON_RESTRICTION_REASONS,
                        coverage.get("blockingReasons", []),
                        "runtime_coverage_incomplete",
                    ),
                    "sourceUrls": coverage.get("sourceUrls", []),
                    "sourceRef": coverage["sourceRef"],
                }
            )

    dated_decisions = []
    for row in pico.get("datedSchedules", []):
        mapped = _mapped_geography(row, geography)
        reasons = [row["sourcePublicationDecision"], *COMMON_RESTRICTION_REASONS]
        if _normalized(row.get("sourcePublicationFlagRaw")).startswith("no"):
            reasons.append("source_explicit_no_publish")
        dated_decisions.append(
            {
                "sourceRecordId": row["sourceRecordId"],
                "sourceJurisdictionKey": row["sourceJurisdictionKey"],
                "department": row["department"],
                "city": row["city"],
                **mapped,
                "vehicleTypeRaw": row.get("vehicleTypeRaw"),
                "vehicleTypeCandidate": row.get("vehicleTypeCandidate"),
                "date": row["date"],
                "sourcePublicationFlagRaw": row.get("sourcePublicationFlagRaw"),
                "sourcePublicationDecision": row["sourcePublicationDecision"],
                "decision": "quarantined",
                "publishable": False,
                "quarantineReasons": _unique_reasons(reasons),
                "sourceUrls": row.get("sourceUrls", []),
                "sourceRef": row["sourceRef"],
            }
        )

    if len(coverage_decisions) != 219 or len(dated_decisions) != 261:
        raise ValueError("Restriction source accounting changed")
    explicit_holds = sum(
        "source_explicit_no_publish" in row["quarantineReasons"]
        for row in dated_decisions
    )
    if explicit_holds != 74:
        raise ValueError("Explicit NO PUBLICAR accounting changed")

    return {
        "schemaVersion": 1,
        "ledgerKey": "viaje_r2_restriction_decisions",
        "version": RELEASE_VERSION,
        "generatedAt": GENERATED_AT,
        "sourceSnapshotDate": pico["sourceSnapshotDate"],
        "decisionPolicy": "all_supplied_coverages_quarantined",
        "existingBundledRestrictionsPreserved": True,
        "existingBundledRestrictionsSha256": restriction_hash,
        "newRuntimeRulesPublished": 0,
        "mappedAppJurisdictionIds": sorted(mapped_ids),
        "coverageDecisions": coverage_decisions,
        "datedScheduleDecisions": dated_decisions,
    }


def _toll_asset(tolls: dict) -> dict:
    records = []
    ids = set()
    tariff_cells = 0
    for source in tolls.get("records", []):
        record = dict(source)
        record["recordKind"] = "physical_station"
        record["chargeEventStatus"] = "unverified"
        if record["id"] in ids:
            raise ValueError(f"Duplicate toll id: {record['id']}")
        ids.add(record["id"])
        location = record.get("location", {})
        latitude = location.get("latitude")
        longitude = location.get("longitude")
        if not isinstance(latitude, (int, float)) or not -5 <= latitude <= 14:
            raise ValueError(f"Invalid toll latitude: {record['id']}")
        if not isinstance(longitude, (int, float)) or not -82 <= longitude <= -66:
            raise ValueError(f"Invalid toll longitude: {record['id']}")
        tariffs = record.get("tariffsBySourceCategoryCOP")
        if not isinstance(tariffs, dict) or set(tariffs) != {
            f"category_{index}" for index in range(1, 8)
        }:
            raise ValueError(f"Seven tariff categories required: {record['id']}")
        tariff_cells += len(tariffs)
        if any(value is not None for value in tariffs.values()):
            raise ValueError(f"Tariff publication is not authorized: {record['id']}")
        if record.get("chargeEventVerified") is not False:
            raise ValueError(f"Charge event cannot be inferred: {record['id']}")
        records.append(record)
    if len(records) != 184 or tariff_cells != 1288:
        raise ValueError("Toll source accounting changed")
    return {
        "schemaVersion": 1,
        "datasetKey": "tolls_inventory",
        "version": RELEASE_VERSION,
        "generatedAt": GENERATED_AT,
        "sourceSnapshotDate": tolls["sourceSnapshotDate"],
        "source": tolls["source"],
        "currency": "COP",
        "inventoryScope": "physical_station_inventory_only",
        "mapInventoryAvailable": True,
        "liveTariffsAvailable": False,
        "records": records,
    }


def _toll_ledger(asset: dict) -> dict:
    decisions = []
    for row in asset["records"]:
        decisions.append(
            {
                "id": row["id"],
                "name": row["name"],
                "decision": "informational_only",
                "reason": "physical_station_inventory_not_verified_charge_event",
                "operationStatusRaw": row["operationStatusRaw"],
                "operationClassification": row["operationClassification"],
                "chargeGroupRaw": row.get("chargeGroupRaw"),
                "routeCountingRuleRaw": row.get("routeCountingRuleRaw"),
                "coverageOriginRaw": row.get("coverageOriginRaw"),
                "inventorySource": row.get("inventorySource"),
                "gpsSource": row.get("gpsSource"),
                "sourceRef": row["sourceRef"],
            }
        )
    return {
        "schemaVersion": 1,
        "ledgerKey": "viaje_r2_toll_decisions",
        "version": RELEASE_VERSION,
        "generatedAt": GENERATED_AT,
        "sourceSnapshotDate": asset["sourceSnapshotDate"],
        "physicalStationsPublished": len(decisions),
        "activeChargesPublished": 0,
        "verifiedChargeEventsPublished": 0,
        "tariffCellsPublished": 0,
        "tariffCellsNull": 1288,
        "recordDecisions": decisions,
    }


def compile_release(source_package: Path, repo_root: Path) -> dict:
    source_package = Path(source_package).resolve()
    repo_root = Path(repo_root).resolve()
    _verify_staging(source_package)

    pico = _read_json(source_package / "data/staging/pico_colombia_source_v1.json")
    tolls = _read_json(source_package / "data/staging/tolls_inventory_v1.json")
    source_counts = _read_json(source_package / "reports/SOURCE_COUNTS.json")
    if pico.get("automaticActivationAuthorized") is not False:
        raise ValueError("Restriction staging activation must remain disabled")
    if tolls.get("automaticActivationAuthorized") is not False:
        raise ValueError("Toll staging activation must remain disabled")
    if source_counts.get("runtimeRestrictionsEmitted") is not False:
        raise ValueError("Source package unexpectedly emits runtime restrictions")

    restriction_path = (
        repo_root / "mobile/assets/datasets/restrictions/restrictions_v1.json"
    )
    restriction_bytes = restriction_path.read_bytes()
    restriction_payload = json.loads(restriction_bytes.decode("utf-8"))
    restriction_hash = _sha256_bytes(restriction_bytes)

    restriction_ledger = _restriction_ledger(pico, repo_root, restriction_hash)
    toll_asset = _toll_asset(tolls)
    toll_ledger = _toll_ledger(toll_asset)

    toll_path = repo_root / OUTPUT_PATHS[0]
    restriction_ledger_path = repo_root / OUTPUT_PATHS[1]
    toll_ledger_path = repo_root / OUTPUT_PATHS[2]
    manifest_path = repo_root / OUTPUT_PATHS[3]
    report_path = repo_root / OUTPUT_PATHS[4]
    _write_json(toll_path, toll_asset)
    _write_json(restriction_ledger_path, restriction_ledger)
    _write_json(toll_ledger_path, toll_ledger)

    manifest = {
        "schemaVersion": 1,
        "generatedAt": GENERATED_AT,
        "minAppVersion": "1.0.0",
        "distribution": "local_simulation_only",
        "serverPublished": False,
        "datasets": {
            "restrictions": {
                "version": restriction_payload["version"],
                "url": "/assets/datasets/restrictions/restrictions_v1.json",
                "sha256": restriction_hash,
                "sourceTimestamp": restriction_payload["generatedAt"],
            },
            "tolls_inventory": {
                "version": RELEASE_VERSION,
                "url": "/assets/catalogs/tolls_inventory_v1.json",
                "sha256": _sha256_file(toll_path),
                "sourceTimestamp": GENERATED_AT,
            },
        },
        "features": {"ads": False, "cloud": False, "paidDocuments": False},
    }
    _write_json(manifest_path, manifest)

    report = {
        "schemaVersion": 1,
        "reportKey": "viaje_r2_local_compile",
        "version": RELEASE_VERSION,
        "generatedAt": GENERATED_AT,
        "distribution": "local_simulation_only",
        "serverPublished": False,
        "stagingHashesVerified": APPROVED_SOURCE_HASHES,
        "restrictions": {
            "existingAssetPreserved": True,
            "existingAssetSha256": restriction_hash,
            "newRulesPublished": 0,
            "coveragesQuarantined": 219,
            "datedSchedulesQuarantined": 261,
            "explicitNoPublishSchedules": 74,
        },
        "tolls": {
            "physicalStationsPublished": 184,
            "verifiedChargeEventsPublished": 0,
            "activeChargesPublished": 0,
            "tariffValuesPublished": 0,
        },
        "tariffCellsNull": 1288,
        "artifacts": {
            str(path.relative_to(repo_root)).replace("\\", "/"): _sha256_file(path)
            for path in (
                toll_path,
                restriction_ledger_path,
                toll_ledger_path,
                manifest_path,
            )
        },
        "unresolvedLegalGates": list(COMMON_RESTRICTION_REASONS),
    }
    _write_json(report_path, report)

    if restriction_path.read_bytes() != restriction_bytes:
        raise RuntimeError("Bundled restrictions bytes changed during compilation")
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-package", required=True, type=Path)
    parser.add_argument(
        "--repo-root", type=Path, default=Path(__file__).resolve().parents[1]
    )
    args = parser.parse_args()
    report = compile_release(args.source_package, args.repo_root)
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
