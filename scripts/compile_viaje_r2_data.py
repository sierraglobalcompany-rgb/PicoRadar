#!/usr/bin/env python3
"""Compile audited VIAJE-R2 staging data into conservative local artifacts."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import unicodedata
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse


RELEASE_VERSION = "2026.09.05-viaje-r2"
GENERATED_AT = "2026-09-05T00:00:00Z"
PUBLICATION_REVISION = 1
REVIEW_DECISIONS_PATH = (
    "data/releases/viaje_r2/reviewed_restriction_decisions_v1.json"
)
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
REVIEW_DECISIONS = {
    "source_blocked",
    "unknown_not_absence",
    "needs_evidence",
    "verified_executable",
    "informational_only",
}
GEOGRAPHY_ALIASES = {
    ("co-source:bogota-d-c:bogota", "Bogotá D.C.", "Bogotá"): (
        "Bogotá, D.C.",
        "Bogotá, D.C.",
    ),
    ("co-source:bolivar:cartagena", "Bolívar", "Cartagena"): (
        "Bolívar",
        "Cartagena de Indias",
    ),
    (
        "co-source:cordoba:santa-cruz-de-lorica",
        "Córdoba",
        "Santa Cruz de Lorica",
    ): ("Córdoba", "Lorica"),
    ("co-source:norte-de-santander:cucuta", "Norte de Santander", "Cúcuta"): (
        "Norte de Santander",
        "San José de Cúcuta",
    ),
    ("co-source:valle-del-cauca:cali", "Valle del Cauca", "Cali"): (
        "Valle del Cauca",
        "Santiago de Cali",
    ),
}


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


def _portable_path(path: Path, repo_root: Path) -> str:
    try:
        value = path.relative_to(repo_root)
    except ValueError:
        value = Path(path.name)
    return str(value).replace("\\", "/")


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


def _source_review_decision(source_disposition: object) -> str:
    normalized = _normalized(source_disposition)
    if "unknown not absence" in normalized:
        return "unknown_not_absence"
    if "blocked" in normalized:
        return "source_blocked"
    if "informational" in normalized:
        return "informational_only"
    return "needs_evidence"


def _is_https_url(value: object) -> bool:
    if not isinstance(value, str):
        return False
    parsed = urlparse(value)
    return parsed.scheme == "https" and bool(parsed.netloc)


def _iso_datetime(value: object) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _read_reviewed_decisions(path: Path | None) -> dict:
    if path is None or not path.is_file():
        return {
            "schemaVersion": 1,
            "reviewVersion": None,
            "reviewedAt": None,
            "reviewer": None,
            "decisions": [],
        }
    payload = _read_json(path)
    if payload.get("schemaVersion") != 1:
        raise ValueError("Reviewed decisions schemaVersion must be 1")
    for field in ("reviewVersion", "reviewedAt", "reviewer"):
        if not isinstance(payload.get(field), str) or not payload[field]:
            raise ValueError(f"Reviewed decisions require {field}")
    decisions = payload.get("decisions")
    if not isinstance(decisions, list):
        raise ValueError("Reviewed decisions must contain a decisions list")
    ids = [row.get("sourceCoverageId") for row in decisions if isinstance(row, dict)]
    if len(ids) != len(decisions) or len(set(ids)) != len(ids):
        raise ValueError("Reviewed decisions require unique sourceCoverageId values")
    return payload


def _review_validation_reasons(
    decision: dict,
    source_coverage: dict,
    mapped: dict,
    dated_by_id: dict[str, dict],
) -> list[str]:
    reasons = []
    for field in (
        "sourceRef",
        "originalValue",
        "interpretedValue",
        "officialSourceUrl",
        "evidenceSummary",
        "consultedAt",
        "legalValidity",
        "decision",
        "reviewer",
        "snapshotAction",
    ):
        value = decision.get(field)
        if value is None or value == "" or value == {}:
            reasons.append(f"review_missing_{field}")
    if decision.get("sourceRef") != source_coverage.get("sourceRef"):
        reasons.append("review_source_ref_mismatch")
    if not _is_https_url(decision.get("officialSourceUrl")):
        reasons.append("review_official_source_url_invalid")
    if decision.get("decision") not in REVIEW_DECISIONS:
        reasons.append("review_decision_invalid")
    if decision.get("snapshotAction") not in {"hold", "add", "update", "maintain"}:
        reasons.append("review_snapshot_action_invalid")

    source_record_ids = decision.get("sourceRecordIds", [])
    if not isinstance(source_record_ids, list):
        reasons.append("review_source_record_ids_invalid")
        source_record_ids = []
    for source_record_id in source_record_ids:
        source_record = dated_by_id.get(source_record_id)
        if source_record is None:
            reasons.append("review_source_record_unknown")
        elif _normalized(source_record.get("sourcePublicationFlagRaw")).startswith("no"):
            reasons.append("source_explicit_no_publish")
    source_jurisdiction_key = decision["sourceCoverageId"].rsplit(":", 1)[0]
    source_vehicle_type = source_coverage.get("sourceVehicleType")
    related_dated_rows = (
        row
        for row in dated_by_id.values()
        if row.get("sourceJurisdictionKey") == source_jurisdiction_key
        and row.get("vehicleTypeCandidate") == source_vehicle_type
    )
    if any(
        _normalized(row.get("sourcePublicationFlagRaw")).startswith("no")
        for row in related_dated_rows
    ):
        reasons.append("source_explicit_no_publish")

    if decision.get("decision") != "verified_executable":
        return _unique_reasons(reasons, decision.get("blockers", []))

    runtime = decision.get("runtimeCoverage")
    if not isinstance(runtime, dict):
        return _unique_reasons(reasons, "runtime_coverage_missing")
    for field in (
        "jurisdictionId",
        "jurisdictionName",
        "vehicleKind",
        "serviceType",
        "verifiedAt",
        "staleAfter",
        "sourceUrls",
        "rules",
    ):
        value = runtime.get(field)
        if value is None or value == "" or value == []:
            reasons.append(f"runtime_coverage_missing_{field}")
    if runtime.get("jurisdictionId") != mapped.get("appJurisdictionId"):
        reasons.append("runtime_jurisdiction_mismatch")
    if runtime.get("vehicleKind") != source_coverage.get("appVehicleKindCandidate"):
        reasons.append("runtime_vehicle_kind_mismatch")
    if runtime.get("serviceType") != source_coverage.get("appServiceTypeCandidate"):
        reasons.append("runtime_service_type_mismatch")
    source_urls = runtime.get("sourceUrls")
    if not isinstance(source_urls, list) or not source_urls or not all(
        _is_https_url(url) for url in source_urls
    ):
        reasons.append("runtime_source_urls_invalid")
    elif decision.get("officialSourceUrl") not in source_urls:
        reasons.append("runtime_official_source_missing")
    if _iso_datetime(runtime.get("verifiedAt")) is None:
        reasons.append("runtime_verified_at_invalid")
    stale_after = _iso_datetime(runtime.get("staleAfter"))
    if stale_after is None:
        reasons.append("runtime_stale_after_invalid")

    legal = decision.get("legalValidity")
    if not isinstance(legal, dict):
        reasons.append("legal_validity_invalid")
        legal = {}
    for field in ("validFrom", "validUntil", "sourceTimestamp"):
        if _iso_datetime(legal.get(field)) is None:
            reasons.append(f"legal_validity_missing_{field}")
    legal_from = _iso_datetime(legal.get("validFrom"))
    legal_until = _iso_datetime(legal.get("validUntil"))
    if legal_from and legal_until and legal_from > legal_until:
        reasons.append("legal_validity_range_invalid")

    rules = runtime.get("rules")
    if not isinstance(rules, list) or not rules:
        reasons.append("runtime_rules_missing")
        rules = []
    rule_ids = set()
    for rule in rules:
        if not isinstance(rule, dict):
            reasons.append("runtime_rule_invalid")
            continue
        for field in (
            "id",
            "priority",
            "effect",
            "validFrom",
            "validUntil",
            "digitPosition",
            "digits",
            "timeWindows",
            "appliesOnHolidays",
            "sourceUrl",
            "verifiedAt",
        ):
            if field not in rule or rule[field] is None or rule[field] == []:
                reasons.append(f"runtime_rule_missing_{field}")
        rule_id = rule.get("id")
        if not isinstance(rule_id, str) or not rule_id or rule_id in rule_ids:
            reasons.append("runtime_rule_id_invalid")
        rule_ids.add(rule_id)
        if rule.get("effect") != "restrict":
            reasons.append("runtime_rule_effect_invalid")
        if rule.get("digitPosition") not in {"firstNumeric", "lastNumeric"}:
            reasons.append("runtime_rule_digit_position_invalid")
        digits = rule.get("digits")
        if not isinstance(digits, list) or not digits or any(
            not isinstance(digit, int) or digit < 0 or digit > 9 for digit in digits
        ):
            reasons.append("runtime_rule_digits_invalid")
        windows = rule.get("timeWindows")
        if not isinstance(windows, list) or not windows:
            reasons.append("runtime_rule_windows_invalid")
            windows = []
        for window in windows:
            if not isinstance(window, dict) or not all(
                isinstance(window.get(field), int)
                and 0 <= window[field] <= 1440
                for field in ("startMinute", "endMinute")
            ):
                reasons.append("runtime_rule_window_invalid")
        rule_from = _iso_datetime(rule.get("validFrom"))
        rule_until = _iso_datetime(rule.get("validUntil"))
        if rule_from is None or rule_until is None or rule_from > rule_until:
            reasons.append("runtime_rule_validity_invalid")
        elif legal_from and legal_until and (
            rule_from < legal_from or rule_until > legal_until
        ):
            reasons.append("runtime_rule_outside_legal_validity")
        if rule.get("sourceUrl") != decision.get("officialSourceUrl"):
            reasons.append("runtime_rule_source_mismatch")
        if rule.get("verifiedAt") != runtime.get("verifiedAt"):
            reasons.append("runtime_rule_verified_at_mismatch")
        if not isinstance(rule.get("appliesOnHolidays"), bool):
            reasons.append("runtime_rule_holiday_policy_invalid")
    if stale_after and legal_until:
        comparable_stale = stale_after.replace(tzinfo=None)
        comparable_until = legal_until.replace(tzinfo=None)
        if comparable_stale <= comparable_until:
            reasons.append("runtime_stale_after_not_after_validity")
    return _unique_reasons(reasons)


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
    source_identity = (
        city.get("sourceJurisdictionKey"),
        city.get("department"),
        city.get("city"),
    )
    target = GEOGRAPHY_ALIASES.get(source_identity)
    if target is None:
        target = (city.get("department"), city.get("city"))
    record = lookup.get((_normalized(target[0]), _normalized(target[1])))
    if record is None:
        return {"divipolaCode": None, "appJurisdictionId": None}
    return {
        "divipolaCode": record.get("code"),
        "appJurisdictionId": record.get("jurisdictionId"),
    }


def _restriction_ledger(
    pico: dict,
    repo_root: Path,
    restriction_hash: str,
    reviewed_decisions: dict,
) -> tuple[dict, list[dict]]:
    geography = _geography_lookup(repo_root)
    coverage_decisions = []
    source_coverages = {}
    mapped_by_coverage = {}
    mapped_ids = set()
    for city in pico.get("jurisdictions", []):
        mapped = _mapped_geography(city, geography)
        if mapped["appJurisdictionId"]:
            mapped_ids.add(mapped["appJurisdictionId"])
        for coverage in city.get("coverages", []):
            source_coverage_id = (
                f"{city['sourceJurisdictionKey']}:{coverage['sourceVehicleType']}"
            )
            source_coverages[source_coverage_id] = coverage
            mapped_by_coverage[source_coverage_id] = mapped
            coverage_decisions.append(
                {
                    "sourceCoverageId": source_coverage_id,
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
                    "reviewDecision": _source_review_decision(
                        coverage["sourceDisposition"]
                    ),
                    "publishable": False,
                    "quarantineReasons": _unique_reasons(
                        COMMON_RESTRICTION_REASONS,
                        coverage.get("blockingReasons", []),
                        "runtime_coverage_incomplete",
                    ),
                    "sourceUrls": coverage.get("sourceUrls", []),
                    "sourceRef": coverage["sourceRef"],
                    "sourceProjection": dict(coverage),
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
                "sourceProjection": dict(row),
            }
        )

    rotation_decisions = []
    rotation_keys = set()
    for row in pico.get("rotationsAndValidity", []):
        source_key = row["sourceJurisdictionKey"]
        if source_key in rotation_keys:
            raise ValueError(f"Duplicate rotation/validity source key: {source_key}")
        rotation_keys.add(source_key)
        if not row.get("valuesBySourceHeader"):
            raise ValueError(
                f"Rotation/validity source values are required: {source_key}"
            )
        rotation_decisions.append(
            {
                "sourceJurisdictionKey": source_key,
                "decision": "informational_only",
                "publishable": False,
                "runtimePublished": False,
                "quarantineReasons": _unique_reasons(
                    COMMON_RESTRICTION_REASONS,
                    "rotation_validity_is_not_a_runtime_rule",
                ),
                "sourceRef": row["sourceRef"],
                "sourceProjection": dict(row),
            }
        )

    if (
        len(coverage_decisions) != 219
        or len(dated_decisions) != 261
        or len(rotation_decisions) != 73
    ):
        raise ValueError("Restriction source accounting changed")
    explicit_holds = sum(
        "source_explicit_no_publish" in row["quarantineReasons"]
        for row in dated_decisions
    )
    if explicit_holds != 74:
        raise ValueError("Explicit NO PUBLICAR accounting changed")

    dated_by_id = {row["sourceRecordId"]: row for row in pico["datedSchedules"]}
    coverage_by_id = {row["sourceCoverageId"]: row for row in coverage_decisions}
    approved = []
    for review in reviewed_decisions["decisions"]:
        source_coverage_id = review["sourceCoverageId"]
        source_coverage = source_coverages.get(source_coverage_id)
        ledger_row = coverage_by_id.get(source_coverage_id)
        if source_coverage is None or ledger_row is None:
            raise ValueError(
                f"Reviewed decision references unknown coverage: {source_coverage_id}"
            )
        reasons = _review_validation_reasons(
            review,
            source_coverage,
            mapped_by_coverage[source_coverage_id],
            dated_by_id,
        )
        requested = review.get("decision")
        accepted = requested == "verified_executable" and not reasons
        ledger_row["reviewDecision"] = (
            "verified_executable" if accepted else requested
        )
        if requested == "verified_executable" and reasons:
            ledger_row["reviewDecision"] = "needs_evidence"
        ledger_row["decision"] = "published" if accepted else "quarantined"
        ledger_row["publishable"] = accepted
        ledger_row["runtimePublished"] = accepted
        ledger_row["quarantineReasons"] = [] if accepted else _unique_reasons(
            ledger_row["quarantineReasons"], reasons, review.get("blockers", [])
        )
        ledger_row["reviewProjection"] = copy.deepcopy(review)
        if accepted:
            approved.append(copy.deepcopy(review))

    ledger = {
        "schemaVersion": 1,
        "ledgerKey": "viaje_r2_restriction_decisions",
        "version": reviewed_decisions["reviewVersion"] or RELEASE_VERSION,
        "generatedAt": reviewed_decisions["reviewedAt"] or GENERATED_AT,
        "sourceSnapshotDate": pico["sourceSnapshotDate"],
        "decisionPolicy": "selective_reviewed_publication_fail_closed",
        "reviewedDecisionCount": len(reviewed_decisions["decisions"]),
        "existingBundledRestrictionsPreserved": not approved,
        "existingBundledRestrictionsSha256": restriction_hash,
        "newRuntimeRulesPublished": sum(
            len(row["runtimeCoverage"]["rules"]) for row in approved
        ),
        "mappedAppJurisdictionIds": sorted(mapped_ids),
        "coverageDecisions": coverage_decisions,
        "datedScheduleDecisions": dated_decisions,
        "rotationValidityDecisions": rotation_decisions,
    }
    return ledger, approved


def _apply_reviewed_coverages(
    restriction_payload: dict,
    approved: list[dict],
    reviewed_decisions: dict,
) -> tuple[dict, dict]:
    result = copy.deepcopy(restriction_payload)
    snapshot_diff = {"added": 0, "updated": 0, "maintained": 0, "removed": 0}
    for decision in approved:
        runtime = copy.deepcopy(decision["runtimeCoverage"])
        jurisdiction_id = runtime.pop("jurisdictionId")
        jurisdiction_name = runtime.pop("jurisdictionName")
        jurisdiction = next(
            (
                row
                for row in result["jurisdictions"]
                if row["id"] == jurisdiction_id
            ),
            None,
        )
        if jurisdiction is None:
            jurisdiction = {
                "id": jurisdiction_id,
                "name": jurisdiction_name,
                "coverages": [],
            }
            result["jurisdictions"].append(jurisdiction)
        existing_index = next(
            (
                index
                for index, row in enumerate(jurisdiction["coverages"])
                if row["vehicleKind"] == runtime["vehicleKind"]
                and row["serviceType"] == runtime["serviceType"]
            ),
            None,
        )
        if existing_index is None:
            jurisdiction["coverages"].append(runtime)
        else:
            jurisdiction["coverages"][existing_index] = runtime
        action = decision["snapshotAction"]
        if action == "add":
            snapshot_diff["added"] += 1
        elif action == "update":
            snapshot_diff["updated"] += 1
        else:
            snapshot_diff["maintained"] += 1
    if approved:
        result["version"] = reviewed_decisions["reviewVersion"]
        result["generatedAt"] = reviewed_decisions["reviewedAt"]
    return result, snapshot_diff


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


def compile_release(
    source_package: Path,
    repo_root: Path,
    reviewed_decisions_path: Path | None = None,
) -> dict:
    source_package = Path(source_package).resolve()
    repo_root = Path(repo_root).resolve()
    if reviewed_decisions_path is None:
        candidate = repo_root / REVIEW_DECISIONS_PATH
        reviewed_decisions_path = candidate if candidate.is_file() else None
    elif reviewed_decisions_path is not None:
        reviewed_decisions_path = Path(reviewed_decisions_path).resolve()
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
    reviewed_decisions = _read_reviewed_decisions(reviewed_decisions_path)
    compile_version = reviewed_decisions["reviewVersion"] or RELEASE_VERSION
    compile_generated_at = reviewed_decisions["reviewedAt"] or GENERATED_AT

    restriction_ledger, approved = _restriction_ledger(
        pico, repo_root, restriction_hash, reviewed_decisions
    )
    restriction_payload, snapshot_diff = _apply_reviewed_coverages(
        restriction_payload, approved, reviewed_decisions
    )
    toll_asset = _toll_asset(tolls)
    toll_ledger = _toll_ledger(toll_asset)

    toll_path = repo_root / OUTPUT_PATHS[0]
    restriction_ledger_path = repo_root / OUTPUT_PATHS[1]
    toll_ledger_path = repo_root / OUTPUT_PATHS[2]
    manifest_path = repo_root / OUTPUT_PATHS[3]
    report_path = repo_root / OUTPUT_PATHS[4]
    if approved:
        _write_json(restriction_path, restriction_payload)
    restriction_output_hash = _sha256_file(restriction_path)
    if approved:
        restriction_ledger["existingBundledRestrictionsSha256"] = None
    restriction_ledger["resultBundledRestrictionsSha256"] = restriction_output_hash
    _write_json(toll_path, toll_asset)
    _write_json(restriction_ledger_path, restriction_ledger)
    _write_json(toll_ledger_path, toll_ledger)

    manifest = {
        "schemaVersion": 1,
        "generatedAt": compile_generated_at,
        "minAppVersion": "1.0.0",
        "distribution": "local_simulation_only",
        "serverPublished": False,
        "datasets": {
            "restrictions": {
                "version": restriction_payload["version"],
                "url": "/assets/datasets/restrictions/restrictions_v1.json",
                "sha256": restriction_output_hash,
                "sourceTimestamp": restriction_payload["generatedAt"],
                "publicationRevision": PUBLICATION_REVISION,
            },
            "tolls_inventory": {
                "version": RELEASE_VERSION,
                "url": "/assets/catalogs/tolls_inventory_v1.json",
                "sha256": _sha256_file(toll_path),
                "sourceTimestamp": GENERATED_AT,
                "publicationRevision": PUBLICATION_REVISION,
            },
        },
        "features": {"ads": False, "cloud": False, "paidDocuments": False},
    }
    _write_json(manifest_path, manifest)

    report = {
        "schemaVersion": 1,
        "reportKey": "viaje_r2_local_compile",
        "version": compile_version,
        "generatedAt": compile_generated_at,
        "distribution": "local_simulation_only",
        "serverPublished": False,
        "stagingHashesVerified": APPROVED_SOURCE_HASHES,
        "restrictions": {
            "existingAssetPreserved": not approved,
            "existingAssetSha256": restriction_hash if not approved else None,
            "resultAssetSha256": restriction_output_hash,
            "newRulesPublished": restriction_ledger["newRuntimeRulesPublished"],
            "reviewedDecisions": len(reviewed_decisions["decisions"]),
            "verifiedExecutableDecisions": len(approved),
            "coveragesQuarantined": 219 - len(approved),
            "datedSchedulesQuarantined": 261,
            "explicitNoPublishSchedules": 74,
            "snapshotDiff": snapshot_diff,
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
    if reviewed_decisions_path is not None:
        report["reviewedDecisions"] = {
            "path": _portable_path(reviewed_decisions_path, repo_root),
            "sha256": _sha256_file(reviewed_decisions_path),
            "reviewVersion": reviewed_decisions["reviewVersion"],
        }
    _write_json(report_path, report)

    if not approved and restriction_path.read_bytes() != restriction_bytes:
        raise RuntimeError("Bundled restrictions bytes changed during compilation")
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-package", required=True, type=Path)
    parser.add_argument(
        "--repo-root", type=Path, default=Path(__file__).resolve().parents[1]
    )
    parser.add_argument("--review-decisions", type=Path)
    args = parser.parse_args()
    report = compile_release(
        args.source_package,
        args.repo_root,
        reviewed_decisions_path=args.review_decisions,
    )
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
