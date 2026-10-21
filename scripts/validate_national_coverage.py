#!/usr/bin/env python3
"""Deterministically validate Lot EF national data contracts."""

from __future__ import annotations

import csv
import hashlib
import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load_json(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def sha256(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def validate_tramites() -> None:
    catalog = load_json("mobile/assets/catalogs/comparendos_authorities_v1.json")
    authorities = catalog["authorities"]
    summary = catalog["summary"]
    direct = [row for row in authorities if row.get("supportsRegistrationProcedures", False)]
    institutional = [
        row
        for row in authorities
        if not row.get("supportsRegistrationProcedures", False)
        and row["verificationStatus"] == "verified"
    ]
    pending = [row for row in authorities if row["verificationStatus"] == "pending"]
    require(len(authorities) == summary["inventoryEntries"] == 769, "Tramites authority count")
    require(len(catalog["sourceRecords"]) == summary["sourceRows"] == 1003, "Tramites source rows")
    require({row["id"] for row in direct} == {"co-bogota", "co-medellin"}, "Tramites direct authorities")
    require(len(institutional) == 5, "Tramites institutional fallback count")
    require(len(pending) == 762, "Tramites RUNT fallback count")
    require(catalog["registrationFallbackUrl"] == "https://www.runt.gov.co/directorio-de-actores", "Tramites RUNT fallback")


def validate_pico() -> None:
    catalog = load_json("mobile/assets/catalogs/pico_jurisdiction_catalog_v1.json")
    records = catalog["records"]
    counts = Counter(row["operationalStatus"] for row in records)
    require(len(records) == 73, "Pico municipality count")
    require(len({row["municipalityCode"] for row in records}) == 73, "Pico municipality uniqueness")
    require(counts == {"verified": 6, "conditional": 36, "expired": 2, "pending": 29}, "Pico status distribution")
    engine = {row["id"] for row in records if row["engineEnabled"]}
    require(engine == {"co-dc-bogota", "co-ant-medellin", "co-san-bucaramanga", "co-cau-popayan", "co-met-villavicencio"}, "Pico engine eligibility")
    require(all(row["operationalStatus"] == "verified" for row in records if row["engineEnabled"]), "Pico engine requires verified status")
    require(next(row for row in records if row["name"] == "Itagüí")["engineEnabled"] is False, "Itagui remains engine-disabled")
    require({row["name"] for row in records if row["operationalStatus"] == "expired"} == {"Barranquilla", "Manizales"}, "Pico expired cities")
    source_path = catalog["source"]["path"]
    require(sha256(source_path) == catalog["source"]["sha256"], "Pico workbook hash")
    require(sha256("mobile/assets/datasets/restrictions/restrictions_v1.json") == "68642a2e8fda49cf89c45d8439c6cbf5064aa176aeefe2fa3c4083c8201c4d16", "restriction engine asset changed")

    with (ROOT / "docs/data/PICO_73_OPERATIONAL_AUDIT_20260919.csv").open(encoding="utf-8", newline="") as handle:
        audit = list(csv.DictReader(handle))
    require(len(audit) == 73, "Pico audit CSV count")
    require({row["municipality_code"] for row in audit} == {row["municipalityCode"] for row in records}, "Pico audit/catalog alignment")


def validate_cameras() -> None:
    manifest = load_json("mobile/assets/datasets/cameras/cameras_manifest_v1.json")
    dataset_path = "mobile/assets/datasets/cameras/cameras_v1.json"
    dataset = load_json(dataset_path)
    records = dataset["records"]
    known = sum(row["reportedSpeedKmh"] is not None for row in records)
    require(manifest["asset"]["bytes"] == (ROOT / dataset_path).stat().st_size, "camera byte count")
    require(manifest["asset"]["sha256"] == sha256(dataset_path), "camera asset hash")
    require(len(records) == manifest["recordCount"] == 360, "camera record count")
    require(known == manifest["speedKnownCount"] == 293, "camera known speed count")
    require(len(records) - known == manifest["speedUnknownCount"] == 67, "camera unknown speed count")
    require(len({row["department"] for row in records}) == manifest["departmentCount"] == 13, "camera department count")
    require(manifest["semantics"]["snapshotOnly"] is True, "camera snapshot semantics")
    require(manifest["semantics"]["currentOperationConfirmed"] is False, "camera current operation must be unknown")


def validate_tolls() -> None:
    manifest = load_json("mobile/assets/catalogs/tolls_manifest_v1.json")
    inventory_path = "mobile/assets/catalogs/tolls_inventory_v1.json"
    tariffs_path = "mobile/assets/catalogs/tolls_tariffs_v1.json"
    inventory = load_json(inventory_path)
    tariffs = load_json(tariffs_path)
    inventory_manifest = manifest["inventory"]
    tariff_manifest = manifest["tariffs"]
    records = inventory["records"]
    operation_counts = Counter(row["operationClassification"] for row in records)
    require(inventory_manifest["asset"]["bytes"] == (ROOT / inventory_path).stat().st_size, "toll inventory bytes")
    require(inventory_manifest["asset"]["sha256"] == sha256(inventory_path), "toll inventory hash")
    require(tariff_manifest["asset"]["bytes"] == (ROOT / tariffs_path).stat().st_size, "toll tariff bytes")
    require(tariff_manifest["asset"]["sha256"] == sha256(tariffs_path), "toll tariff hash")
    require(len(records) == inventory_manifest["stationCount"] == 184, "toll station count")
    require(dict(operation_counts) == inventory_manifest["operationCounts"], "toll operation distribution")
    require(inventory_manifest["currentOperationConfirmed"] is False, "toll current operation semantics")
    require(inventory_manifest["unknownTariffStationCount"] == 184, "toll unknown inventory tariffs")
    require(all(value is None for row in records for value in row["tariffsBySourceCategoryCOP"].values()), "toll inventory unknown changed to zero/value")
    expected_tariff_counts = {
        "stationCount": 184,
        "generalRateCount": 1300,
        "numericGeneralRateCount": 1007,
        "officialGeneralRateCount": 793,
        "secondaryGeneralRateCount": 214,
        "specialRateCount": 437,
        "candidatesOutsideBase": 9,
    }
    require(all(tariff_manifest[key] == value for key, value in expected_tariff_counts.items()), "toll tariff manifest counts")
    require(tariffs["counts"] == {"candidatesOutsideBase": 9, "generalRates": 1300, "numericGeneralRates": 1007, "officialGeneralRates": 793, "secondaryGeneralRates": 214, "specialRates": 437, "stations": 184}, "toll tariff source counts")
    require(tariff_manifest["independentExternalReverification"] is False, "toll reverification must remain false")


def main() -> None:
    validate_tramites()
    validate_pico()
    validate_cameras()
    validate_tolls()
    require((ROOT / "docs/data/NATIONAL_DATA_PROVENANCE_AUDIT_20260919.md").exists(), "national provenance audit missing")
    print("PASS: national coverage validation")


if __name__ == "__main__":
    main()
