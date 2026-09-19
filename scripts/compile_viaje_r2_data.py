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
EVIDENCE_KINDS = {"dated_schedule", "weekly_recurrence"}
OFFICIAL_SOURCE_HOSTS = {
    "alcaldiabogota.gov.co",
    "bogota.gov.co",
    "medellin.gov.co",
    "movilidadbogota.gov.co",
    "pasto.gov.co",
    "www.alcaldiabogota.gov.co",
    "www.bogota.gov.co",
    "www.medellin.gov.co",
    "www.movilidadbogota.gov.co",
    "www.pasto.gov.co",
}
VEHICLE_KINDS = {"car", "motorcycle"}
SERVICE_TYPES = {"private", "taxi"}
REGISTRATION_ORIGINS = {"local", "foreign", "unknown"}
RULE_EFFECTS = {"restrict", "allow"}
DATE_PARITIES = {"odd", "even"}
DIGIT_POSITIONS = {"firstNumeric", "lastNumeric"}
RULE_SEMANTIC_FIELDS = (
    "priority",
    "effect",
    "validFrom",
    "validUntil",
    "registrationOrigins",
    "weekdays",
    "dateParity",
    "digitPosition",
    "digits",
    "timeWindows",
    "appliesOnHolidays",
    "sourceUrl",
    "verifiedAt",
)
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


def _canonical_sha256(value: object) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return _sha256_bytes(encoded)


def _recurrence_source_value(source_coverage: dict) -> dict:
    return {
        "sourceRef": copy.deepcopy(source_coverage.get("sourceRef")),
        "sourceUrls": copy.deepcopy(source_coverage.get("sourceUrls")),
        "digitPositionCandidate": source_coverage.get("digitPositionCandidate"),
        "weekdaySchedule": copy.deepcopy(source_coverage.get("weekdaySchedule")),
        "timeWindowsCandidate": copy.deepcopy(
            source_coverage.get("timeWindowsCandidate")
        ),
    }


def _is_utc_timestamp(value: object) -> bool:
    parsed = _iso_datetime(value)
    return (
        isinstance(value, str)
        and "T" in value
        and parsed is not None
        and parsed.tzinfo is not None
        and parsed.utcoffset() is not None
        and parsed.utcoffset().total_seconds() == 0
    )


def _is_official_source_url(value: object) -> bool:
    return _is_https_url(value) and urlparse(str(value)).hostname in OFFICIAL_SOURCE_HOSTS


def _is_exact_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _comparable_datetime(value: datetime) -> datetime:
    return value.replace(tzinfo=None)


def _runtime_rule_reasons(rule: object, runtime_source_urls: list[str]) -> list[str]:
    if not isinstance(rule, dict):
        return ["runtime_rule_invalid"]
    reasons = []
    rule_id = rule.get("id")
    if not isinstance(rule_id, str) or not rule_id.strip():
        reasons.append("runtime_rule_id_invalid")
    if not _is_exact_int(rule.get("priority")):
        reasons.append("runtime_rule_priority_invalid")
    effect = rule.get("effect")
    if not isinstance(effect, str) or effect not in RULE_EFFECTS:
        reasons.append("runtime_rule_effect_invalid")

    valid_from = _iso_datetime(rule.get("validFrom"))
    valid_until_value = rule.get("validUntil")
    valid_until = (
        None if valid_until_value is None else _iso_datetime(valid_until_value)
    )
    if valid_from is None or (
        valid_until_value is not None and valid_until is None
    ):
        reasons.append("runtime_rule_validity_invalid")
    elif valid_until is not None and _comparable_datetime(
        valid_from
    ) > _comparable_datetime(valid_until):
        reasons.append("runtime_rule_validity_invalid")

    registration_origins = rule.get("registrationOrigins")
    if registration_origins is not None and (
        not isinstance(registration_origins, list)
        or any(
            not isinstance(value, str) or value not in REGISTRATION_ORIGINS
            for value in registration_origins
        )
    ):
        reasons.append("runtime_rule_registration_origins_invalid")
    weekdays = rule.get("weekdays")
    if weekdays is not None and (
        not isinstance(weekdays, list)
        or any(not _is_exact_int(value) or value < 1 or value > 7 for value in weekdays)
    ):
        reasons.append("runtime_rule_weekdays_invalid")
    date_parity = rule.get("dateParity")
    if date_parity is not None and (
        not isinstance(date_parity, str) or date_parity not in DATE_PARITIES
    ):
        reasons.append("runtime_rule_date_parity_invalid")
    digit_position = rule.get("digitPosition")
    if digit_position is not None and (
        not isinstance(digit_position, str)
        or digit_position not in DIGIT_POSITIONS
    ):
        reasons.append("runtime_rule_digit_position_invalid")
    digits = rule.get("digits")
    if digits is not None and (
        not isinstance(digits, list)
        or any(not _is_exact_int(value) or value < 0 or value > 9 for value in digits)
    ):
        reasons.append("runtime_rule_digits_invalid")
    if digits is not None and digit_position is None:
        reasons.append("runtime_rule_digit_position_required")

    windows = rule.get("timeWindows")
    if not isinstance(windows, list):
        reasons.append("runtime_rule_windows_invalid")
    else:
        for window in windows:
            if (
                not isinstance(window, dict)
                or not _is_exact_int(window.get("startMinute"))
                or not _is_exact_int(window.get("endMinute"))
                or window["startMinute"] < 0
                or window["startMinute"] >= 1440
                or window["endMinute"] < 0
                or window["endMinute"] >= 1440
                or window["startMinute"] == window["endMinute"]
            ):
                reasons.append("runtime_rule_window_invalid")
    if not isinstance(rule.get("appliesOnHolidays"), bool):
        reasons.append("runtime_rule_holiday_policy_invalid")
    source_url = rule.get("sourceUrl")
    if not _is_https_url(source_url):
        reasons.append("runtime_rule_source_url_invalid")
    elif source_url not in runtime_source_urls:
        reasons.append("runtime_rule_source_mismatch")
    if _iso_datetime(rule.get("verifiedAt")) is None:
        reasons.append("runtime_rule_verified_at_invalid")
    return _unique_reasons(reasons)


def _runtime_coverage_reasons(runtime: object) -> list[str]:
    if not isinstance(runtime, dict):
        return ["runtime_coverage_missing"]
    reasons = []
    for field in ("jurisdictionId", "jurisdictionName"):
        value = runtime.get(field)
        if not isinstance(value, str) or not value.strip():
            reasons.append(f"runtime_coverage_missing_{field}")
    vehicle_kind = runtime.get("vehicleKind")
    if not isinstance(vehicle_kind, str) or vehicle_kind not in VEHICLE_KINDS:
        reasons.append("runtime_vehicle_kind_invalid")
    service_type = runtime.get("serviceType")
    if not isinstance(service_type, str) or service_type not in SERVICE_TYPES:
        reasons.append("runtime_service_type_invalid")
    if _iso_datetime(runtime.get("verifiedAt")) is None:
        reasons.append("runtime_verified_at_invalid")
    if _iso_datetime(runtime.get("staleAfter")) is None:
        reasons.append("runtime_stale_after_invalid")
    source_urls = runtime.get("sourceUrls")
    if not isinstance(source_urls, list) or not source_urls or any(
        not _is_https_url(value) for value in source_urls
    ):
        reasons.append("runtime_source_urls_invalid")
        source_urls = []
    rules = runtime.get("rules")
    if not isinstance(rules, list):
        reasons.append("runtime_rules_invalid")
        rules = []
    elif not rules:
        reasons.append("runtime_rules_missing")
    rule_ids = set()
    for rule in rules:
        reasons.extend(_runtime_rule_reasons(rule, source_urls))
        if isinstance(rule, dict) and isinstance(rule.get("id"), str):
            rule_id = rule["id"]
            if rule_id in rule_ids:
                reasons.append("runtime_rule_id_duplicate")
            rule_ids.add(rule_id)
    return _unique_reasons(reasons)


def _actual_snapshot_action(restriction_payload: dict, runtime: dict) -> str:
    jurisdiction = next(
        (
            row
            for row in restriction_payload["jurisdictions"]
            if row["id"] == runtime["jurisdictionId"]
        ),
        None,
    )
    if jurisdiction is None:
        return "add"
    existing = next(
        (
            row
            for row in jurisdiction["coverages"]
            if row["vehicleKind"] == runtime["vehicleKind"]
            and row["serviceType"] == runtime["serviceType"]
        ),
        None,
    )
    if existing is None:
        return "add"
    expected = {
        key: value
        for key, value in runtime.items()
        if key not in {"jurisdictionId", "jurisdictionName"}
    }
    if jurisdiction.get("name") == runtime["jurisdictionName"] and existing == expected:
        return "maintain"
    return "update"


def _runtime_dataset_reasons(payload: object) -> list[str]:
    if not isinstance(payload, dict):
        return ["runtime_dataset_invalid"]
    reasons = []
    if payload.get("schemaVersion") != 1:
        reasons.append("runtime_dataset_schema_invalid")
    if payload.get("datasetKey") != "restrictions":
        reasons.append("runtime_dataset_key_invalid")
    for field in ("version",):
        if not isinstance(payload.get(field), str) or not payload[field].strip():
            reasons.append(f"runtime_dataset_{field}_invalid")
    if _iso_datetime(payload.get("generatedAt")) is None:
        reasons.append("runtime_dataset_generated_at_invalid")
    jurisdictions = payload.get("jurisdictions")
    if not isinstance(jurisdictions, list):
        return _unique_reasons(reasons, "runtime_jurisdictions_invalid")
    coverage_ids = set()
    rule_ids = set()
    for jurisdiction in jurisdictions:
        if not isinstance(jurisdiction, dict):
            reasons.append("runtime_jurisdiction_invalid")
            continue
        jurisdiction_id = jurisdiction.get("id")
        jurisdiction_name = jurisdiction.get("name")
        if not isinstance(jurisdiction_id, str) or not jurisdiction_id.strip():
            reasons.append("runtime_jurisdiction_id_invalid")
            continue
        if not isinstance(jurisdiction_name, str) or not jurisdiction_name.strip():
            reasons.append("runtime_jurisdiction_name_invalid")
        coverages = jurisdiction.get("coverages")
        if not isinstance(coverages, list):
            reasons.append("runtime_coverages_invalid")
            continue
        for coverage in coverages:
            if not isinstance(coverage, dict):
                reasons.append("runtime_coverage_invalid")
                continue
            runtime = {
                "jurisdictionId": jurisdiction_id,
                "jurisdictionName": jurisdiction_name,
                **coverage,
            }
            coverage_reasons = _runtime_coverage_reasons(runtime)
            rules = coverage.get("rules")
            if (
                isinstance(rules, list)
                and not rules
                and _iso_datetime(coverage.get("verifiedAt")) is not None
                and _iso_datetime(coverage.get("staleAfter")) is not None
                and isinstance(coverage.get("sourceUrls"), list)
                and coverage["sourceUrls"]
            ):
                coverage_reasons = [
                    reason
                    for reason in coverage_reasons
                    if reason != "runtime_rules_missing"
                ]
            reasons.extend(coverage_reasons)
            coverage_id = (
                jurisdiction_id,
                coverage.get("vehicleKind"),
                coverage.get("serviceType"),
            )
            if coverage_id in coverage_ids:
                reasons.append("runtime_coverage_duplicate")
            coverage_ids.add(coverage_id)
            if not isinstance(rules, list):
                continue
            for rule in rules:
                if not isinstance(rule, dict):
                    continue
                rule_key = (jurisdiction_id, rule.get("id"))
                if rule_key in rule_ids:
                    reasons.append("runtime_rule_id_duplicate")
                rule_ids.add(rule_key)
    return _unique_reasons(reasons)


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
    if not _is_utc_timestamp(payload["reviewedAt"]):
        raise ValueError(
            "Reviewed decisions require reviewedAt as a UTC timestamp"
        )
    decisions = payload.get("decisions")
    if not isinstance(decisions, list):
        raise ValueError("Reviewed decisions must contain a decisions list")
    ids = [row.get("sourceCoverageId") for row in decisions if isinstance(row, dict)]
    if (
        len(ids) != len(decisions)
        or any(not isinstance(value, str) or not value for value in ids)
        or len(set(ids)) != len(ids)
    ):
        raise ValueError("Reviewed decisions require unique sourceCoverageId values")
    return payload


def _review_validation_reasons(
    decision: dict,
    source_coverage: dict,
    mapped: dict,
    dated_by_id: dict[str, dict],
    restriction_payload: dict,
) -> list[str]:
    reasons = []
    evidence_kind = decision.get("evidenceKind", "dated_schedule")
    if evidence_kind not in EVIDENCE_KINDS:
        reasons.append("review_evidence_kind_invalid")
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

    source_record_ids = decision.get("sourceRecordIds")
    if not isinstance(source_record_ids, list):
        reasons.append("review_source_record_ids_invalid")
        source_record_ids = []
    elif any(
        not isinstance(value, str) or not value for value in source_record_ids
    ):
        reasons.append("review_source_record_ids_invalid")
        source_record_ids = []
    elif len(set(source_record_ids)) != len(source_record_ids):
        reasons.append("review_source_record_ids_duplicate")
    source_records = []
    for source_record_id in source_record_ids:
        source_record = dated_by_id.get(source_record_id)
        if source_record is None:
            reasons.append("review_source_record_unknown")
            continue
        source_records.append(source_record)
        if _normalized(source_record.get("sourcePublicationFlagRaw")).startswith("no"):
            reasons.append("source_explicit_no_publish")
    source_jurisdiction_key = decision["sourceCoverageId"].rsplit(":", 1)[0]
    source_vehicle_type = source_coverage.get("sourceVehicleType")
    for source_record in source_records:
        if (
            source_record.get("sourceJurisdictionKey") != source_jurisdiction_key
            or source_record.get("vehicleTypeCandidate") != source_vehicle_type
        ):
            reasons.append("review_source_record_not_correlated")
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

    blockers = decision.get("blockers")
    if not isinstance(blockers, list) or blockers:
        reasons.append("review_blockers_present")
    if not _is_utc_timestamp(decision.get("consultedAt")):
        reasons.append("review_consulted_at_not_utc")
    if evidence_kind == "dated_schedule" and not source_record_ids:
        reasons.append("review_source_record_ids_required")
    if evidence_kind == "weekly_recurrence" and source_record_ids:
        reasons.append("review_source_record_ids_not_allowed_for_recurrence")
    official_source_url = decision.get("officialSourceUrl")
    if not _is_official_source_url(official_source_url):
        reasons.append("review_official_source_domain_not_allowed")
    linked_source_urls = {
        url
        for source in (source_coverage, *source_records)
        for url in source.get("sourceUrls", [])
        if isinstance(url, str)
    }
    if official_source_url not in linked_source_urls:
        reasons.append("review_official_source_not_in_source_records")

    runtime = decision.get("runtimeCoverage")
    if not isinstance(runtime, dict):
        return _unique_reasons(reasons, "runtime_coverage_missing")
    reasons.extend(_runtime_coverage_reasons(runtime))
    if runtime.get("jurisdictionId") != mapped.get("appJurisdictionId"):
        reasons.append("runtime_jurisdiction_mismatch")
    if runtime.get("vehicleKind") != source_coverage.get("appVehicleKindCandidate"):
        reasons.append("runtime_vehicle_kind_mismatch")
    if runtime.get("serviceType") != source_coverage.get("appServiceTypeCandidate"):
        reasons.append("runtime_service_type_mismatch")
    source_urls = runtime.get("sourceUrls")
    if isinstance(source_urls, list) and any(
        not _is_official_source_url(url) for url in source_urls
    ):
        reasons.append("runtime_source_url_domain_not_allowed")
    if isinstance(source_urls, list) and official_source_url not in source_urls:
        reasons.append("runtime_official_source_missing")
    stale_after = _iso_datetime(runtime.get("staleAfter"))
    if runtime.get("verifiedAt") != decision.get("consultedAt"):
        reasons.append("runtime_verified_at_not_consulted_at")

    legal = decision.get("legalValidity")
    if not isinstance(legal, dict):
        reasons.append("legal_validity_invalid")
        legal = {}
    if legal.get("status") != "complete":
        reasons.append("legal_validity_status_not_complete")
    for field in ("validFrom", "validUntil", "sourceTimestamp"):
        if _iso_datetime(legal.get(field)) is None:
            reasons.append(f"legal_validity_missing_{field}")
    if legal.get("sourceTimestamp") is not None and not _is_utc_timestamp(
        legal.get("sourceTimestamp")
    ):
        reasons.append("legal_validity_source_timestamp_not_utc")
    legal_from = _iso_datetime(legal.get("validFrom"))
    legal_until = _iso_datetime(legal.get("validUntil"))
    if legal_from and legal_until and _comparable_datetime(
        legal_from
    ) > _comparable_datetime(legal_until):
        reasons.append("legal_validity_range_invalid")

    original_value = decision.get("originalValue")
    if not isinstance(original_value, dict):
        reasons.append("review_original_value_invalid")
        original_value = {}
    if original_value.get("sourceCoverageSha256") != _canonical_sha256(
        source_coverage
    ):
        reasons.append("review_source_coverage_hash_mismatch")
    if original_value.get("sourceRecordsSha256") != _canonical_sha256(source_records):
        reasons.append("review_source_records_hash_mismatch")
    if evidence_kind == "weekly_recurrence" and original_value.get(
        "sourceRecurrenceSha256"
    ) != _canonical_sha256(_recurrence_source_value(source_coverage)):
        reasons.append("review_source_recurrence_hash_mismatch")
    interpreted_value = decision.get("interpretedValue")
    if not isinstance(interpreted_value, dict):
        reasons.append("review_interpreted_value_invalid")
        interpreted_value = {}
    if interpreted_value.get("runtimeCoverageSha256") != _canonical_sha256(runtime):
        reasons.append("review_runtime_coverage_hash_mismatch")

    rules = runtime.get("rules")
    if not isinstance(rules, list):
        rules = []
    evidence_rows = interpreted_value.get("ruleEvidence")
    if not isinstance(evidence_rows, list):
        reasons.append("review_rule_evidence_invalid")
        evidence_rows = []
    evidence_by_rule = {
        row.get("ruleId"): row for row in evidence_rows if isinstance(row, dict)
    }
    for rule in rules:
        if not isinstance(rule, dict):
            continue
        rule_from = _iso_datetime(rule.get("validFrom"))
        rule_until = _iso_datetime(rule.get("validUntil"))
        if rule_from and rule_until and legal_from and legal_until and (
            _comparable_datetime(rule_from) < _comparable_datetime(legal_from)
            or _comparable_datetime(rule_until) > _comparable_datetime(legal_until)
        ):
            reasons.append("runtime_rule_outside_legal_validity")
        if rule.get("verifiedAt") != runtime.get("verifiedAt"):
            reasons.append("runtime_rule_verified_at_mismatch")
        evidence = evidence_by_rule.get(rule.get("id"))
        if not isinstance(evidence, dict):
            reasons.append("review_rule_evidence_missing")
            continue
        reviewed_semantics = evidence.get("reviewedSemantics")
        runtime_semantics = {
            field: copy.deepcopy(rule.get(field)) for field in RULE_SEMANTIC_FIELDS
        }
        if not isinstance(reviewed_semantics, dict):
            reasons.append("review_rule_semantics_missing")
        elif reviewed_semantics != runtime_semantics:
            reasons.append("review_rule_semantics_mismatch")
        if evidence_kind == "weekly_recurrence":
            source_weekdays = evidence.get("sourceWeekdays")
            if (
                not isinstance(source_weekdays, list)
                or not source_weekdays
                or any(
                    not _is_exact_int(value) or value < 1 or value > 7
                    for value in source_weekdays
                )
                or len(set(source_weekdays)) != len(source_weekdays)
            ):
                reasons.append("review_rule_source_weekdays_invalid")
                continue
            schedule_by_weekday = {
                row.get("isoWeekday"): row
                for row in source_coverage.get("weekdaySchedule", [])
                if isinstance(row, dict)
            }
            source_schedule = [
                schedule_by_weekday.get(weekday) for weekday in source_weekdays
            ]
            if any(row is None for row in source_schedule):
                reasons.append("review_rule_source_weekday_unknown")
                continue
            expected_windows = [
                {
                    "startMinute": window.get("startMinute"),
                    "endMinute": window.get("endMinute"),
                }
                for window in source_coverage.get("timeWindowsCandidate", [])
            ]
            structured_digits = [
                row.get("digitsRestrictedCandidate") for row in source_schedule
            ]
            digits_match = all(
                digits is not None and digits == rule.get("digits")
                for digits in structured_digits
            )
            parity_source = all(
                "fecha par impar" in _normalized(row.get("raw"))
                for row in source_schedule
            )
            if (
                "regla semanal"
                not in _normalized(source_coverage.get("dynamicCalendarRaw"))
                or rule.get("weekdays") != source_weekdays
                or (not digits_match and not (parity_source and rule.get("dateParity")))
                or rule.get("digitPosition")
                != source_coverage.get("digitPositionCandidate")
                or rule.get("timeWindows") != expected_windows
                or rule.get("sourceUrl")
                not in source_coverage.get("sourceUrls", [])
            ):
                reasons.append("review_rule_evidence_mismatch")
        else:
            source_record_id = evidence.get("sourceRecordId")
            source_record = dated_by_id.get(source_record_id)
            if source_record_id not in source_record_ids or source_record is None:
                reasons.append("review_rule_evidence_missing")
                continue
            expected_windows = [
                {
                    "startMinute": window.get("startMinute"),
                    "endMinute": window.get("endMinute"),
                }
                for window in source_record.get("timeWindowsCandidate", [])
            ]
            expected_date = source_record.get("date")
            if (
                rule_from is None
                or rule_until is None
                or rule_from.date().isoformat() != expected_date
                or rule_until.date().isoformat() != expected_date
                or rule.get("weekdays") != [source_record.get("isoWeekday")]
                or rule.get("digits")
                != source_record.get("digitsRestrictedCandidate")
                or rule.get("digitPosition")
                != source_record.get("digitPositionCandidate")
                or rule.get("timeWindows") != expected_windows
                or rule.get("sourceUrl") not in source_record.get("sourceUrls", [])
            ):
                reasons.append("review_rule_evidence_mismatch")
    if stale_after and legal_until:
        if _comparable_datetime(stale_after) <= _comparable_datetime(legal_until):
            reasons.append("runtime_stale_after_not_after_validity")
    if isinstance(runtime, dict) and all(
        key in runtime
        for key in (
            "jurisdictionId",
            "jurisdictionName",
            "vehicleKind",
            "serviceType",
        )
    ):
        actual_action = _actual_snapshot_action(restriction_payload, runtime)
        if decision.get("snapshotAction") != actual_action:
            reasons.append(f"snapshot_action_mismatch_expected_{actual_action}")
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
    restriction_payload: dict,
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
            restriction_payload,
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
        action = _actual_snapshot_action(result, runtime)
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
        else:
            jurisdiction["name"] = jurisdiction_name
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
    return _compile_inputs(
        pico, tolls, source_counts, repo_root, reviewed_decisions_path,
        verified_staging_hashes=APPROVED_SOURCE_HASHES,
    )


def _compile_inputs(
    pico: dict,
    tolls: dict,
    source_counts: dict,
    repo_root: Path,
    reviewed_decisions_path: Path | None,
    *,
    verified_staging_hashes: dict,
) -> dict:
    # Transformation shared with synthetic tests; the public entry verifies bytes first.
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
        pico,
        repo_root,
        restriction_hash,
        reviewed_decisions,
        restriction_payload,
    )
    base_restriction_payload = restriction_payload
    restriction_payload, snapshot_diff = _apply_reviewed_coverages(
        restriction_payload, approved, reviewed_decisions
    )
    dataset_reasons = _runtime_dataset_reasons(restriction_payload)
    if approved and dataset_reasons:
        for ledger_row in restriction_ledger["coverageDecisions"]:
            if not ledger_row.get("publishable"):
                continue
            ledger_row["reviewDecision"] = "needs_evidence"
            ledger_row["decision"] = "quarantined"
            ledger_row["publishable"] = False
            ledger_row["runtimePublished"] = False
            ledger_row["quarantineReasons"] = dataset_reasons
        approved = []
        restriction_payload = base_restriction_payload
        snapshot_diff = {"added": 0, "updated": 0, "maintained": 0, "removed": 0}
        restriction_ledger["existingBundledRestrictionsPreserved"] = True
        restriction_ledger["newRuntimeRulesPublished"] = 0
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
        "stagingHashesVerified": verified_staging_hashes,
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
    if not verified_staging_hashes:
        report["inputKind"] = "NON_PRODUCTION_FIXTURE"
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
