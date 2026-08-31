#!/usr/bin/env python3
"""Build the PicoRadar CDA catalog from the official RUNT open dataset."""

from __future__ import annotations

import hashlib
import json
import sys
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path


DATASET_ID = "epfm-5fhb"
DATASET_NAME = "ACTORES RUNT POR MUNICIPIO Y DEPARTAMENTO RUNT2.0"
SOURCE_URL = (
    "https://www.datos.gov.co/Transporte/"
    "ACTORES-RUNT-POR-MUNICIPIO-Y-DEPARTAMENTO-RUNT2-0/epfm-5fhb"
)
API_ROOT = f"https://www.datos.gov.co/resource/{DATASET_ID}.json"
METADATA_URL = f"https://www.datos.gov.co/api/views/{DATASET_ID}"
OUTPUT = Path(__file__).resolve().parents[1] / "mobile" / "assets" / "catalogs" / "cda_catalog_v1.json"

REQUIRED_FIELDS = {
    "id_empresa",
    "nombre_empresa",
    "nit_empresa",
    "nombre_municipio",
    "codigo_departamento",
    "nombre_departamento",
    "tipo_actor",
    "mes_nombre",
    "a_o",
    "certifico",
    "registro_novedad",
}

MONTHS = {
    "ENERO": 1,
    "FEBRERO": 2,
    "MARZO": 3,
    "ABRIL": 4,
    "MAYO": 5,
    "JUNIO": 6,
    "JULIO": 7,
    "AGOSTO": 8,
    "SEPTIEMBRE": 9,
    "SETIEMBRE": 9,
    "OCTUBRE": 10,
    "NOVIEMBRE": 11,
    "DICIEMBRE": 12,
}


def fetch_json(url: str) -> object:
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def query(params: dict[str, str | int]) -> list[dict[str, object]]:
    url = f"{API_ROOT}?{urllib.parse.urlencode(params)}"
    data = fetch_json(url)
    if not isinstance(data, list):
        raise RuntimeError("Unexpected Socrata response shape.")
    return data


def clean(value: object) -> str:
    return str(value or "").strip()


def upper(value: object) -> str:
    return clean(value).upper()


def month_number(value: object) -> int | None:
    return MONTHS.get(upper(value))


def source_period(row: dict[str, object]) -> tuple[int, int]:
    year = int(clean(row.get("a_o")))
    month = month_number(row.get("mes_nombre"))
    if month is None:
        raise ValueError(f"Unknown month name: {row.get('mes_nombre')}")
    return year, month


def is_safe_current_cda(row: dict[str, object]) -> bool:
    return (
        upper(row.get("tipo_actor")) == "CDA"
        and upper(row.get("certifico")) == "SI"
        and upper(row.get("registro_novedad")) == "NO"
    )


def period_label(period: tuple[int, int]) -> str:
    year, month = period
    return f"{year}-{month:02d}"


def latest_accepted_period(
    periods: set[tuple[int, int]],
    generated_at: datetime,
) -> tuple[int, int]:
    current_period = (generated_at.year, generated_at.month)
    accepted = [period for period in periods if period <= current_period]
    if not accepted:
        raise RuntimeError("Official CDA source has no non-future source period.")
    return max(accepted)


def main() -> int:
    metadata = fetch_json(METADATA_URL)
    fields = {
        column.get("fieldName")
        for column in metadata.get("columns", [])
        if isinstance(column, dict)
    }
    missing = sorted(REQUIRED_FIELDS - fields)
    if missing:
        raise RuntimeError(f"Dataset schema changed; missing fields: {', '.join(missing)}")

    source_total = query({"$select": "count(*)"})[0]["count"]
    cda_source_total = query(
        {"$select": "count(*)", "$where": "upper(tipo_actor)='CDA'"}
    )[0]["count"]

    rows: list[dict[str, object]] = []
    limit = 50000
    offset = 0
    while True:
        page = query(
            {
                "$limit": limit,
                "$offset": offset,
                "$where": "upper(tipo_actor)='CDA'",
                "$order": "id_empresa,a_o,mes_nombre",
            }
        )
        rows.extend(page)
        if len(page) < limit:
            break
        offset += limit

    if not rows:
        raise RuntimeError("Official CDA source returned an empty catalog.")

    generated_at_dt = datetime.now(timezone.utc).replace(microsecond=0)
    generated_at = generated_at_dt.isoformat().replace("+00:00", "Z")

    period_rows: Counter[tuple[int, int]] = Counter()
    period_ids: dict[tuple[int, int], set[str]] = defaultdict(set)
    periods: set[tuple[int, int]] = set()
    latest_safe_period_by_id: dict[str, tuple[int, int]] = {}
    for row in rows:
        cda_id = clean(row.get("id_empresa"))
        if not cda_id:
            continue
        period = source_period(row)
        periods.add(period)
        period_rows[period] += 1
        period_ids[period].add(cda_id)
        if is_safe_current_cda(row):
            previous = latest_safe_period_by_id.get(cda_id)
            if previous is None or period > previous:
                latest_safe_period_by_id[cda_id] = period

    latest_global_period = max(periods)
    accepted_period = latest_accepted_period(periods, generated_at_dt)
    if latest_global_period > accepted_period:
        print(
            "WARNING=Future source periods ignored for active CDA catalog: "
            f"{period_label(latest_global_period)}"
        )

    rows_in_accepted_period = [
        row for row in rows if source_period(row) == accepted_period
    ]
    rows_by_id: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in rows_in_accepted_period:
        cda_id = clean(row.get("id_empresa"))
        if cda_id:
            rows_by_id[cda_id].append(row)

    excluded = Counter()
    entries: list[dict[str, object]] = []
    latest_accepted_ids = set(rows_by_id)
    stale_historical_ids = {
        cda_id
        for cda_id, period in latest_safe_period_by_id.items()
        if period < accepted_period and cda_id not in latest_accepted_ids
    }
    excluded["stale_historical_cda"] = len(stale_historical_ids)

    for cda_id, current_rows in rows_by_id.items():
        relevant = [
            "nombre_empresa",
            "nit_empresa",
            "nombre_municipio",
            "codigo_departamento",
            "nombre_departamento",
            "certifico",
            "registro_novedad",
        ]
        signatures = {
            tuple(clean(row.get(key)) for key in relevant)
            for row in current_rows
        }
        if len(signatures) > 1:
            excluded["ambiguous_current_duplicate"] += 1
            continue
        row = current_rows[0]
        required_values = {
            "id": cda_id,
            "name": clean(row.get("nombre_empresa")),
            "municipality": clean(row.get("nombre_municipio")),
            "department": clean(row.get("nombre_departamento")),
            "departmentCode": clean(row.get("codigo_departamento")),
        }
        if any(not value for value in required_values.values()):
            excluded["missing_required_field"] += 1
            continue
        if upper(row.get("tipo_actor")) != "CDA":
            excluded["non_cda_actor"] += 1
            continue
        if upper(row.get("certifico")) != "SI":
            excluded["certifico_not_si"] += 1
            continue
        if upper(row.get("registro_novedad")) != "NO":
            excluded["unsafe_novelty"] += 1
            continue
        year, month = source_period(row)
        entries.append(
            {
                **required_values,
                "nit": clean(row.get("nit_empresa")) or None,
                "sourceYear": year,
                "sourceMonth": month,
                "sourceMonthName": upper(row.get("mes_nombre")),
                "certified": is_safe_current_cda(row),
                "novelty": upper(row.get("registro_novedad")),
                "sourceVerifiedAt": generated_at,
                "generatedAt": generated_at,
            }
        )

    if not entries:
        raise RuntimeError("All current CDA rows were excluded.")

    entries.sort(
        key=lambda item: (
            item["department"],
            item["municipality"],
            item["name"],
            item["id"],
        )
    )
    latest_year, latest_month = accepted_period
    latest_month_name = next(
        upper(row.get("mes_nombre"))
        for row in rows_in_accepted_period
        if source_period(row) == accepted_period
    )
    catalog = {
        "schemaVersion": 1,
        "source": {
            "provider": "Ministerio de Transporte / RUNT 2.0",
            "datasetId": DATASET_ID,
            "datasetName": DATASET_NAME,
            "sourceUrl": SOURCE_URL,
            "sourceVerifiedAt": generated_at,
            "latestSourceYear": latest_year,
            "latestSourceMonth": latest_month,
            "latestSourceMonthName": latest_month_name,
        },
        "metrics": {
            "sourceRows": int(source_total),
            "cdaSourceRows": int(cda_source_total),
            "latestSourcePeriod": period_label(accepted_period),
            "globalLatestSourcePeriod": period_label(latest_global_period),
            "futureSourcePeriodsIgnored": latest_global_period > accepted_period,
            "latestPeriodCdaRows": period_rows[accepted_period],
            "currentUniqueCdaCount": len(entries),
            "staleHistoricalCdaExcludedCount": excluded["stale_historical_cda"],
            "certificoNotSiCount": excluded["certifico_not_si"],
            "unsafeNoveltyCount": excluded["unsafe_novelty"],
            "ambiguousCurrentDuplicateCount": excluded[
                "ambiguous_current_duplicate"
            ],
            "uniqueCdaCount": len(entries),
            "excludedCurrentStatusCount": sum(excluded.values()),
            "municipalityCount": len({item["municipality"] for item in entries}),
            "departmentCount": len({item["department"] for item in entries}),
            "excludedReasons": dict(sorted(excluded.items())),
            "sponsoredCdaCount": 0,
        },
        "entries": entries,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    OUTPUT.write_text(payload, encoding="utf-8", newline="\n")
    digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    print(f"SOURCE_ROWS={source_total}")
    print(f"CDA_SOURCE_ROWS={cda_source_total}")
    print(f"LATEST_SOURCE_PERIOD={period_label(accepted_period)}")
    print(f"GLOBAL_LATEST_SOURCE_PERIOD={period_label(latest_global_period)}")
    print(f"LATEST_PERIOD_CDA_ROWS={period_rows[accepted_period]}")
    print(f"CURRENT_UNIQUE_CDA_COUNT={len(entries)}")
    print(f"STALE_HISTORICAL_CDA_EXCLUDED_COUNT={excluded['stale_historical_cda']}")
    print(f"CERTIFICO_NOT_SI_COUNT={excluded['certifico_not_si']}")
    print(f"UNSAFE_NOVELTY_COUNT={excluded['unsafe_novelty']}")
    print(
        "AMBIGUOUS_CURRENT_DUPLICATE_COUNT="
        f"{excluded['ambiguous_current_duplicate']}"
    )
    print(f"UNIQUE_CDA_COUNT={len(entries)}")
    print(f"EXCLUDED_CURRENT_STATUS_COUNT={sum(excluded.values())}")
    print(f"MUNICIPALITY_COUNT={catalog['metrics']['municipalityCount']}")
    print(f"DEPARTMENT_COUNT={catalog['metrics']['departmentCount']}")
    print(f"CATALOG_BYTES={len(payload.encode('utf-8'))}")
    print(f"SHA256={digest}")
    print(f"OUTPUT={OUTPUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
