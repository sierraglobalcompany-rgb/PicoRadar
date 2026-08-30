#!/usr/bin/env python3
"""Build the local Colombian vehicle-registration city catalog.

Source: Datos Abiertos Colombia / MinTransporte / RUNT 2.0 dataset epfm-5fhb.
The app ships the generated JSON; it never calls this network source at runtime.
"""

from __future__ import annotations

import json
import time
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path


DATASET_ID = "epfm-5fhb"
DATASET_URL = (
    "https://www.datos.gov.co/Transporte/"
    "ACTORES-RUNT-POR-MUNICIPIO-Y-DEPARTAMENTO-RUNT2-0/epfm-5fhb"
)
API_ROOT = f"https://www.datos.gov.co/resource/{DATASET_ID}.json"
METADATA_URL = f"https://www.datos.gov.co/api/views/{DATASET_ID}"
OUTPUT = Path(
    "mobile/assets/catalogs/colombia_registration_cities_v1.json"
)

ACCENT_FIXES = {
    "ANTIOQUIA": "Antioquia",
    "ATLANTICO": "Atlántico",
    "BOGOTA D.C.": "Bogotá D.C.",
    "BOLIVAR": "Bolívar",
    "BOYACA": "Boyacá",
    "CALDAS": "Caldas",
    "CAQUETA": "Caquetá",
    "CORDOBA": "Córdoba",
    "CHOCO": "Chocó",
    "GUAINIA": "Guainía",
    "GUAJIRA": "La Guajira",
    "NARINO": "Nariño",
    "QUINDIO": "Quindío",
    "SAN ANDRES": "San Andrés",
    "SUCRE": "Sucre",
    "VALLE DEL CAUCA": "Valle del Cauca",
    "VAUPES": "Vaupés",
    "MEDELLIN": "Medellín",
    "BOGOTA": "Bogotá",
    "CARTAGENA": "Cartagena",
    "IBAGUE": "Ibagué",
    "CUCUTA": "Cúcuta",
    "SANTA MARTA": "Santa Marta",
    "VILLAVICENCIO": "Villavicencio",
    "PEREIRA": "Pereira",
    "MANIZALES": "Manizales",
    "BARRANQUILLA": "Barranquilla",
}


def fetch_json(url: str) -> object:
    with urllib.request.urlopen(url, timeout=45) as response:
        return json.loads(response.read().decode("utf-8"))


def title_case(value: str) -> str:
    normalized = " ".join(value.strip().split()).upper()
    if normalized in ACCENT_FIXES:
        return ACCENT_FIXES[normalized]
    return " ".join(part.capitalize() for part in normalized.split(" "))


def search_key(*parts: str) -> str:
    raw = " ".join(parts).casefold()
    without_marks = "".join(
        char
        for char in unicodedata.normalize("NFD", raw)
        if unicodedata.category(char) != "Mn"
    )
    return " ".join(without_marks.split())


def iso_from_epoch(value: object) -> str | None:
    if not isinstance(value, int):
        return None
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(value))


def main() -> None:
    params = {
        "$select": "nombre_municipio,nombre_departamento,count(*)",
        "$where": (
            "tipo_actor='OT' AND certifico='SI' AND "
            "(registro_novedad='NO APLICA' OR registro_novedad='NO' "
            "OR registro_novedad IS NULL)"
        ),
        "$group": "nombre_municipio,nombre_departamento",
        "$order": "nombre_departamento,nombre_municipio",
        "$limit": "5000",
    }
    rows = fetch_json(f"{API_ROOT}?{urllib.parse.urlencode(params)}")
    if not isinstance(rows, list):
        raise RuntimeError("Unexpected Socrata response")

    records = []
    seen: set[tuple[str, str]] = set()
    for row in rows:
        if not isinstance(row, dict):
            continue
        municipality_raw = str(row.get("nombre_municipio", "")).strip()
        department_raw = str(row.get("nombre_departamento", "")).strip()
        if not municipality_raw or not department_raw:
            continue
        municipality = title_case(municipality_raw)
        department = title_case(department_raw)
        key = (search_key(municipality), search_key(department))
        if key in seen:
            continue
        seen.add(key)
        records.append(
            {
                "municipality": municipality,
                "department": department,
                "displayName": f"{municipality} - {department}",
                "source": DATASET_ID,
            }
        )

    records.sort(key=lambda item: search_key(item["department"], item["municipality"]))
    metadata = fetch_json(METADATA_URL)
    source_updated_at = (
        iso_from_epoch(metadata.get("rowsUpdatedAt")) if isinstance(metadata, dict) else None
    )
    payload = {
        "schemaVersion": 1,
        "source": {
            "name": "ACTORES RUNT POR MUNICIPIO Y DEPARTAMENTO RUNT2.0",
            "datasetId": DATASET_ID,
            "url": DATASET_URL,
            "owner": "Ministerio de Transporte - MinTransporte / RUNT 2.0",
            "filter": "tipo_actor=OT; certifico=SI; registro_novedad NO/NO APLICA/null",
            "sourceUpdatedAt": source_updated_at,
        },
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "recordCount": len(records),
        "records": records,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(records)} registration cities to {OUTPUT}")


if __name__ == "__main__":
    main()
