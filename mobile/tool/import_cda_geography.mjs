#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const args = process.argv.slice(2);
const allowPartial = args.includes('--allow-partial');
const positional = args.filter((arg) => arg !== '--allow-partial');
const input = positional[0];
const output =
  positional[1] ?? 'assets/catalogs/cda_geography_v1.generated.json';

if (!input) {
  console.error(
    'Usage: node tool/import_cda_geography.mjs <authorized-csv> [output-json] [--allow-partial]',
  );
  process.exit(64);
}

const catalogPath = path.join(root, 'assets/catalogs/cda_catalog_v1.json');
const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
const latest = latestCatalogEntries(catalog.entries);
const byId = new Map(latest.map((entry) => [entry.id, entry]));
const rows = parseCsv(fs.readFileSync(input, 'utf8'));
const seen = new Set();
const entries = [];
const errors = [];

for (const [index, row] of rows.entries()) {
  const line = index + 2;
  const cdaId = required(row, 'cdaId', line, errors);
  if (!cdaId) continue;
  const catalogEntry = byId.get(cdaId);
  if (!catalogEntry) {
    errors.push(`Line ${line}: cdaId ${cdaId} is not in current catalog.`);
    continue;
  }
  if (seen.has(cdaId)) {
    errors.push(`Line ${line}: duplicate cdaId ${cdaId}.`);
    continue;
  }
  seen.add(cdaId);
  const latitude = optionalNumber(row.latitude);
  const longitude = optionalNumber(row.longitude);
  const locationSourceUrl = row.locationSourceUrl?.trim();
  const locationReviewedAt = row.locationReviewedAt?.trim();
  const contactSourceUrl = row.contactSourceUrl?.trim();
  const contactReviewedAt = row.contactReviewedAt?.trim();
  const compatibilitySourceUrl = row.compatibilitySourceUrl?.trim();
  const compatibilityReviewedAt = row.compatibilityReviewedAt?.trim();
  const address = row.address?.trim();
  const status =
    row.status?.trim() ||
    (address && validEvidence(locationSourceUrl, locationReviewedAt)
      ? 'address_verified'
      : 'pending');
  if (
    !['pending', 'address_verified', 'geocoded', 'verified', 'rejected'].includes(
      status,
    )
  ) {
    errors.push(
      `Line ${line}: status must be pending,address_verified,geocoded,verified,rejected.`,
    );
  }
  const vehicleTypes = splitList(row.vehicleTypes).filter((type) =>
    ['car', 'motorcycle'].includes(type),
  );
  if (row.vehicleTypes && vehicleTypes.length !== splitList(row.vehicleTypes).length) {
    errors.push(`Line ${line}: vehicleTypes only accepts car,motorcycle.`);
  }
  if (status === 'address_verified' || status === 'geocoded' || status === 'verified') {
    if (!address) {
      errors.push(`Line ${line}: ${status} row needs address.`);
    }
    if (!validEvidence(locationSourceUrl, locationReviewedAt)) {
      errors.push(`Line ${line}: ${status} row needs location evidence.`);
    }
  }
  if (status === 'geocoded' || status === 'verified') {
    if (!isFiniteNumber(latitude) || !isFiniteNumber(longitude)) {
      errors.push(`Line ${line}: ${status} row needs latitude and longitude.`);
    }
  }
  entries.push({
    cdaId,
    catalogName: catalogEntry.name,
    municipality: catalogEntry.municipality,
    departmentCode: catalogEntry.departmentCode,
    status,
    ...(isFiniteNumber(latitude) ? { latitude } : {}),
    ...(isFiniteNumber(longitude) ? { longitude } : {}),
    ...(address ? { address } : {}),
    ...(row.locationMethod?.trim()
      ? { locationMethod: row.locationMethod.trim() }
      : {}),
    ...(row.locationScore?.trim() ? { locationScore: Number(row.locationScore) } : {}),
    locationSources: validEvidence(locationSourceUrl, locationReviewedAt)
      ? [{ url: locationSourceUrl, reviewedAt: locationReviewedAt }]
      : [],
    vehicleTypes,
    compatibilitySources: validEvidence(
      compatibilitySourceUrl,
      compatibilityReviewedAt,
    )
      ? [{ url: compatibilitySourceUrl, reviewedAt: compatibilityReviewedAt }]
      : [],
    ...(row.phone?.trim() ? { phone: row.phone.trim() } : {}),
    ...(row.web?.trim() ? { web: row.web.trim() } : {}),
    contactSources: validEvidence(contactSourceUrl, contactReviewedAt)
      ? [{ url: contactSourceUrl, reviewedAt: contactReviewedAt }]
      : [],
  });
}

const missing = latest.filter((entry) => !seen.has(entry.id));
if (missing.length > 0 && !allowPartial) {
  errors.push(`Missing ${missing.length} current catalog IDs.`);
}
const addressVerifiedCount = entries.filter((entry) =>
  ['address_verified', 'geocoded', 'verified'].includes(entry.status),
).length;
const verifiedCount = entries.filter((entry) => entry.status === 'verified').length;
const mapEligibleCount = entries.filter((entry) =>
  ['geocoded', 'verified'].includes(entry.status),
).length;
const approved =
  entries.length > 0 && mapEligibleCount === entries.length && errors.length === 0;
const payload = {
  schemaVersion: 1,
  version: new Date().toISOString().slice(0, 10),
  catalogPeriod: `${catalog.source.latestSourceYear}-${String(
    catalog.source.latestSourceMonth,
  ).padStart(2, '0')}`,
  approved,
  entries,
};

fs.writeFileSync(path.join(root, output), `${JSON.stringify(payload, null, 2)}\n`);
console.log(
  JSON.stringify(
    {
      input,
      output,
      inventoryEntries: latest.length,
      importedRows: entries.length,
      addressVerifiedRows: addressVerifiedCount,
      verifiedRows: verifiedCount,
      mapEligibleRows: mapEligibleCount,
      missingRows: missing.length,
      allowPartial,
      approved,
      errors: errors.slice(0, 20),
      errorCount: errors.length,
    },
    null,
    2,
  ),
);
if (errors.length > 0) process.exit(65);

function latestCatalogEntries(entries) {
  const sourceYear = catalog.source.latestSourceYear;
  const sourceMonth = catalog.source.latestSourceMonth;
  return entries.filter(
    (entry) =>
      entry.sourceYear === sourceYear &&
      entry.sourceMonth === sourceMonth &&
      entry.certified === true,
  );
}

function required(row, key, line, errors) {
  const value = row[key]?.trim();
  if (!value) errors.push(`Line ${line}: missing ${key}.`);
  return value;
}

function optionalNumber(value) {
  if (value == null || value.trim() === '') return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : Number.NaN;
}

function isFiniteNumber(value) {
  return typeof value === 'number' && Number.isFinite(value);
}

function splitList(value) {
  return (value ?? '')
    .split(/[;,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function validEvidence(url, reviewedAt) {
  return Boolean(
    url &&
      /^https:\/\/[^/\s]+\.[^/\s]+/i.test(url) &&
      reviewedAt &&
      !Number.isNaN(Date.parse(reviewedAt)),
  );
}

function parseCsv(text) {
  const rows = [];
  let field = '';
  let row = [];
  let quoted = false;
  for (let index = 0; index < text.length; index++) {
    const char = text[index];
    const next = text[index + 1];
    if (quoted && char === '"' && next === '"') {
      field += '"';
      index++;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (!quoted && char === ',') {
      row.push(field);
      field = '';
    } else if (!quoted && (char === '\n' || char === '\r')) {
      if (char === '\r' && next === '\n') index++;
      row.push(field);
      if (row.some((cell) => cell.trim() !== '')) rows.push(row);
      row = [];
      field = '';
    } else {
      field += char;
    }
  }
  row.push(field);
  if (row.some((cell) => cell.trim() !== '')) rows.push(row);
  if (rows.length === 0) return [];
  const headers = rows[0].map((header) => header.trim());
  return rows.slice(1).map((cells) =>
    Object.fromEntries(headers.map((header, index) => [header, cells[index] ?? ''])),
  );
}
