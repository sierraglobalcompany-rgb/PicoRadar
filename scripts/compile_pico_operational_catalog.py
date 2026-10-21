#!/usr/bin/env python3
"""Compile the audited 73-city Pico source into app and audit artifacts."""

from __future__ import annotations

import csv
import hashlib
import json
import re
import unicodedata
from collections import defaultdict
from datetime import date, datetime
from pathlib import Path

from openpyxl import load_workbook


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data/sources/restrictions/PicoRadar_Pico_y_Placa_Colombia_CONSOLIDADO_2026-09-10.xlsx"
MUNICIPALITIES = ROOT / "mobile/assets/catalogs/colombia_trip_municipalities_v1.json"
OUTPUT = ROOT / "mobile/assets/catalogs/pico_jurisdiction_catalog_v1.json"
AUDIT_CSV = ROOT / "docs/data/PICO_73_OPERATIONAL_AUDIT_20260919.csv"
AUDIT_MD = ROOT / "docs/data/PICO_73_OPERATIONAL_AUDIT_20260919.md"
AS_OF = date(2026, 9, 19)

ENGINE_IDS = {
    "05001": "co-ant-medellin",
    "11001": "co-dc-bogota",
    "19001": "co-cau-popayan",
    "50001": "co-met-villavicencio",
    "68001": "co-san-bucaramanga",
}

LEGACY_IDS = {
    "05001": "co-ant-medellin",
    "08001": "co-atl-barranquilla",
    "11001": "co-dc-bogota",
    "13001": "co-bol-cartagena",
    "17001": "co-cal-manizales",
    "19001": "co-cau-popayan",
    "23001": "co-cor-monteria",
    "47001": "co-mag-santa-marta",
    "50001": "co-met-villavicencio",
    "52001": "co-nar-pasto",
    "54001": "co-nds-cucuta",
    "63001": "co-qui-armenia",
    "66001": "co-ris-pereira",
    "68001": "co-san-bucaramanga",
    "73001": "co-tol-ibague",
    "76001": "co-vac-cali",
}

MUNICIPALITY_ALIASES = {
    ("bogota d c", "bogota"): "11001",
    ("bolivar", "cartagena"): "13001",
    ("cordoba", "santa cruz de lorica"): "23417",
    ("norte de santander", "cucuta"): "54001",
    ("valle del cauca", "cali"): "76001",
}


def normalize(value: object) -> str:
    text = unicodedata.normalize("NFD", str(value).lower())
    return " ".join(
        "".join(char for char in text if unicodedata.category(char) != "Mn")
        .replace(".", " ")
        .split()
    )


def iso_date(value: object) -> date | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value)[:10])


def status_for(rows: list[tuple[object, ...]]) -> str:
    active = any(
        row[5] == "SÍ"
        and row[10] == "RESPALDADO SEGÚN ALCANCE"
        and row[4] != "DEROGACIÓN DOCUMENTADA"
        and (iso_date(row[7]) is None or iso_date(row[7]) >= AS_OF)
        for row in rows
    )
    expired = any(
        row[4] == "DEROGACIÓN DOCUMENTADA"
        or (
            row[5] == "SÍ"
            and iso_date(row[7]) is not None
            and iso_date(row[7]) < AS_OF
        )
        for row in rows
    )
    conditional = any(row[5] == "CONDICIONADO" for row in rows)
    if active:
        return "verified"
    if expired:
        return "expired"
    if conditional:
        return "conditional"
    return "pending"


def evidence_summary(city: str, status: str) -> str:
    if status == "verified":
        return (
            "La fuente consolidada contiene al menos una categoría respaldada "
            "para uso documental automático al corte."
        )
    if status == "conditional":
        return (
            "La fuente consolidada condiciona al menos una categoría; requiere "
            "validación local antes de uso automático."
        )
    if status == "expired" and city == "Barranquilla":
        return (
            "La evidencia afirmativa documentada fue derogada; no se presenta "
            "como regla vigente."
        )
    if status == "expired" and city == "Manizales":
        return (
            "La regla temporal documentada terminó antes de la fecha de corte; "
            "no se presenta como vigente."
        )
    return (
        "La fuente consolidada no aporta evidencia suficiente para uso "
        "automático al corte."
    )


def main() -> None:
    municipalities = json.loads(MUNICIPALITIES.read_text(encoding="utf-8"))["records"]
    by_name = {
        (normalize(row["department"]), normalize(row["municipality"])): row
        for row in municipalities
    }
    by_code = {row["code"]: row for row in municipalities}

    workbook = load_workbook(SOURCE, read_only=True, data_only=True)
    rows = [
        row
        for row in workbook["Estado_al_corte"].iter_rows(
            min_row=2,
            values_only=True,
        )
        if row[1] and row[2]
    ]
    grouped: dict[tuple[str, str], list[tuple[object, ...]]] = defaultdict(list)
    for row in rows:
        grouped[(str(row[1]), str(row[2]))].append(row)

    records = []
    for (source_department, source_city), city_rows in sorted(grouped.items()):
        key = (normalize(source_department), normalize(source_city))
        municipality = by_name.get(key)
        if municipality is None:
            code = MUNICIPALITY_ALIASES[key]
            municipality = by_code[code]
        code = municipality["code"]
        status = status_for(city_rows)
        engine_id = ENGINE_IDS.get(code)
        engine_enabled = engine_id is not None
        if engine_enabled and status != "verified":
            raise ValueError(f"Engine-enabled city is not verified: {source_city}")

        evidence_ids = sorted({str(row[0]) for row in city_rows})
        source_ids = sorted(
            {
                item.strip()
                for row in city_rows
                for item in str(row[13] or "").split(";")
                if item.strip()
            }
        )
        source_urls = sorted(
            {
                url.rstrip(".,);")
                for row in city_rows
                for url in re.findall(r"https://[^ |]+", str(row[14] or ""))
            }
        )
        records.append(
            {
                "id": LEGACY_IDS.get(code, f"co-mun-{code}"),
                "municipalityCode": code,
                "name": source_city,
                "displayName": {
                    "05001": "Medellín / Valle de Aburrá",
                    "54001": "Cúcuta / área metropolitana",
                }.get(code, source_city),
                "department": source_department,
                "operationalStatus": status,
                "engineEnabled": engine_enabled,
                "engineJurisdictionId": engine_id,
                "classification": {
                    "verified": "SUPPORTED_CURRENT"
                    if engine_enabled
                    else "VERIFIED_SOURCE_ENGINE_DISABLED",
                    "conditional": "CONDITIONED_SOURCE",
                    "expired": "EXPIRED_SOURCE",
                    "pending": "PENDING_EXACT_RULES",
                }[status],
                "sourceDate": "2026-09-10",
                "evidenceSummary": evidence_summary(source_city, status),
                "evidenceRecordIds": evidence_ids,
                "sourceIds": source_ids,
                "sourceUrls": source_urls,
            }
        )

    counts = {status: sum(row["operationalStatus"] == status for row in records) for status in ("verified", "conditional", "expired", "pending")}
    expected = {"verified": 6, "conditional": 36, "expired": 2, "pending": 29}
    if len(records) != 73 or counts != expected:
        raise ValueError(f"Unexpected reconciliation: {len(records)} rows, {counts}")
    if sum(row["engineEnabled"] for row in records) != 5:
        raise ValueError("Unexpected engine-enabled count")

    payload = {
        "schemaVersion": 2,
        "catalogKey": "pico_jurisdictions",
        "version": "2026.09.19-operational-v1",
        "asOfDate": AS_OF.isoformat(),
        "sourceCutoff": "2026-09-10",
        "source": {
            "path": SOURCE.relative_to(ROOT).as_posix(),
            "sheet": "Estado_al_corte",
            "sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            "categoryRows": len(rows),
        },
        "statusPolicy": {
            "verified": "At least one supported affirmative category remains within its documented coverage limit at the as-of date.",
            "conditional": "At least one category is conditioned and no verified or expired status takes precedence.",
            "expired": "Affirmative evidence is derogated or ended before the as-of date and no verified category remains.",
            "pending": "No category is eligible for automatic documentary use.",
            "engineEnabled": "Separate from documentary status; true only for five existing local rule packs with affirmative coverage on the as-of date.",
        },
        "summary": {**counts, "engineEnabled": 5, "municipalities": 73},
        "records": records,
    }
    with OUTPUT.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")

    AUDIT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with AUDIT_CSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(
            [
                "municipality_code",
                "municipality",
                "department",
                "operational_status",
                "engine_enabled",
                "engine_jurisdiction_id",
                "evidence_record_ids",
                "source_ids",
                "source_urls",
                "evidence_summary",
            ]
        )
        for row in records:
            writer.writerow(
                [
                    row["municipalityCode"],
                    row["name"],
                    row["department"],
                    row["operationalStatus"],
                    str(row["engineEnabled"]).lower(),
                    row["engineJurisdictionId"] or "",
                    ";".join(row["evidenceRecordIds"]),
                    ";".join(row["sourceIds"]),
                    ";".join(row["sourceUrls"]),
                    row["evidenceSummary"],
                ]
            )

    no_external_source = [row["name"] for row in records if not row["sourceUrls"]]
    audit_markdown = (
        "# Auditoría operativa Pico 73 — 2026-09-19\n\n"
        "Fuente: `data/sources/restrictions/PicoRadar_Pico_y_Placa_Colombia_CONSOLIDADO_2026-09-10.xlsx`, hoja `Estado_al_corte`.\n\n"
        "## Conteos\n\n"
        "| Estado | Municipios |\n|---|---:|\n"
        f"| Verificado | {counts['verified']} |\n"
        f"| Condicional | {counts['conditional']} |\n"
        f"| Expirado | {counts['expired']} |\n"
        f"| Pendiente | {counts['pending']} |\n"
        "| **Total** | **73** |\n\n"
        "Solo 5 municipios tienen `engineEnabled=true`: Bogotá, Medellín, Bucaramanga, Popayán y Villavicencio. Itagüí conserva estado documental verificado, pero no tiene paquete específico del motor.\n\n"
        "## Brechas editoriales\n\n"
        "No hay URL externa suficiente en la hoja fuente para: "
        + ", ".join(no_external_source)
        + ". Permanecen pendientes; no se reemplazaron con reglas ni fechas inferidas.\n"
    )
    with AUDIT_MD.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(audit_markdown)


if __name__ == "__main__":
    main()
