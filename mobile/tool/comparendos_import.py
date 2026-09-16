"""Reconcile public directory PDFs offline; run from the repository root.

python mobile/tool/comparendos_import.py --extract
Without --extract, rebuild from the existing extracted source_rows.json.

Requires the existing audit environment's pdfplumber, never a mobile dependency.
The downloaded inputs and generated audit files live in temp/COMPARENDOS_OWNER.
No contact/person fields enter the application asset.
"""

import json
import re
import unicodedata
import hashlib
from collections import Counter, defaultdict
from pathlib import Path

import pdfplumber

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / 'temp/COMPARENDOS_OWNER'
SOURCES = {
    'fcm_organismos': 'https://www.fcm.org.co/wp-content/uploads/2021/07/Directorio-Organismos-de-Transito.pdf',
    'fcm_autoridades': 'https://www.fcm.org.co/wp-content/uploads/2021/08/Base-de-Datos-Autoridades-de-Transito.pdf',
    'runt': 'https://www.runt.gov.co/sites/default/files/documentos/LISTADO%20EXTENSIONES%20IP%20ORGANISMOS%20DE%20TRANSITO.pdf',
}


def clean(value):
    return ' '.join((value or '').split())


def norm(value):
    text = ''.join(c for c in unicodedata.normalize('NFD', value.lower())
                   if unicodedata.category(c) != 'Mn')
    return re.sub(r'[^a-z0-9]+', ' ', text).strip()


def name_key(row):
    text = norm(row['name'])
    # Recover common words fused by the PDF's narrow authority column.
    for fused, spaced in {
        'inspeccionmunicipaldepoliciaytransito': 'inspeccion municipal de policia y transito',
        'secretariadetransporteytransitodela': 'secretaria de transporte y transito de la',
        'secretariadetransitoytransportedela': 'secretaria de transito y transporte de la',
        'inspecciondetransitoytransportedela': 'inspeccion de transito y transporte de la',
        'inspecciondepoliciaytransitode': 'inspeccion de policia y transito de',
        'inspecciondepoliciadetransitodesan': 'inspeccion de policia de transito de san',
    }.items():
        text = text.replace(fused, spaced)
    # Word order and municipal qualifiers vary across the directories. Preserve
    # entity type and department names: an office address is not an identity.
    words = text.replace('transportes', 'transporte').split()
    stop = {'de', 'del', 'la', 'el', 'y', 'los', 'las', 'municipal', 'municipio', 'distrital'}
    return ' '.join(sorted(w for w in words if w not in stop))


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def extract():
    rows = []
    page_counts = {}
    extraction_checks = []
    for source in SOURCES:
        counts = []
        with pdfplumber.open(AUDIT / f'{source}.pdf') as pdf:
            for page_no, page in enumerate(pdf.pages, 1):
                before = len(rows)
                if source == 'runt':
                    # Ruled-table extraction drops rows at page boundaries.
                    # Use numbered row anchors and the printed column positions.
                    words = page.extract_words(x_tolerance=1, y_tolerance=2)
                    anchors = [w for w in words if w['x0'] < 90 and w['text'].isdigit()]
                    unmatched = [w for w in words if w['top'] >= min(a['top'] for a in anchors) - 3
                                 and not any(abs(w['top'] - a['top']) < 3 for a in anchors)]
                    assert not unmatched, (source, page_no, unmatched)
                    extraction_checks.append(dict(sourceId=source, page=page_no,
                                                  numberedRows=len(anchors), unassignedBodyWords=0))
                    for anchor in anchors:
                        cells = [[] for _ in range(4)]
                        for word in words:
                            if abs(word['top'] - anchor['top']) < 3 and word['x0'] >= 90:
                                x = word['x0']
                                column = 0 if x < 615 else 1 if x < 760 else 2 if x < 900 else 3
                                cells[column].append(word['text'])
                        name, department, municipality, extension = map(' '.join, cells)
                        assert all((name, department, municipality, extension)), anchor
                        rows.append(dict(id=f'runt-{int(anchor["text"]):03}', sourceId=source,
                                         page=page_no, row=int(anchor['text']), name=name,
                                         department=department, officeMunicipality=municipality))
                else:
                    tables = page.extract_tables()
                    assert len(tables) == 1, (source, page_no, len(tables))
                    for table in tables:
                        for table_row, cells in enumerate(table, 1):
                            assert len(cells) == (9 if source == 'fcm_organismos' else 12)
                            department, municipality, name = map(clean, cells[:3])
                            if not department or norm(department) in (
                                'departamentoubicacion', 'dpto', 'datos autoridades de transito',
                            ):
                                continue
                            assert municipality and name, (source, page_no, table_row, cells[:3])
                            rows.append(dict(id=f'{source}-p{page_no}-r{table_row}', sourceId=source,
                                             page=page_no, row=table_row, name=name,
                                             department=department, officeMunicipality=municipality))
                counts.append(len(rows) - before)
        page_counts[source] = counts
    assert [r['row'] for r in rows if r['sourceId'] == 'runt'] == list(range(1, 298))
    assert len({r['id'] for r in rows}) == len(rows)
    assert Counter(r['sourceId'] for r in rows) == {
        'fcm_organismos': 398, 'fcm_autoridades': 308, 'runt': 297,
    }, 'Source changed: review the PDF before changing intake expectations.'
    write_json(AUDIT / 'source_rows.json', rows)
    write_json(AUDIT / 'intake_counts.json', page_counts)
    write_json(AUDIT / 'extraction_checks.json', extraction_checks)
    print(json.dumps(page_counts))
    groups = defaultdict(list)
    for row in rows:
        groups[norm(row['department']) + ' | ' + norm(row['officeMunicipality'])].append(row)
    lines = []
    for key, entries in sorted(groups.items()):
        lines.append('\n' + key)
        lines.extend(f'{r["id"]}: {r["name"]}' for r in entries)
    (AUDIT / 'location_review.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'{len(rows)} source rows, {len(groups)} raw location labels')


def build():
    rows = json.loads((AUDIT / 'source_rows.json').read_text(encoding='utf-8'))
    reviews = json.loads((ROOT / 'mobile/tool/comparendos_verifications.json').read_text(encoding='utf-8'))
    municipalities = json.loads((ROOT / 'mobile/assets/catalogs/colombia_trip_municipalities_v1.json').read_text(encoding='utf-8'))['records']
    locations = {(norm(r['department']), norm(r['municipality'])): r for r in municipalities}
    by_code = {r['code']: r for r in municipalities}
    department_aliases = {'bogota': 'bogota d c', 'guajira': 'la guajira', 'norte santander': 'norte de santander'}
    groups = defaultdict(list)
    reviewed_rows = {}
    for review in reviews['authorities']:
        for ref in review['sourceRecordIds']:
            assert ref not in reviewed_rows, ref
            reviewed_rows[ref] = review['id']
    # Name equivalence does not establish legal succession or territorial coverage.
    for row in rows:
        department = department_aliases.get(norm(row['department']), norm(row['department']))
        municipality = norm(row['officeMunicipality'])
        fingerprint = name_key(row)
        key = reviewed_rows.get(row['id'], (department, municipality, fingerprint))
        groups[key].append(row)
    assert set(reviewed_rows) <= {r['id'] for r in rows}
    verified_by_id = {r['id']: r for r in reviews['authorities']}
    authorities = []
    for key, entries in groups.items():
        first = entries[0]
        review = verified_by_id.get(key) if isinstance(key, str) else None
        authority_id = key if review else 'inventory-' + first['id']
        department = department_aliases.get(norm(first['department']), norm(first['department']))
        location = locations.get((department, norm(first['officeMunicipality'])))
        if review:
            location = by_code[review['municipalityCodes'][0]]
        name = review['name'] if review else first['name']
        normalized_name = norm(name)
        if any(x in normalized_name for x in ('consorcio', 'union temporal', 'sociedad', 'empresa', ' s a', ' sas')):
            kind = 'operator_or_company'
        elif any(x in normalized_name for x in ('departamental', 'departamento de', 'itboy', 'del departamento')):
            kind = 'departmental_or_office'
        else:
            kind = 'authority_or_office'
        entry = dict(
            id=authority_id, name=name,
            platformName=review['platformName'] if review else 'Portal pendiente de verificación',
            municipalityCodes=review['municipalityCodes'] if review else [],
            officeMunicipality=location['municipality'] if location else first['officeMunicipality'],
            department=location['department'] if location else first['department'],
            officeMunicipalityCode=location['code'] if location else None,
            entryKind=kind,
            consultationUrl=review['consultationUrl'] if review else None,
            institutionalUrl=review['institutionalUrl'] if review else None,
            evidenceUrl=review['evidenceUrl'] if review else None,
            verifiedAt=review['verifiedAt'] if review else None,
            verificationStatus='verified' if review else 'pending',
            portalStatus=('direct_consultation' if review['consultationUrl'] else 'institution_only') if review else 'pending',
            researchStatus='individually_reviewed' if review else 'not_individually_reviewed',
            coverageStatus='verified_municipal' if review else 'pending',
            currentExistenceStatus='official_page_reviewed' if review else 'not_revalidated',
            identityStatus='reviewed_source_aliases' if review else 'source_name_only',
            sourceRecordIds=[r['id'] for r in entries],
            sourceNames=list(dict.fromkeys(r['name'] for r in entries)),
        )
        authorities.append(entry)
        for row in entries:
            row['authorityId'] = authority_id
    # Possible aliases are retained, identified, and never silently coalesced by city.
    locations_to_entries = defaultdict(list)
    for entry in authorities:
        key = (norm(entry['department']), norm(entry['officeMunicipality']))
        locations_to_entries[key].append(entry['id'])
    for entry in authorities:
        key = (norm(entry['department']), norm(entry['officeMunicipality']))
        entry['sameOfficeLocationIds'] = [i for i in locations_to_entries[key] if i != entry['id']]
    authorities.sort(key=lambda r: (norm(r['department']), norm(r['officeMunicipality']), norm(r['name']), r['id']))
    counts = Counter(r['sourceId'] for r in rows)
    sources = [dict(id=k, url=v, observedRowCount=counts[k],
                    historical=True, publicationDate=None,
                    fileSha256=hashlib.sha256((AUDIT / f'{k}.pdf').read_bytes()).hexdigest(),
                    retrievedAt=reviews['reviewedAt']) for k, v in SOURCES.items()]
    summary = dict(sourceRows=len(rows), inventoryEntries=len(authorities),
                   reconciledRows=len(rows)-len(authorities),
                   verifiedEntries=len(reviews['authorities']),
                   directConsultationEntries=sum(r['consultationUrl'] is not None for r in authorities),
                   institutionOnlyEntries=sum(r['institutionalUrl'] is not None and r['consultationUrl'] is None for r in authorities),
                   pendingEntries=len(authorities)-len(reviews['authorities']),
                   individuallyReviewedEntries=len(reviews['authorities']),
                   notIndividuallyReviewedEntries=len(authorities)-len(reviews['authorities']),
                   supplementaryMunicipalityLeads=len(reviews['pendingChecks']),
                   verifiedMunicipalities=len({c for r in authorities for c in r['municipalityCodes']}),
                   officeLocationCodesMatched=sum(r['officeMunicipalityCode'] is not None for r in authorities),
                   entriesWithUnresolvedOfficeCode=sum(r['officeMunicipalityCode'] is None for r in authorities))
    asset = dict(schemaVersion=1, version='2026-09-13.directory-v1',
                 reviewedAt=reviews['reviewedAt'],
                 scope='Historical national source inventory; not a census of current legal authorities or legal coverage.',
                 reconciliationPolicy='Equivalent name words at the same stated location (accent, order, function words, municipal qualifiers and PDF spacing normalization), plus explicitly reviewed aliases. Entity type and department names retained. Other same-location records retained separately; identity/coverage/current existence pending.',
                 summary=summary, sources=sources,
                 simit=dict(reviews['simit'], verifiedAt=reviews['reviewedAt']),
                 authorities=authorities, sourceRecords=rows)
    write_json(ROOT / 'mobile/assets/catalogs/comparendos_authorities_v1.json', asset)
    write_json(AUDIT / 'reconciliation.json', dict(summary=summary, records=rows))
    write_json(AUDIT / 'link_review.json', reviews)
    write_json(AUDIT / 'individual_review_queue.json', {
        'status': 'PARTIAL_NOT_COMPLETE',
        'goal': 'Individually research every inventoried authority, including current identity, official portals and evidenced coverage.',
        'reviewedEntries': summary['individuallyReviewedEntries'],
        'pendingEntries': [dict(id=r['id'], name=r['name'], department=r['department'],
                                officeMunicipality=r['officeMunicipality'], sourceRecordIds=r['sourceRecordIds'])
                           for r in authorities if r['researchStatus'] == 'not_individually_reviewed'],
        'supplementaryMunicipalityLeads': reviews['pendingChecks'],
    })
    print(json.dumps(summary))


if __name__ == '__main__':
    import sys
    if '--extract' in sys.argv:
        extract()
    build()
