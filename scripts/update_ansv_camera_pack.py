#!/usr/bin/env python3
"""Build PicoRadar's local ANSV camera pack from the public official dataset."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SOURCE_URL = "https://fotodeteccion.ansv.gov.co/map/data/sast.json"
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


def _number(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _speed(value: Any) -> int | None:
    text = _text(value)
    if text is None:
        return None
    match = re.search(r"\d+", text)
    if match is None:
        return None
    speed = int(match.group(0))
    return speed if 10 <= speed <= 130 else None


def _kind(value: Any) -> str:
    text = (_text(value) or "").lower()
    if "velocidad" in text:
        return "speed"
    if "semaforo" in text or "semáforo" in text:
        return "red_light"
    return "mixed"


def _camera_id(result: dict[str, Any], location: dict[str, Any]) -> str:
    for key in ("codigo_unico", "id", "codigo"):
        value = _text(location.get(key))
        if value is not None:
            return value
    request_code = _text(result.get("codigo_solicitud")) or "solicitud"
    lat = _text(location.get("latitud")) or "lat"
    lon = _text(location.get("longitud")) or "lon"
    return f"{request_code}:{lat}:{lon}"


def build_pack(raw: dict[str, Any]) -> dict[str, Any]:
    cameras: list[dict[str, Any]] = []
    for result in raw.get("results", []):
        if not isinstance(result, dict):
            continue
        for location in result.get("ubicaciones", []):
            if not isinstance(location, dict):
                continue
            lat = _number(location.get("latitud"))
            lon = _number(location.get("longitud"))
            if lat is None or lon is None:
                continue
            status = _text(location.get("estado_operacion")) or _text(
                result.get("estado")
            )
            technology = _text(location.get("tipo_tecnologia"))
            cameras.append(
                {
                    "id": _camera_id(result, location),
                    "department": _text(result.get("departamento")),
                    "municipality": _text(result.get("municipio")),
                    "jurisdiction": _text(result.get("jurisdiccion")),
                    "address": _text(location.get("direccion")),
                    "latitude": round(lat, 7),
                    "longitude": round(lon, 7),
                    "status": status,
                    "technology": technology,
                    "kind": _kind(technology),
                    "speedLimitKmh": _speed(location.get("velocidad_maxima_permitida")),
                }
            )
    cameras.sort(key=lambda item: (item["department"] or "", item["municipality"] or "", item["id"]))
    return {
        "schemaVersion": 1,
        "source": {
            "name": "ANSV camaras de fotodeteccion autorizadas",
            "pageUrl": SOURCE_PAGE,
            "dataUrl": SOURCE_URL,
            "fetchedAtUtc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        },
        "cameras": cameras,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    with urllib.request.urlopen(SOURCE_URL, timeout=30) as response:
        raw_bytes = response.read()
    raw = json.loads(raw_bytes.decode("utf-8"))
    pack = build_pack(raw)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(pack, ensure_ascii=False, indent=2, sort_keys=True).encode(
        "utf-8"
    )
    args.output.write_bytes(encoded)
    digest = hashlib.sha256(encoded).hexdigest()
    print(f"wrote {args.output}")
    print(f"cameras {len(pack['cameras'])}")
    print(f"sha256 {digest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
