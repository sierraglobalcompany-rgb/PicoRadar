#!/usr/bin/env python3
"""Compile the audited owner toll tariffs into the compact Flutter asset."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (
    ROOT
    / "data"
    / "releases"
    / "tolls_tariffs_2026_09_08"
    / "tolls_tariffs_source_2026_09_08.json"
)
OUTPUT = ROOT / "mobile" / "assets" / "catalogs" / "tolls_tariffs_v1.json"

EXPECTED_WORKBOOK_SHA256 = (
    "8863b418cdd4664fc4b0a2c7eaaafde73dd88b0eea9535db7c57fcbd7f1b5a4a"
)
EXPECTED_COUNTS = {
    "stations": 184,
    "generalRates": 1300,
    "specialRates": 437,
    "candidatesOutsideBase": 9,
}
EXPECTED_CATEGORY_I = {
    "INV-GUARNE-3A941FAFD9": 18500,
    "INV-LAS-PALMAS-E8C2EE2BB5": 13500,
    "INV-COCORNA-6A6F1282D1": 18800,
    "INV-AMAGA-ABD7881C50": 25900,
}


def main() -> None:
    source_bytes = SOURCE.read_bytes()
    raw = json.loads(source_bytes.decode("utf-8"))
    _validate_source(raw)

    rates_by_station: dict[str, list[dict[str, object | None]]] = {}
    for rate in raw["generalRates"]:
        rates_by_station.setdefault(rate["stationId"], []).append(
            _general_rate(rate)
        )

    specials_by_station: dict[str, list[dict[str, object | None]]] = {}
    for rate in raw["specialRates"]:
        specials_by_station.setdefault(rate["stationId"], []).append(
            _special_rate(rate)
        )

    stations = []
    for station in raw["stations"]:
        station_id = station["id"]
        stations.append(
            {
                "id": station_id,
                "name": station["name"],
                "department": station.get("departmentReviewed"),
                "latitude": station["latitude"],
                "longitude": station["longitude"],
                "operationStatus": station.get("operationStatusRaw"),
                "publicationControl": station.get("publicationControlRaw"),
                "routeRule": station.get("routeRuleRaw"),
                "logicalChargeGroup": station.get("logicalChargeGroupRaw"),
                "evidenceQuality": station.get("evidenceQualityRaw"),
                "sourceInventoryRow": station.get("sourceInventoryRow"),
                "sourceSummaryRow": station.get("sourceSummaryRow"),
                "generalRates": sorted(
                    rates_by_station.get(station_id, []),
                    key=lambda item: str(item.get("categoryCode") or ""),
                ),
                "specialRates": sorted(
                    specials_by_station.get(station_id, []),
                    key=lambda item: (
                        str(item.get("rateType") or ""),
                        str(item.get("categoryCode") or ""),
                    ),
                ),
            }
        )

    compiled = {
        "schemaVersion": 1,
        "datasetKey": "tolls_tariffs",
        "version": raw["version"],
        "currency": raw["currency"],
        "amountUnit": raw["amountUnit"],
        "scope": "owner_tariff_catalog_by_physical_toll_id",
        "source": {
            **raw["source"],
            "jsonFileName": SOURCE.name,
            "jsonSha256": hashlib.sha256(source_bytes).hexdigest(),
        },
        "readingRules": raw.get("readingRules", {}),
        "counts": {
            "stations": len(raw["stations"]),
            "generalRates": len(raw["generalRates"]),
            "specialRates": len(raw["specialRates"]),
            "numericGeneralRates": sum(
                1
                for rate in raw["generalRates"]
                if rate.get("publishedAmountCop") is not None
            ),
            "officialGeneralRates": sum(
                1
                for rate in raw["generalRates"]
                if rate.get("sourceTypeRaw") == "Oficial"
            ),
            "secondaryGeneralRates": sum(
                1
                for rate in raw["generalRates"]
                if rate.get("sourceTypeRaw") == "Secundaria"
            ),
            "candidatesOutsideBase": len(raw.get("candidatesOutsideBase", [])),
        },
        "stations": sorted(stations, key=lambda item: str(item["id"])),
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(compiled, ensure_ascii=False, sort_keys=True, indent=2)
        + "\n",
        encoding="utf-8",
    )
    _validate_compiled(compiled)
    print(f"wrote {OUTPUT.relative_to(ROOT)}")


def _general_rate(rate: dict[str, object | None]) -> dict[str, object | None]:
    return {
        "categoryCode": rate.get("categoryCodeRaw"),
        "vehicleDescription": rate.get("vehicleDescriptionRaw"),
        "rateType": rate.get("rateTypeRaw"),
        "amountCop": rate.get("publishedAmountCop"),
        "collectionMultiplier": rate.get("collectionMultiplier"),
        "boothBaseChargeCop": rate.get("boothBaseChargeCop"),
        "dataStatus": rate.get("dataStatusRaw"),
        "sourceDate": rate.get("sourceDateRaw"),
        "sourceDatePrecision": rate.get("sourceDatePrecisionRaw"),
        "consultedOn": rate.get("consultedOnRaw"),
        "sourceType": rate.get("sourceTypeRaw"),
        "amountSourceId": rate.get("amountSourceId"),
        "amountSourceUrl": rate.get("amountSourceUrl"),
        "chargeSourceUrl": rate.get("chargeSourceUrl"),
        "conditions": rate.get("conditionsRaw"),
        "publicationControl": rate.get("publicationControlRaw"),
        "sourceRow": rate.get("sourceRow"),
    }


def _special_rate(rate: dict[str, object | None]) -> dict[str, object | None]:
    return {
        "categoryCode": rate.get("categoryCodeRaw"),
        "rateType": rate.get("rateTypeRaw"),
        "amountCop": rate.get("publishedAmountCop"),
        "conditionalChargeCop": rate.get("conditionalChargeCop"),
        "validityStatus": rate.get("validityStatusRaw"),
        "sourceDate": rate.get("sourceDateRaw"),
        "sourceDatePrecision": rate.get("sourceDatePrecisionRaw"),
        "beneficiariesCondition": rate.get("beneficiariesConditionRaw"),
        "routeControl": rate.get("routeControlRaw"),
        "sourceId": rate.get("sourceId"),
        "sourceType": rate.get("sourceTypeRaw"),
        "sourceUrl": rate.get("sourceUrl"),
        "consultedOn": rate.get("consultedOnRaw"),
        "sourceRow": rate.get("sourceRow"),
    }


def _validate_source(raw: dict[str, object]) -> None:
    if raw.get("schemaVersion") != 1:
        raise SystemExit("unexpected schemaVersion")
    if raw.get("datasetKey") != "tolls_tariffs_source":
        raise SystemExit("unexpected source datasetKey")
    if raw.get("currency") != "COP" or raw.get("amountUnit") != "whole_pesos":
        raise SystemExit("unexpected money unit")
    source = raw.get("source")
    if not isinstance(source, dict):
        raise SystemExit("missing source metadata")
    if source.get("sha256") != EXPECTED_WORKBOOK_SHA256:
        raise SystemExit("unexpected workbook sha256")
    for key, expected in EXPECTED_COUNTS.items():
        actual = len(raw[key]) if key != "candidatesOutsideBase" else len(raw.get(key, []))
        if actual != expected:
            raise SystemExit(f"{key} count mismatch: {actual} != {expected}")
    station_ids = [station["id"] for station in raw["stations"]]
    if len(station_ids) != len(set(station_ids)):
        raise SystemExit("duplicate station ids")
    for station_id, expected in EXPECTED_CATEGORY_I.items():
        amount = _find_general(raw, station_id, "I")
        if amount != expected:
            raise SystemExit(f"{station_id} category I mismatch: {amount}")


def _validate_compiled(raw: dict[str, object]) -> None:
    if raw["counts"]["numericGeneralRates"] != 1007:
        raise SystemExit("numeric general rate count mismatch")
    if raw["counts"]["officialGeneralRates"] != 793:
        raise SystemExit("official general rate count mismatch")
    if raw["counts"]["secondaryGeneralRates"] != 214:
        raise SystemExit("secondary general rate count mismatch")


def _find_general(
    raw: dict[str, object],
    station_id: str,
    category_code: str,
) -> int | None:
    for rate in raw["generalRates"]:
        if (
            rate["stationId"] == station_id
            and rate["categoryCodeRaw"] == category_code
        ):
            return rate.get("publishedAmountCop")
    return None


if __name__ == "__main__":
    main()
