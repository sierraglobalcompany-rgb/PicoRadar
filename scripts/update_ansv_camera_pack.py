#!/usr/bin/env python3
"""Build PicoRadar's local ANSV camera pack from the official FeatureServer."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from unicodedata import normalize


SOURCE_URL = (
    "https://srvansvargweb.ansv.gov.co/server/rest/services/"
    "Equipos_Fotodeteccion/Equipos_Geo/FeatureServer/0"
)
SOURCE_PAGE = "https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html"
DEFAULT_OUTPUT = (
    Path(__file__).resolve().parents[1]
    / "mobile"
    / "assets"
    / "datasets"
    / "cameras"
    / "camera_pack_v1.json"
)


def _text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.lower() == "none":
        return None
    return text


def _normalized_text(value: Any) -> str | None:
    text = _text(value)
    if text is None:
        return None
    without_accents = "".join(
        char
        for char in normalize("NFKD", text)
        if not 0x300 <= ord(char) <= 0x036F
    )
    return re.sub(r"\s+", " ", without_accents).strip().casefold()


def _camera_status(attributes: dict[str, Any]) -> str | None:
    return _text(attributes.get("ESTADO_EQUIPO")) or _text(
        attributes.get("ESTADO_SOLICITUD")
    )


def _is_approved_status(value: Any) -> bool:
    return _normalized_text(value) == "aprobada"


def _number(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _speed(value: Any) -> int | None:
    if isinstance(value, int):
        speed = value
    else:
        text = _text(value)
        if text is None:
            return None
        match = re.search(r"\d+", text)
        if match is None:
            return None
        speed = int(match.group(0))
    return speed if 10 <= speed <= 130 else None


def _kind(attributes: dict[str, Any]) -> str:
    if attributes.get("VELOCIDAD") == 1:
        return "speed"
    text = (_text(attributes.get("INFRACCIONES")) or "").lower()
    if "velocidad" in text:
        return "speed"
    if attributes.get("SEMAFORO_PARE") == 1:
        return "red_light"
    if "semaforo" in text or "semáforo" in text:
        return "red_light"
    return "mixed"


def _date(value: Any) -> str | None:
    if not isinstance(value, int):
        return None
    return (
        datetime.fromtimestamp(value / 1000, tz=timezone.utc)
        .replace(microsecond=0)
        .isoformat()
    )


def _is_colombia_coordinate(lat: float, lon: float) -> bool:
    return -5.0 <= lat <= 14.0 and -82.5 <= lon <= -66.0


def _distance_meters(
    *,
    from_lat: float,
    from_lon: float,
    to_lat: float,
    to_lon: float,
) -> float:
    radius = 6371000.0
    lat1 = math.radians(from_lat)
    lat2 = math.radians(to_lat)
    delta_lat = math.radians(to_lat - from_lat)
    delta_lon = math.radians(to_lon - from_lon)
    haversine = (
        math.sin(delta_lat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(delta_lon / 2) ** 2
    )
    return radius * 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine))


def _query_json(path: str, params: dict[str, str | int]) -> dict[str, Any]:
    if not path.startswith("https://"):
        raise ValueError("ANSV source must be HTTPS")
    url = f"{path}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def _fetch_features() -> tuple[dict[str, Any], list[dict[str, Any]]]:
    schema = _query_json(SOURCE_URL, {"f": "json"})
    required = {
        "OBJECTID",
        "ID",
        "ID_EQUIPO",
        "TIPO_INSTALACION",
        "INFRACCIONES",
        "VELOCIDAD",
        "VELOCIDAD_INFRACCIONAR",
        "DEPARTAMENTO",
        "MUNICIPIO",
        "JURISDICCION",
        "ESTADO_EQUIPO",
        "ESTADO_SOLICITUD",
        "FECHA_CARGUE",
        "LONGITUD",
        "LATITUD",
    }
    fields = {field["name"] for field in schema.get("fields", [])}
    missing = sorted(required - fields)
    if missing:
        raise ValueError(f"ANSV FeatureServer schema missing fields: {missing}")

    count_response = _query_json(
        f"{SOURCE_URL}/query",
        {"where": "1=1", "returnCountOnly": "true", "f": "json"},
    )
    total = int(count_response["count"])
    page_size = min(int(schema.get("maxRecordCount") or 2000), 2000)
    features: list[dict[str, Any]] = []
    for offset in range(0, total, page_size):
        page = _query_json(
            f"{SOURCE_URL}/query",
            {
                "where": "1=1",
                "outFields": "*",
                "returnGeometry": "true",
                "f": "json",
                "resultRecordCount": page_size,
                "resultOffset": offset,
            },
        )
        features.extend(page.get("features", []))
    if not features:
        raise ValueError("ANSV FeatureServer returned an empty camera pack")
    return schema, features


def build_pack(schema: dict[str, Any], features: list[dict[str, Any]]) -> dict[str, Any]:
    cameras: list[dict[str, Any]] = []
    official_ids: set[str] = set()
    status_distribution: dict[str, int] = {}
    excluded_status_distribution: dict[str, int] = {}
    invalid_approved_coordinates = 0
    for feature in features:
        if not isinstance(feature, dict):
            continue
        attributes = feature.get("attributes")
        if not isinstance(attributes, dict):
            continue
        status = _camera_status(attributes)
        status_key = status or "UNKNOWN"
        status_distribution[status_key] = status_distribution.get(status_key, 0) + 1
        if not _is_approved_status(status):
            excluded_status_distribution[status_key] = (
                excluded_status_distribution.get(status_key, 0) + 1
            )
            continue
        geometry = feature.get("geometry") if isinstance(feature.get("geometry"), dict) else {}
        lat = _number(geometry.get("y")) or _number(attributes.get("LATITUD"))
        lon = _number(geometry.get("x")) or _number(attributes.get("LONGITUD"))
        if lat is None or lon is None or not _is_colombia_coordinate(lat, lon):
            invalid_approved_coordinates += 1
            continue

        official_id = _text(attributes.get("ID_EQUIPO")) or _text(attributes.get("ID"))
        if official_id is not None:
            if official_id in official_ids:
                raise ValueError(f"Duplicate ANSV official id: {official_id}")
            official_ids.add(official_id)
        object_id = _text(attributes.get("OBJECTID")) or "unknown"
        camera_id = f"ansv-{official_id or object_id}"
        cameras.append(
            {
                "id": camera_id,
                "officialId": official_id,
                "department": _text(attributes.get("DEPARTAMENTO")),
                "municipality": _text(attributes.get("MUNICIPIO")),
                "jurisdiction": _text(attributes.get("JURISDICCION")),
                "address": None,
                "latitude": round(lat, 7),
                "longitude": round(lon, 7),
                "status": "Aprobada",
                "technology": _text(attributes.get("TIPO_INSTALACION")),
                "kind": _kind(attributes),
                "speedLimitKmh": _speed(attributes.get("VELOCIDAD_INFRACCIONAR")),
                "sourceVerifiedAt": _date(attributes.get("FECHA_CARGUE")),
            }
        )
    cameras.sort(
        key=lambda item: (item["department"] or "", item["municipality"] or "", item["id"])
    )
    exact_duplicate_coordinates = _count_exact_duplicate_coordinates(cameras)
    near_duplicate_coordinates = _count_near_duplicate_coordinates(cameras)
    return {
        "schemaVersion": 1,
        "source": {
            "name": "ANSV camaras de fotodeteccion autorizadas",
            "pageUrl": SOURCE_PAGE,
            "dataUrl": f"{SOURCE_URL}/query",
            "fetchedAtUtc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
            "featureServerLayer": schema.get("name"),
            "sourceTotalCount": len(features),
            "statusDistribution": dict(sorted(status_distribution.items())),
            "approvedStatusCount": status_distribution.get("Aprobada", 0),
            "approvedRuntimeCandidateCount": len(cameras),
            "approvedWithoutRuntimeCoordinatesCount": invalid_approved_coordinates,
            "excludedCount": len(features) - len(cameras),
            "excludedStatusDistribution": dict(sorted(excluded_status_distribution.items())),
            "duplicateAudit": {
                "duplicateOfficialIds": 0,
                "exactDuplicateCoordinates": exact_duplicate_coordinates,
                "nearDuplicateCoordinatePairsWithin10m": near_duplicate_coordinates,
            },
        },
        "cameras": cameras,
    }


def _count_exact_duplicate_coordinates(cameras: list[dict[str, Any]]) -> int:
    seen: set[tuple[float, float]] = set()
    duplicates = 0
    for camera in cameras:
        coordinates = (float(camera["latitude"]), float(camera["longitude"]))
        if coordinates in seen:
            duplicates += 1
        else:
            seen.add(coordinates)
    return duplicates


def _count_near_duplicate_coordinates(cameras: list[dict[str, Any]]) -> int:
    pairs = 0
    for index, camera in enumerate(cameras):
        lat = float(camera["latitude"])
        lon = float(camera["longitude"])
        for other in cameras[index + 1 :]:
            distance = _distance_meters(
                from_lat=lat,
                from_lon=lon,
                to_lat=float(other["latitude"]),
                to_lon=float(other["longitude"]),
            )
            if 0 < distance <= 10:
                pairs += 1
    return pairs


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    schema, features = _fetch_features()
    pack = build_pack(schema, features)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(pack, ensure_ascii=False, indent=2, sort_keys=True).encode(
        "utf-8"
    )
    args.output.write_bytes(encoded)
    digest = hashlib.sha256(encoded).hexdigest()
    source = pack["source"]
    print(f"wrote {args.output}")
    print(f"sourceTotalCount {source['sourceTotalCount']}")
    print(f"statusDistribution {json.dumps(source['statusDistribution'], ensure_ascii=False, sort_keys=True)}")
    print(f"approvedStatusCount {source['approvedStatusCount']}")
    print(f"approvedRuntimeCandidateCount {source['approvedRuntimeCandidateCount']}")
    print(f"approvedWithoutRuntimeCoordinatesCount {source['approvedWithoutRuntimeCoordinatesCount']}")
    print(f"excludedCount {source['excludedCount']}")
    print(f"cameras {len(pack['cameras'])}")
    print(f"duplicateAudit {json.dumps(source['duplicateAudit'], sort_keys=True)}")
    print(f"sha256 {digest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
