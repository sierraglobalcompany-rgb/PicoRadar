import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const inventoryUrl = new URL('../assets/catalogs/cda_catalog_v1.json', import.meta.url);
const geographyUrl = new URL('../assets/catalogs/cda_geography_v1.json', import.meta.url);
const coverageUrl = new URL('../../codex/cda_geography_coverage.csv', import.meta.url);
const reviewDate = '2026-09-14';
const expectedFields = [
  'certified', 'department', 'departmentCode', 'generatedAt', 'id',
  'municipality', 'name', 'nit', 'novelty', 'sourceMonth',
  'sourceMonthName', 'sourceVerifiedAt', 'sourceYear',
].sort();
const columns = [
  'id', 'name', 'municipality', 'department', 'status',
  'missing_location', 'missing_evidence', 'inventory_source_url',
  'inventory_source_period', 'inventory_fields_checked_on',
  'location_source_url', 'location_verified_at', 'evidence_scope',
];

function csvCell(value) {
  return `"${String(value).replaceAll('"', '""')}"`;
}

export function buildCoverage(catalog, geography = { entries: [] }) {
  assert.equal(catalog.schemaVersion, 1, 'Re-review changed inventory schema.');
  assert.equal(catalog.source?.datasetId, 'epfm-5fhb', 'Re-review changed source.');
  const sourceUrl = new URL(catalog.source.sourceUrl);
  assert.equal(sourceUrl.protocol, 'https:');
  assert.equal(sourceUrl.hostname, 'www.datos.gov.co');
  assert.ok(sourceUrl.pathname.endsWith('/epfm-5fhb'));
  assert.ok(Array.isArray(catalog.entries), 'Inventory entries must be an array.');
  assert.equal(catalog.entries.length, 964, 'Re-review changed inventory population.');
  const ids = new Set();
  const departments = new Set();
  const municipalityNames = new Set();
  const departmentMunicipalities = new Set();
  const geoById = new Map((geography.entries ?? []).map((entry) => [entry.cdaId, entry]));
  let addressVerified = 0;
  let geocoded = 0;
  let coordinateVerified = 0;
  let mapEligible = 0;
  let missingEvidence = 0;

  const rows = catalog.entries.map((entry) => {
    // This audit is frozen to the location-free schema; new evidence needs review.
    assert.deepEqual(Object.keys(entry).sort(), expectedFields,
      `Re-review changed fields for ID ${entry.id}; do not discard new geography.`);
    for (const key of ['id', 'name', 'municipality', 'department', 'nit']) {
      assert.equal(typeof entry[key], 'string', `${key} must retain its source text.`);
      assert.ok(entry[key].trim().length > 0, `${key} must not be blank.`);
    }
    assert.match(entry.id, /^\d+$/, 'Source ID must remain a decimal string.');
    assert.ok(!ids.has(entry.id), `Duplicate inventory ID: ${entry.id}`);
    assert.equal(entry.sourceYear, 2026, 'Re-review changed source period.');
    assert.equal(entry.sourceMonth, 7, 'Re-review changed source period.');
    ids.add(entry.id);
    departments.add(entry.department);
    municipalityNames.add(entry.municipality);
    departmentMunicipalities.add(JSON.stringify([entry.department, entry.municipality]));
    const site = geoById.get(entry.id);
    const sources = site?.locationSources ?? [];
    const hasEvidence = sources.length > 0;
    const hasAddress = typeof site?.address === 'string' && site.address.trim().length > 0;
    const hasCoordinate =
      typeof site?.latitude === 'number' && typeof site?.longitude === 'number';
    const status = site?.status ?? 'pending';
    const isAddressVerified =
      (status === 'address_verified' || status === 'geocoded' || status === 'verified') &&
      hasAddress &&
      hasEvidence;
    const isGeocoded = status === 'geocoded' && hasCoordinate && isAddressVerified;
    const isCoordinateVerified = status === 'verified' && hasCoordinate && isAddressVerified;
    if (isAddressVerified) addressVerified++;
    if (isGeocoded) geocoded++;
    if (isCoordinateVerified) coordinateVerified++;
    if (isGeocoded || isCoordinateVerified) mapEligible++;
    if (!hasEvidence) missingEvidence++;
    return [
      entry.id,
      entry.name,
      entry.municipality,
      entry.department,
      status,
      !isCoordinateVerified,
      !hasEvidence,
      catalog.source.sourceUrl,
      '2026-07',
      reviewDate,
      sources[0]?.url ?? '',
      sources[0]?.reviewedAt ?? '',
      isCoordinateVerified
        ? 'coordinate_verified'
        : isGeocoded
          ? 'geocoded_from_address'
        : isAddressVerified
          ? 'address_verified_no_coordinate'
          : 'inventory_fields_only_no_external_location_verification',
    ];
  });
  assert.equal(departments.size, 30, 'Re-review changed department population.');
  // Source ID order avoids locale-dependent sorting and preserves every source value.
  rows.sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));
  return {
    csv: [columns, ...rows].map((row) => row.map(csvCell).join(',')).join('\r\n') + '\r\n',
    summary: {
      inventoryEntries: rows.length,
      uniqueIds: ids.size,
      departments: departments.size,
      municipalityNames: municipalityNames.size,
      departmentMunicipalityPairs: departmentMunicipalities.size,
      addressVerified,
      geocoded,
      mapEligible,
      missingFromOperationalDataset: rows.length - addressVerified,
      pending: rows.length - mapEligible,
      missingLocation: rows.length - mapEligible,
      missingEvidence,
      externallyVerifiedLocations: coordinateVerified,
      inventoryFieldsCheckedOn: reviewDate,
      hardGateSatisfied:
        geography.approved === true &&
        mapEligible === addressVerified &&
        addressVerified === (geography.entries ?? []).length &&
        addressVerified > 0,
    },
  };
}

async function main() {
  const args = process.argv.slice(2);
  assert.ok(args.length === 0 || (args.length === 1 && args[0] === '--check'),
    'Usage: node mobile/tool/audit_cda_geography.mjs [--check]');
  const catalog = JSON.parse(await readFile(inventoryUrl, 'utf8'));
  const geography = JSON.parse(await readFile(geographyUrl, 'utf8'));
  const { csv, summary } = buildCoverage(catalog, geography);
  if (args[0] === '--check') {
    assert.equal(await readFile(coverageUrl, 'utf8'), csv,
      'Coverage CSV differs from the reproducible inventory audit; regenerate and review.');
  } else {
    await writeFile(coverageUrl, csv, 'utf8');
  }
  console.log(JSON.stringify({ mode: args[0] === '--check' ? 'check' : 'write', ...summary }, null, 2));
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main();
}
