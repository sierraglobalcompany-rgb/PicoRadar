#!/usr/bin/env python3
"""Build a reference-only DANE MGN 2025 sidecar without downloading polygons."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

PRIMARY = (
    "https://geoportal.dane.gov.co/mparcgis/rest/services/Divipola/"
    "Serv_DIVIPOLA_MGN_2025/FeatureServer"
)
MIRROR = (
    "https://portalgis.dane.gov.co/mparcgis/rest/services/Divipola/"
    "Serv_DIVIPOLA_MGN_2025/FeatureServer"
)
LAYERS = {305: "Centros Poblados", 317: "Municipio", 319: "Departamento"}
CHUNK_SIZE = 1000
RETRIES = 2


def fetch_json(url: str, snapshots: list[dict[str, str]]) -> dict[str, Any]:
    last_error: Exception | None = None
    for attempt in range(RETRIES):
        try:
            request = Request(url, headers={"User-Agent": "PicoRadar-G34-Geography/1.0"})
            with urlopen(request, timeout=30) as response:
                raw = response.read()
            payload = json.loads(raw)
            if "error" in payload:
                raise RuntimeError(f"ArcGIS error: {payload['error']}")
            snapshots.append({"url": url, "sha256": hashlib.sha256(raw).hexdigest()})
            return payload
        except (HTTPError, URLError, TimeoutError, json.JSONDecodeError, RuntimeError) as error:
            last_error = error
            if attempt + 1 < RETRIES:
                time.sleep(0.5 * (attempt + 1))
    raise RuntimeError(f"DANE request failed after {RETRIES} attempts: {url}: {last_error}")


def request_json(
    root: str, path: str, params: dict[str, Any], snapshots: list[dict[str, str]]
) -> dict[str, Any]:
    return fetch_json(f"{root}/{path}?{urlencode(params)}", snapshots)


def load_layer(
    root: str, layer_id: int, snapshots: list[dict[str, str]]
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    metadata = request_json(root, str(layer_id), {"f": "pjson"}, snapshots)
    if metadata.get("name") != LAYERS[layer_id] or metadata.get("maxRecordCount", 0) < 1:
        raise RuntimeError(f"Unexpected DIVIPOLA layer metadata for {layer_id}.")
    advanced = metadata.get("advancedQueryCapabilities", {})
    if advanced.get("supportsPagination") is not False:
        raise RuntimeError(f"Layer {layer_id} pagination contract changed; re-audit importer.")
    if metadata.get("geometryType") != "esriGeometryPolygon":
        raise RuntimeError(f"Layer {layer_id} geometry contract changed; re-audit importer.")

    count = request_json(
        root, f"{layer_id}/query", {"where": "1=1", "returnCountOnly": "true", "f": "json"}, snapshots
    ).get("count")
    ids_payload = request_json(
        root, f"{layer_id}/query", {"where": "1=1", "returnIdsOnly": "true", "f": "json"}, snapshots
    )
    ids = ids_payload.get("objectIds")
    if not isinstance(count, int) or not isinstance(ids, list) or len(ids) != count:
        raise RuntimeError(f"Layer {layer_id} count and object ID list disagree.")
    if len(set(ids)) != len(ids):
        raise RuntimeError(f"Layer {layer_id} returned duplicate object IDs.")

    fields = [field["name"] for field in metadata.get("fields", [])]
    if layer_id == 305:
        required = {"OBJECTID", "MPIO_CDPMP", "CLAS_CCDGO", "ZU_CDIVI", "ZU_CCNCT", "ZU_CNMBRE", "ZU_NANO"}
    elif layer_id == 317:
        required = {"OBJECTID", "MPIO_CDPMP", "DPTO_CCDGO", "MPIO_CNMBRE", "MPIO_NANO", "MPIO_TIPO"}
    else:
        required = {"OBJECTID", "DPTO_CCDGO", "DPTO_CNMBRE", "DPTO_NANO"}
    if not required.issubset(fields):
        raise RuntimeError(f"Layer {layer_id} is missing required DIVIPOLA fields.")

    out_fields = ",".join(sorted(required))
    rows: list[dict[str, Any]] = []
    ordered_ids = sorted(ids)
    for start in range(0, len(ordered_ids), CHUNK_SIZE):
        group = ordered_ids[start : start + CHUNK_SIZE]
        params: dict[str, Any] = {
            "objectIds": ",".join(map(str, group)),
            "outFields": out_fields,
            "returnGeometry": "false",
            "f": "json",
        }
        if layer_id == 305:
            params.update({"returnCentroid": "true", "outSR": "4326"})
        batch = request_json(root, f"{layer_id}/query", params, snapshots).get("features")
        if not isinstance(batch, list) or len(batch) != len(group):
            raise RuntimeError(f"Layer {layer_id} returned a truncated OBJECTID group.")
        got = [item.get("attributes", {}).get("OBJECTID") for item in batch]
        if sorted(got) != group:
            raise RuntimeError(f"Layer {layer_id} OBJECTID group did not round-trip exactly.")
        rows.extend(batch)
    if len(rows) != count:
        raise RuntimeError(f"Layer {layer_id} final row count does not match DANE count.")
    return metadata, rows


def valid_point(centroid: Any) -> tuple[float | None, float | None, str]:
    if not isinstance(centroid, dict):
        return None, None, "unknown"
    lon, lat = centroid.get("x"), centroid.get("y")
    if not isinstance(lon, (int, float)) or not isinstance(lat, (int, float)):
        return None, None, "unknown"
    if lon == 0 and lat == 0 or not (-180 <= lon <= 180 and -90 <= lat <= 90):
        return None, None, "unknown"
    return float(lat), float(lon), "derived_centroid_reference_only"


def build_sidecar(
    center_rows: list[dict[str, Any]], verified_at: str, root: str = MIRROR
) -> dict[str, Any]:
    features = []
    for row in center_rows:
        attrs = row.get("attributes", {})
        class_code = str(attrs.get("CLAS_CCDGO", ""))
        if class_code not in {"1", "2"}:
            raise RuntimeError(f"Unexpected CLAS_CCDGO in DANE 305: {class_code!r}.")
        parent = attrs.get("MPIO_CDPMP")
        center_code = attrs.get("ZU_CCNCT")
        if not isinstance(parent, str) or len(parent) != 5 or not parent.isdigit():
            raise RuntimeError("DANE 305 returned an invalid parent DIVIPOLA code.")
        if not isinstance(center_code, str) or not center_code.isdigit():
            raise RuntimeError("DANE 305 returned an invalid ZU_CCNCT key.")
        latitude, longitude, point_role = valid_point(row.get("centroid"))
        features.append(
            {
                "geoId": f"dane-mgn-2025:305:{center_code}",
                "level": "municipal_seat" if class_code == "1" else "populated_center",
                "parentDivipolaCode": parent,
                "divipolaCode": attrs.get("ZU_CDIVI") or None,
                "officialName": attrs.get("ZU_CNMBRE"),
                "latitude": latitude,
                "longitude": longitude,
                "pointRole": point_role,
                "sourceService": root,
                "layerId": 305,
                "sourceVersion": "2025",
                "verifiedAt": verified_at,
            }
        )
    features.sort(key=lambda feature: feature["geoId"])
    keys = [feature["geoId"] for feature in features]
    if len(keys) != len(set(keys)):
        raise RuntimeError("DANE 305 returned duplicate ZU_CCNCT identities.")
    return {"schemaVersion": 1, "features": features}


def reconcile(baseline: dict[str, Any], municipalities: list[dict[str, Any]], departments: list[dict[str, Any]]) -> dict[str, Any]:
    local_mpios = {row["code"]: row for row in baseline["municipalities"]}
    local_depts = {row["code"]: row for row in baseline["departments"]}
    remote_mpios = {row["attributes"]["MPIO_CDPMP"]: row["attributes"] for row in municipalities}
    remote_depts = {row["attributes"]["DPTO_CCDGO"]: row["attributes"] for row in departments}
    added = sorted(set(remote_mpios) - set(local_mpios))
    missing = sorted(set(local_mpios) - set(remote_mpios))
    parent_mismatches = sorted(
        code for code, local in local_mpios.items()
        if code in remote_mpios and local["departmentCode"] != remote_mpios[code]["DPTO_CCDGO"]
    )
    type_mismatches = [
        {
            "code": code,
            "localType": str(local["officialType"]).upper(),
            "daneType": str(remote_mpios[code].get("MPIO_TIPO") or "UNKNOWN").upper(),
        }
        for code, local in sorted(local_mpios.items())
        if code in remote_mpios
        and str(local["officialType"]).upper() != str(remote_mpios[code].get("MPIO_TIPO") or "UNKNOWN").upper()
    ]
    type_counts: dict[str, int] = {}
    for row in remote_mpios.values():
        kind = str(row.get("MPIO_TIPO") or "UNKNOWN")
        type_counts[kind] = type_counts.get(kind, 0) + 1
    return {
        "localDepartments": len(local_depts),
        "daneDepartments": len(remote_depts),
        "departmentCodesMatch": set(local_depts) == set(remote_depts),
        "localMunicipalities": len(local_mpios),
        "daneMunicipalityLayerFeatures": len(remote_mpios),
        "municipalityCodesInBoth": len(set(local_mpios) & set(remote_mpios)),
        "daneOnlyCodes": [
            {"code": code, "name": remote_mpios[code].get("MPIO_CNMBRE"), "type": remote_mpios[code].get("MPIO_TIPO")}
            for code in added
        ],
        "localOnlyCodes": missing,
        "parentCodeMismatches": parent_mismatches,
        "administrativeTypeMismatches": type_mismatches,
        "daneTypeCounts": dict(sorted(type_counts.items())),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--audit", type=Path, required=True)
    parser.add_argument("--fragment-output", type=Path)
    parser.add_argument("--verified-at", help="Pin an ISO-8601 UTC timestamp for deterministic output.")
    args = parser.parse_args()
    baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
    verified_at = args.verified_at or datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    errors = []
    for root in (PRIMARY, MIRROR):
        snapshots: list[dict[str, str]] = []
        try:
            service = fetch_json(f"{root}?f=pjson", snapshots)
            layer_names = {row.get("id"): row.get("name") for row in service.get("layers", [])}
            if any(layer_names.get(layer_id) != name for layer_id, name in LAYERS.items()):
                raise RuntimeError("DANE service layer IDs/names do not match DIVIPOLA 2025.")
            _, center_rows = load_layer(root, 305, snapshots)
            _, municipality_rows = load_layer(root, 317, snapshots)
            _, department_rows = load_layer(root, 319, snapshots)
            break
        except Exception as error:  # bounded host failover; no partial files are written
            errors.append(f"{root}: {type(error).__name__}: {error}")
    else:
        print("\n".join(errors), file=sys.stderr)
        return 2

    classes: dict[str, int] = {"1": 0, "2": 0}
    for row in center_rows:
        code = str(row.get("attributes", {}).get("CLAS_CCDGO", ""))
        if code in classes:
            classes[code] += 1
    sidecar = build_sidecar(center_rows, verified_at, root)
    reconciliation = reconcile(baseline, municipality_rows, department_rows)
    points = sum(feature["latitude"] is not None for feature in sidecar["features"])
    fragment = None
    if args.fragment_output:
        sample_ids = [row["attributes"]["OBJECTID"] for row in center_rows[:2]]
        sample_response = request_json(
            root,
            "305/query",
            {
                "objectIds": ",".join(map(str, sample_ids)),
                "outFields": "OBJECTID,MPIO_CDPMP,CLAS_CCDGO,ZU_CDIVI,ZU_CCNCT,ZU_CNMBRE,ZU_NANO",
                "returnGeometry": "false",
                "returnCentroid": "true",
                "outSR": "4326",
                "f": "json",
            },
            snapshots,
        )
        fragment = {
            "sourceService": root,
            "layerId": 305,
            "sourceVersion": "2025",
            "verifiedAt": verified_at,
            "responseSha256": snapshots[-1]["sha256"],
            "response": sample_response,
        }
    audit = {
        "verifiedAt": verified_at,
        "serviceUrl": root,
        "serviceVersion": service.get("currentVersion"),
        "layerIds": LAYERS,
        "primaryHostErrors": errors,
        "pagination": "supportsPagination=false; returnIdsOnly plus sorted OBJECTID groups of 1000",
        "geometry": "Polygon data was not downloaded; layer 305 returnCentroid=true with outSR=4326.",
        "counts": {
            "municipalityLayer": len(municipality_rows),
            "departmentLayer": len(department_rows),
            "centresLayer": len(center_rows),
            "municipalSeatsClass1": classes["1"],
            "populatedCentersClass2": classes["2"],
            "validReferencePoints": points,
            "unknownPoints": len(sidecar["features"]) - points,
        },
        "reconciliation": reconciliation,
        "responseSnapshots": snapshots,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.audit.parent.mkdir(parents=True, exist_ok=True)
    if fragment is not None:
        args.fragment_output.parent.mkdir(parents=True, exist_ok=True)
        args.fragment_output.write_text(json.dumps(fragment, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    args.output.write_text(json.dumps(sidecar, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
    args.audit.write_text(json.dumps(audit, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(audit["counts"] | {"reconciliation": reconciliation, "sidecarSha256": hashlib.sha256(args.output.read_bytes()).hexdigest()}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
