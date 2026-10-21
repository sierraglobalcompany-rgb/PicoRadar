import csv
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "codex/cda_owner_locations_20260915_import.csv"
OUTPUT = ROOT / "codex/cda_owner_locations_20260915_geocoded.csv"
CACHE = ROOT / "codex/cda_owner_locations_20260915_geocode_cache.json"
AUDIT = ROOT / "codex/cda_owner_locations_20260915_geocode_audit.json"
CATALOG = ROOT / "mobile/assets/catalogs/cda_catalog_v1.json"
ARCGIS_URL = (
    "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/"
    "findAddressCandidates"
)
MIN_SCORE = 70.0


def colombia(lat, lon):
    return -5 <= lat <= 14 and -82 <= lon <= -66


def read_rows():
    with INPUT.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def request_candidates(query):
    params = {
        "f": "json",
        "SingleLine": query,
        "maxLocations": "5",
        "outFields": "Match_addr,Addr_type,Score",
        "countryCode": "COL",
    }
    url = f"{ARCGIS_URL}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": "PicoRadar-CDA-geocoder/1.0"})
    with urllib.request.urlopen(req, timeout=30) as response:
        data = json.loads(response.read().decode("utf-8"))
    return url, data.get("candidates", [])


def catalog_by_id():
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    year = catalog["source"]["latestSourceYear"]
    month = catalog["source"]["latestSourceMonth"]
    return {
        entry["id"]: entry
        for entry in catalog["entries"]
        if entry["sourceYear"] == year
        and entry["sourceMonth"] == month
        and entry["certified"] is True
        and entry["novelty"] == "NO"
    }


def best_candidate(row, entry, cache):
    if row["latitude"].strip() and row["longitude"].strip():
        return {
            "latitude": float(row["latitude"]),
            "longitude": float(row["longitude"]),
            "score": 100.0,
            "sourceUrl": row["locationSourceUrl"],
            "matchAddress": row["address"],
            "method": "owner_verified_coordinate",
            "status": "verified",
        }
    key = row["cdaId"]
    if key in cache:
        return cache[key]
    address = row["address"].strip()
    name = entry["name"].strip()
    municipality = entry["municipality"].strip()
    department = entry["department"].strip()
    queries = [
        f"{name}, {address}, {municipality}, {department}, Colombia",
        f"{address}, {municipality}, {department}, Colombia",
        f"{name}, {municipality}, {department}, Colombia",
    ]
    best = None
    failures = []
    for query in queries:
        try:
            url, candidates = request_candidates(query)
        except Exception as exc:  # noqa: BLE001 - audit needs exact failure text.
            failures.append({"query": query, "error": str(exc)})
            continue
        for candidate in candidates:
            location = candidate.get("location") or {}
            lon = location.get("x")
            lat = location.get("y")
            score = float(candidate.get("score") or candidate.get("attributes", {}).get("Score") or 0)
            if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
                continue
            if not colombia(lat, lon):
                continue
            current = {
                "latitude": lat,
                "longitude": lon,
                "score": score,
                "sourceUrl": url,
                "matchAddress": candidate.get("address") or candidate.get("attributes", {}).get("Match_addr", ""),
                "method": "geocoded_from_address",
                "status": "geocoded",
            }
            if best is None or current["score"] > best["score"]:
                best = current
        if best is not None and best["score"] >= 90:
            break
        time.sleep(0.05)
    if best is None:
        best = {
            "latitude": None,
            "longitude": None,
            "score": 0,
            "sourceUrl": "",
            "matchAddress": "",
            "method": "geocode_failed",
            "status": "address_verified",
            "failures": failures,
        }
    cache[key] = best
    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    time.sleep(0.08)
    return best


def main():
    rows = read_rows()
    entries = catalog_by_id()
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    output = []
    failed = []
    low_score = []
    for index, row in enumerate(rows, start=1):
        result = best_candidate(row, entries[row["cdaId"]], cache)
        next_row = dict(row)
        if result["latitude"] is not None and result["longitude"] is not None:
            next_row["status"] = result["status"]
            next_row["latitude"] = f'{result["latitude"]:.8f}'.rstrip("0").rstrip(".")
            next_row["longitude"] = f'{result["longitude"]:.8f}'.rstrip("0").rstrip(".")
            next_row["locationSourceUrl"] = result["sourceUrl"]
            next_row["locationMethod"] = result["method"]
            next_row["locationScore"] = f'{float(result["score"]):.2f}'.rstrip("0").rstrip(".")
            if result["score"] < MIN_SCORE:
                low_score.append({"cdaId": row["cdaId"], "score": result["score"]})
        else:
            failed.append(row["cdaId"])
        output.append(next_row)
        if index % 50 == 0:
            print(f"geocoded {index}/{len(rows)}; failed={len(failed)}; lowScore={len(low_score)}", flush=True)
    fieldnames = list(rows[0].keys())
    for extra in ["locationMethod", "locationScore"]:
        if extra not in fieldnames:
            fieldnames.append(extra)
    with OUTPUT.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(output)
    audit = {
        "input": str(INPUT),
        "output": str(OUTPUT),
        "rows": len(rows),
        "geocodedRows": len(rows) - len(failed),
        "failed": failed,
        "lowScore": low_score,
        "minScore": MIN_SCORE,
        "cache": str(CACHE),
        "provider": "ArcGIS World Geocoding Service",
    }
    AUDIT.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(audit, ensure_ascii=False, indent=2))
    if failed:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
