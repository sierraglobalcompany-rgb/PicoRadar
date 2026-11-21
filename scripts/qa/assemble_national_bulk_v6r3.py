#!/usr/bin/env python3
"""Assemble an explicit schema2 LAB release from its versioned source manifest."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path, PurePosixPath, PureWindowsPath
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / "server/database/data/restrictions/lab"
DEFAULT_MANIFEST = LAB / "national_sources_manifest_v1.json"
TZ_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$")
SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")
BOGOTA = timezone(timedelta(hours=-5))


def fail(message: str) -> None:
    raise ValueError(message)


def object_with_keys(value: object, keys: set[str], label: str) -> dict:
    if not isinstance(value, dict):
        fail(f"{label} must be a JSON object")
    extra = set(value) - keys
    missing = keys - set(value)
    if extra or missing:
        fail(f"{label} keys mismatch: missing={sorted(missing)} extra={sorted(extra)}")
    return value


def parse_timestamp(value: object, label: str) -> datetime:
    if not isinstance(value, str) or not TZ_DATE.fullmatch(value):
        fail(f"{label} must be ISO-8601 with an explicit timezone")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        fail(f"{label} is not a valid timestamp: {exc}")
    if parsed.tzinfo is None:
        fail(f"{label} must include a timezone")
    return parsed


def lab_path(lab: Path, relative: object, label: str) -> Path:
    if not isinstance(relative, str) or not relative:
        fail(f"{label} must be a nonempty relative path inside LAB")
    normalized = relative.replace("\\", "/")
    parts = normalized.split("/")
    posix = PurePosixPath(normalized)
    windows = PureWindowsPath(relative)
    if (
        posix.is_absolute()
        or windows.is_absolute()
        or windows.drive
        or any(part in {"", ".", ".."} for part in parts)
    ):
        fail(f"{label} path must be canonical and cannot traverse outside LAB: {relative}")
    root = lab.resolve()
    candidate = (root.joinpath(*posix.parts)).resolve()
    try:
        candidate.relative_to(root)
    except ValueError:
        fail(f"{label} path escapes LAB: {relative}")
    return candidate


def json_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        fail(f"Expected JSON object: {path.name}")
    return value


def validate_expires_at(payload: dict) -> None:
    if "expiresAt" in payload:
        parse_timestamp(payload["expiresAt"], "expiresAt")


def validate_jurisdiction(
    j: dict,
    seen_codes: dict[str, str],
    seen_rules: set[str],
    seen_rule_signatures: set[tuple[str, str, str, str]] | None = None,
) -> tuple[int, int]:
    if seen_rule_signatures is None:
        seen_rule_signatures = set()
    allowed_j = {"schemaVersion", "id", "name", "coverages", "municipalityCodes", "consultationEnabled"}
    if not isinstance(j, dict) or set(j) - allowed_j:
        fail(f"Unsupported jurisdiction key: {j.get('id') if isinstance(j, dict) else None} / {sorted(set(j)-allowed_j) if isinstance(j, dict) else ''}")
    if j.get("schemaVersion") != 2 or not isinstance(j.get("id"), str) or not j["id"]:
        fail("Every source must be a schema2 jurisdiction with an id")
    if not isinstance(j.get("name"), str) or not j["name"]:
        fail(f"Missing name: {j['id']}")
    if not isinstance(j.get("consultationEnabled"), bool):
        fail(f"consultationEnabled must be boolean: {j['id']}")
    codes = j.get("municipalityCodes")
    if not isinstance(codes, list) or not codes or codes != sorted(set(codes)):
        fail(f"municipalityCodes must be a sorted, nonempty unique list: {j['id']}")
    for code in codes:
        if not isinstance(code, str) or not re.fullmatch(r"\d{5}", code):
            fail(f"Invalid DIVIPOLA code: {j['id']} / {code!r}")
        if j["consultationEnabled"]:
            if code in seen_codes:
                fail(f"Enabled DIVIPOLA collision {code}: {seen_codes[code]} / {j['id']}")
            seen_codes[code] = j["id"]
    coverages = j.get("coverages")
    if not isinstance(coverages, list) or not coverages:
        fail(f"Jurisdiction has no coverages: {j['id']}")
    pair_keys: set[tuple[str, str]] = set()
    rule_count = 0
    allowed_c = {"vehicleKind", "serviceType", "coverageCompleteness", "verifiedAt", "staleAfter", "sourceUrls", "rules"}
    allowed_r = {"id", "priority", "effect", "validFrom", "validUntil", "weekdays", "dateParity", "digitPosition", "digits", "registrationOrigins", "timeWindows", "appliesOnHolidays", "sourceUrl", "verifiedAt", "conditions"}
    for cov in coverages:
        if not isinstance(cov, dict) or set(cov) - allowed_c:
            fail(f"Unsupported coverage shape: {j['id']}")
        pair = (cov.get("vehicleKind"), cov.get("serviceType"))
        if pair in pair_keys:
            fail(f"Duplicate vehicle/service coverage: {j['id']} / {pair}")
        pair_keys.add(pair)
        if cov.get("coverageCompleteness") != "partial":
            fail(f"LAB scope must remain partial: {j['id']} / {pair}")
        coverage_verified = parse_timestamp(cov.get("verifiedAt"), f"verifiedAt {j['id']} {pair}")
        coverage_stale = parse_timestamp(cov.get("staleAfter"), f"staleAfter {j['id']} {pair}")
        if coverage_stale <= coverage_verified:
            fail(f"staleAfter must be later than verifiedAt: {j['id']} / {pair}")
        sources = cov.get("sourceUrls")
        if not isinstance(sources, list) or not sources or len(sources) != len(set(sources)):
            fail(f"Coverage needs unique official source URLs: {j['id']} / {pair}")
        for source in sources:
            parsed = urlparse(source) if isinstance(source, str) else None
            if parsed is None or parsed.scheme != "https" or not parsed.netloc:
                fail(f"Invalid HTTPS source: {j['id']} / {pair}")
        rules = cov.get("rules")
        if not isinstance(rules, list) or not rules:
            fail(f"Coverage needs at least one source-backed rule: {j['id']} / {pair}")
        for rule in rules:
            if not isinstance(rule, dict) or set(rule) - allowed_r:
                fail(f"Unsupported rule key: {j['id']} / {pair}")
            rule_id = rule.get("id")
            if not isinstance(rule_id, str) or not rule_id or rule_id in seen_rules:
                fail(f"Missing or duplicate global rule id: {rule_id!r}")
            seen_rules.add(rule_id)
            valid_from = parse_timestamp(rule.get("validFrom"), f"validFrom {rule_id}")
            rule_verified = parse_timestamp(rule.get("verifiedAt"), f"verifiedAt {rule_id}")
            if rule_verified > coverage_verified:
                fail(f"Rule verification is later than its coverage verification: {rule_id}")
            if rule.get("validUntil") is not None:
                valid_until = parse_timestamp(rule["validUntil"], f"validUntil {rule_id}")
                if valid_until < valid_from:
                    fail(f"validUntil precedes validFrom: {rule_id}")
            if rule.get("sourceUrl") not in sources:
                fail(f"Rule source must appear in coverage sourceUrls: {rule_id}")
            if rule.get("effect") not in {"restrict", "allow"} or not isinstance(rule.get("appliesOnHolidays"), bool):
                fail(f"Invalid effect/holiday flag: {rule_id}")
            conditions = rule.get("conditions")
            if not isinstance(conditions, list) or not any(
                isinstance(x, dict) and x.get("type") == "inside_scope_ref"
                and isinstance(x.get("value"), str) and re.fullmatch(r"[^@]+@[^@]+", x["value"])
                for x in conditions
            ):
                fail(f"Partial coverage rule lacks unresolved spatial scope: {rule_id}")
            windows = rule.get("timeWindows")
            if not isinstance(windows, list) or not windows:
                fail(f"Rule needs a time window: {rule_id}")
            for window in windows:
                if not isinstance(window, dict) or frozenset(window) not in {
                    frozenset({"startMinute", "endMinute"}),
                    frozenset({"startMinute", "endMinute", "fullDay"}),
                }:
                    fail(f"Invalid time window object: {rule_id}")
                start, end = window["startMinute"], window["endMinute"]
                has_full_day = "fullDay" in window
                valid_minutes = (
                    type(start) is int
                    and type(end) is int
                    and 0 <= start < 1440
                    and 0 <= end < 1440
                )
                valid_full_day = start != end or (
                    has_full_day and window["fullDay"] is True
                )
                marker_matches_window = start == end or not has_full_day
                if not valid_minutes or not valid_full_day or not marker_matches_window:
                    fail(f"Invalid or unsupported 24-hour time window: {rule_id}")
            signature = json.dumps(
                {key: value for key, value in rule.items() if key != "id"},
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            signature_key = (j["id"], pair[0], pair[1], signature)
            if signature_key in seen_rule_signatures:
                fail(f"Duplicate semantic rule: {j['id']} / {pair} / {rule_id}")
            seen_rule_signatures.add(signature_key)
            rule_count += 1
    return len(coverages), rule_count


def read_source_jurisdiction(raw: bytes, name: str) -> dict:
    parsed = json.loads(raw.decode("utf-8"))
    if not isinstance(parsed, dict):
        fail(f"Source must be a JSON object: {name}")
    validate_expires_at(parsed)
    if "generatedAt" in parsed:
        parse_timestamp(parsed["generatedAt"], f"generatedAt {name}")
    if "jurisdictions" in parsed:
        if parsed.get("schemaVersion") != 2 or parsed.get("datasetKey") != "restrictions":
            fail(f"Invalid preserved schema2 source envelope: {name}")
        rows = parsed.get("jurisdictions")
        if not isinstance(rows, list) or len(rows) != 1 or not isinstance(rows[0], dict):
            fail(f"Expected exactly one jurisdiction in source envelope: {name}")
        return rows[0]
    return parsed


def build(manifest_path: Path = DEFAULT_MANIFEST) -> tuple[bytes, dict]:
    manifest_path = Path(manifest_path).resolve()
    lab = manifest_path.parent
    raw_manifest = manifest_path.read_bytes()
    manifest = json.loads(raw_manifest.decode("utf-8"))
    object_with_keys(manifest, {"schemaVersion", "release", "sources"}, "manifest")
    if manifest["schemaVersion"] != 1:
        fail("Unsupported source manifest schemaVersion")
    release = object_with_keys(manifest["release"], {"version", "generatedAt", "outputFile", "shaFile"}, "release")
    version = release["version"]
    if not isinstance(version, str) or not re.fullmatch(r"[A-Z0-9][A-Z0-9-]{0,127}", version):
        fail("release.version must be a stable LAB identifier")
    generated_at = parse_timestamp(release["generatedAt"], "release.generatedAt")
    output_path = lab_path(lab, release["outputFile"], "release.outputFile")
    hash_path = lab_path(lab, release["shaFile"], "release.shaFile")
    if output_path == hash_path or output_path == manifest_path or hash_path == manifest_path:
        fail("Manifest, snapshot, and SHA sidecar paths must be distinct")
    entries = manifest["sources"]
    if not isinstance(entries, list) or not entries:
        fail("manifest.sources must be a nonempty explicit allowlist")
    source_ids: list[str] = []
    source_files: set[str] = set()
    for entry in entries:
        object_with_keys(
            entry,
            {"jurisdictionId", "file", "enabled", "expectedSha256", "provenance", "editorialDate"},
            "source entry",
        )
        source_id = entry["jurisdictionId"]
        if not isinstance(source_id, str) or not source_id:
            fail("source jurisdictionId must be a nonempty string")
        source_ids.append(source_id)
        if not isinstance(entry["enabled"], bool):
            fail(f"source enabled must be boolean: {source_id}")
        if not isinstance(entry["expectedSha256"], str) or not SHA256.fullmatch(entry["expectedSha256"]):
            fail(f"source expectedSha256 must be 64 hexadecimal characters: {source_id}")
        if not isinstance(entry["provenance"], str) or not entry["provenance"].strip():
            fail(f"source provenance is required: {source_id}")
        try:
            editorial_date = date.fromisoformat(entry["editorialDate"])
        except (TypeError, ValueError):
            fail(f"source editorialDate must be YYYY-MM-DD: {source_id}")
        if editorial_date.isoformat() != entry["editorialDate"]:
            fail(f"source editorialDate must be canonical YYYY-MM-DD: {source_id}")
        if entry["file"] in source_files:
            fail(f"Duplicate source file: {entry['file']}")
        source_files.add(entry["file"])
    if len(source_ids) != len(set(source_ids)):
        fail("Duplicate source jurisdictionId in manifest")
    if source_ids != sorted(source_ids):
        fail("manifest.sources must be ordered by jurisdictionId")
    if str(output_path) in {str(lab_path(lab, entry["file"], "source.file")) for entry in entries}:
        fail("Snapshot output cannot overwrite a declared source")
    if str(hash_path) in {str(lab_path(lab, entry["file"], "source.file")) for entry in entries}:
        fail("SHA sidecar cannot overwrite a declared source")

    jurisdictions: list[dict] = []
    seen_codes: dict[str, str] = {}
    seen_rules: set[str] = set()
    seen_rule_signatures: set[tuple[str, str, str, str]] = set()
    coverage_count = rule_count = enabled_count = disabled_count = 0
    max_verified_at: datetime | None = None
    warnings: list[str] = []
    input_hashes: dict[str, str] = {}
    for entry in entries:
        source_id = entry["jurisdictionId"]
        path = lab_path(lab, entry["file"], "source.file")
        if not path.is_file():
            fail(f"Declared source file does not exist: {entry['file']}")
        raw = path.read_bytes()
        actual_hash = hashlib.sha256(raw).hexdigest()
        input_hashes[entry["file"]] = actual_hash
        if actual_hash.lower() != entry["expectedSha256"].lower():
            fail(f"Source SHA-256 mismatch: {entry['file']}")
        jurisdiction = read_source_jurisdiction(raw, entry["file"])
        if jurisdiction.get("id") != source_id:
            fail(f"Manifest jurisdictionId does not match source JSON: {source_id} / {entry['file']}")
        if entry["enabled"]:
            if jurisdiction.get("consultationEnabled") is not True:
                fail(f"Enabled source must have consultationEnabled=true: {source_id}")
            seen_codes_for_source = seen_codes
            seen_rules_for_source = seen_rules
            seen_signatures_for_source = seen_rule_signatures
        else:
            # Disabled means omitted from this release, never that the jurisdiction has no rules.
            seen_codes_for_source, seen_rules_for_source, seen_signatures_for_source = {}, set(), set()
            disabled_count += 1
        source_coverages, source_rules = validate_jurisdiction(
            jurisdiction,
            seen_codes_for_source,
            seen_rules_for_source,
            seen_signatures_for_source,
        )
        if entry["enabled"]:
            enabled_count += 1
            jurisdictions.append(jurisdiction)
            coverage_count += source_coverages
            rule_count += source_rules
        latest_verified = max(parse_timestamp(c["verifiedAt"], f"verifiedAt {source_id}") for c in jurisdiction["coverages"])
        expected_editorial_date = latest_verified.astimezone(BOGOTA).date().isoformat()
        if entry["editorialDate"] != expected_editorial_date:
            fail(f"editorialDate does not match latest verifiedAt in America/Bogota: {source_id}")
        for coverage in jurisdiction["coverages"]:
            verified = parse_timestamp(coverage["verifiedAt"], f"verifiedAt {source_id}")
            stale = parse_timestamp(coverage["staleAfter"], f"staleAfter {source_id}")
            if entry["enabled"]:
                max_verified_at = verified if max_verified_at is None else max(max_verified_at, verified)
            if stale <= generated_at:
                warnings.append(f"stale coverage at generatedAt: {source_id} {coverage['vehicleKind']}/{coverage['serviceType']} staleAfter={coverage['staleAfter']}")
            for rule in coverage["rules"]:
                until_text = rule.get("validUntil")
                if until_text is not None and parse_timestamp(until_text, f"validUntil {rule['id']}") < generated_at:
                    warnings.append(f"expired rule retained for explicit stale/unknown handling: {rule['id']} validUntil={until_text}")
    if max_verified_at is not None and generated_at < max_verified_at:
        fail("release.generatedAt is earlier than the latest enabled source verifiedAt")

    jurisdictions.sort(key=lambda row: row["id"])
    for jurisdiction in jurisdictions:
        jurisdiction["coverages"].sort(key=lambda row: (row["vehicleKind"], row["serviceType"]))
    payload = {
        "schemaVersion": 2,
        "datasetKey": "restrictions",
        "version": version,
        "generatedAt": release["generatedAt"],
        "jurisdictions": jurisdictions,
    }
    encoded = (json.dumps(payload, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")
    return encoded, {
        "jurisdictions": len(jurisdictions),
        "enabledMunicipalityCodes": len(seen_codes),
        "coverages": coverage_count,
        "rules": rule_count,
        "enabledSources": enabled_count,
        "disabledSources": disabled_count,
        "manifestSha256": hashlib.sha256(raw_manifest).hexdigest(),
        "inputHashes": input_hashes,
        "warnings": sorted(set(warnings)),
        "version": version,
        "generatedAt": release["generatedAt"],
        "outputFile": release["outputFile"],
        "shaFile": release["shaFile"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST, help="explicit LAB source manifest")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--check", action="store_true", help="verify deterministic snapshot and SHA sidecar")
    group.add_argument("--write", action="store_true", help="write the LAB-only QA snapshot and SHA sidecar")
    args = parser.parse_args()
    try:
        manifest_path = args.manifest.resolve()
        encoded, details = build(manifest_path)
        lab = manifest_path.parent
        output_path = lab_path(lab, details["outputFile"], "release.outputFile")
        hash_path = lab_path(lab, details["shaFile"], "release.shaFile")
        digest = hashlib.sha256(encoded).hexdigest()
        if args.check:
            if not output_path.is_file() or output_path.read_bytes() != encoded:
                fail("Snapshot is absent or differs from deterministic manifest assembly")
            expected_sidecar = f"{digest}  {output_path.name}\n"
            if not hash_path.is_file() or hash_path.read_text(encoding="utf-8") != expected_sidecar:
                fail("Snapshot SHA sidecar is absent or incorrect")
        else:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            hash_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(encoded)
            hash_path.write_text(f"{digest}  {output_path.name}\n", encoding="utf-8", newline="\n")
        print(
            f"PASS {details['version']} generatedAt={details['generatedAt']} "
            f"jurisdictions={details['jurisdictions']} codes={details['enabledMunicipalityCodes']} "
            f"coverages={details['coverages']} rules={details['rules']} "
            f"manifest_sha256={details['manifestSha256']} output_sha256={digest} "
            f"output={details['outputFile']} mode={'check' if args.check else 'write'}"
        )
        for name, source_hash in sorted(details["inputHashes"].items()):
            print(f"INPUT_SHA256 {name} {source_hash}")
        for warning in details["warnings"]:
            print(f"WARN {warning}")
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
