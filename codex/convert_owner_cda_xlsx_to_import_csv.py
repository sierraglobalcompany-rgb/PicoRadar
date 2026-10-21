import csv
import json
from pathlib import Path
from urllib.parse import quote_plus

from openpyxl import load_workbook

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "data/sources/cda/CDA_Colombia_FINAL_866_UBICADOS_2026-09-15.xlsx"
CATALOG = ROOT / "mobile/assets/catalogs/cda_catalog_v1.json"
OUTPUT = ROOT / "codex/cda_owner_locations_20260915_import.csv"
AUDIT = ROOT / "codex/cda_owner_locations_20260915_audit.json"
REVIEWED_AT = "2026-09-14"


def text(value):
    return "" if value is None else str(value).strip()


def number(value):
    raw = text(value).replace(",", ".")
    if not raw:
        return None
    try:
        parsed = float(raw)
    except ValueError:
        return None
    return parsed


catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
period_year = catalog["source"]["latestSourceYear"]
period_month = catalog["source"]["latestSourceMonth"]
latest = [
    row
    for row in catalog["entries"]
    if row["sourceYear"] == period_year
    and row["sourceMonth"] == period_month
    and row["certified"] is True
    and row["novelty"] == "NO"
]
by_id = {str(row["id"]): row for row in latest}

workbook = load_workbook(INPUT, read_only=True, data_only=True)
sheet = workbook["CDA_COMPLETOS"]
rows = list(sheet.iter_rows(values_only=True))[1:]

seen = set()
output_rows = []
unknown_ids = []
duplicate_ids = []
missing_address = []
coordinate_rows = []
out_of_bounds_coordinates = []

for row in rows:
    if not row or row[0] is None:
        continue
    cda_id = text(row[0])
    if cda_id in seen:
        duplicate_ids.append(cda_id)
        continue
    seen.add(cda_id)
    if cda_id not in by_id:
        unknown_ids.append(cda_id)
        continue

    address = text(row[4]) or text(row[5])
    lat = number(row[6])
    lon = number(row[7])
    has_coordinate = lat is not None and lon is not None
    if has_coordinate and not (-5 <= lat <= 14 and -82 <= lon <= -66):
        out_of_bounds_coordinates.append(cda_id)
        lat = lon = None
        has_coordinate = False

    if not address and has_coordinate:
        address = f"Coordenada verificada: {lat:.5f}, {lon:.5f}"
    if not address:
        missing_address.append(cda_id)

    google_url = text(row[8])
    source_url = text(row[10]) or google_url
    if not source_url:
        catalog_entry = by_id[cda_id]
        query = (
            f"{catalog_entry['name']}, {catalog_entry['municipality']}, "
            f"{catalog_entry['department']}, Colombia"
        )
        source_url = f"https://www.google.com/maps/search/?api=1&query={quote_plus(query)}"

    status = "verified" if has_coordinate and address else "address_verified"
    if has_coordinate:
        coordinate_rows.append(cda_id)

    output_rows.append(
        {
            "cdaId": cda_id,
            "status": status,
            "latitude": "" if lat is None else f"{lat:.8f}".rstrip("0").rstrip("."),
            "longitude": "" if lon is None else f"{lon:.8f}".rstrip("0").rstrip("."),
            "address": address,
            "locationSourceUrl": source_url,
            "locationReviewedAt": REVIEWED_AT,
            "phone": "",
            "web": "",
            "contactSourceUrl": "",
            "contactReviewedAt": "",
            "vehicleTypes": "",
            "compatibilitySourceUrl": "",
            "compatibilityReviewedAt": "",
        }
    )

missing_from_workbook = sorted(set(by_id) - seen)
fieldnames = [
    "cdaId",
    "status",
    "latitude",
    "longitude",
    "address",
    "locationSourceUrl",
    "locationReviewedAt",
    "phone",
    "web",
    "contactSourceUrl",
    "contactReviewedAt",
    "vehicleTypes",
    "compatibilitySourceUrl",
    "compatibilityReviewedAt",
]
with OUTPUT.open("w", encoding="utf-8", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(output_rows)

audit = {
    "input": str(INPUT),
    "output": str(OUTPUT),
    "catalogPeriod": f"{period_year}-{period_month:02d}",
    "catalogRows": len(latest),
    "workbookRows": len([row for row in rows if row and row[0] is not None]),
    "importRows": len(output_rows),
    "addressRows": sum(1 for row in output_rows if row["address"]),
    "coordinateRows": len(coordinate_rows),
    "missingFromWorkbook": len(missing_from_workbook),
    "duplicateIds": duplicate_ids,
    "unknownIds": unknown_ids,
    "missingAddress": missing_address,
    "outOfBoundsCoordinates": out_of_bounds_coordinates,
    "sampleMissingFromWorkbook": missing_from_workbook[:20],
    "reviewedAt": REVIEWED_AT,
}
AUDIT.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(audit, ensure_ascii=False, indent=2))
