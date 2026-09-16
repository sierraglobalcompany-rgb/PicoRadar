import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

// Input is the jointly simplified Mapshaper output, never independent regions.
const [sourcePath, simplifiedPath, outputPath] = process.argv.slice(2);
if (!outputPath) throw new Error('Usage: node prepare_department_geometry.mjs source simplified output');
const sourceBytes = fs.readFileSync(sourcePath);
const source = JSON.parse(sourceBytes);
const simplified = JSON.parse(fs.readFileSync(simplifiedPath));
const parts = feature => feature.geometry.type === 'Polygon'
  ? [feature.geometry.coordinates] : feature.geometry.coordinates;
const grouped = new Map();
for (const feature of simplified.features) {
  const code = feature.properties.dpto_ccdgo;
  if (!grouped.has(code)) grouped.set(code, []);
  grouped.get(code).push(...parts(feature));
}
if (source.features.length !== 33 || grouped.size !== 33) throw new Error('Expected 33 territories');
const features = source.features.map(feature => {
  const code = feature.properties.dpto_ccdgo;
  const original = parts(feature);
  const reduced = grouped.get(code);
  if (!reduced || original.length !== reduced.length) throw new Error(`Lost parts: ${code}`);
  const holes = list => list.reduce((sum, part) => sum + part.length - 1, 0);
  if (holes(original) !== holes(reduced)) throw new Error(`Lost holes: ${code}`);
  for (const polygon of reduced) for (const ring of polygon) {
    if (ring.length < 4 || JSON.stringify(ring[0]) !== JSON.stringify(ring.at(-1))) {
      throw new Error(`Unclosed/degenerate ring: ${code}`);
    }
    for (const point of ring) if (!point.every(Number.isFinite)) throw new Error(`Invalid coordinate: ${code}`);
  }
  return {type: 'Feature', properties: {code, name: feature.properties.dpto_cnmbr},
    geometry: {type: 'MultiPolygon', coordinates: reduced}};
});
function neighbors(input) {
  const edges = new Map(), pairs = new Set();
  for (const feature of input) {
    const code = feature.properties.code ?? feature.properties.dpto_ccdgo;
    for (const polygon of parts(feature)) for (const ring of polygon) {
      for (let i = 1; i < ring.length; i++) {
        const a = ring[i - 1].join(','), b = ring[i].join(',');
        const key = a < b ? `${a}/${b}` : `${b}/${a}`;
        const other = edges.get(key);
        if (other && other !== code) pairs.add([other, code].sort().join('-'));
        else edges.set(key, code);
      }
    }
  }
  return pairs;
}
const before = neighbors(source.features), after = neighbors(features);
for (const pair of before) if (!after.has(pair)) throw new Error(`Shared boundary lost: ${pair}`);
const result = {type: 'FeatureCollection', source: {
  name: 'Departamento Administrativo Nacional de Estadistica - DANE',
  url: 'https://geoportal.dane.gov.co/mparcgis/rest/services/Territoriales_DANE/Serv_Territoriales_DANE_2025/MapServer/1',
  year: 2025, sourceSha256: crypto.createHash('sha256').update(sourceBytes).digest('hex'),
  transformation: 'Mapshaper 0.7.61, explode, simplify dp interval=100 keep-shapes; grouped without dissolve',
}, features};
fs.mkdirSync(path.dirname(outputPath), {recursive: true});
fs.writeFileSync(outputPath, JSON.stringify(result));
console.log(JSON.stringify({territories: features.length, parts: features.reduce((s, f) => s + parts(f).length, 0),
  sharedBoundaryPairsBefore: before.size, sharedBoundaryPairsAfter: after.size,
  sourceBytes: sourceBytes.length, assetBytes: fs.statSync(outputPath).size, sourceSha256: result.source.sourceSha256}));
