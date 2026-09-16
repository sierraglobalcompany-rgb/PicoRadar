import fs from 'node:fs/promises';
import path from 'node:path';
import { SpreadsheetFile, Workbook } from '@oai/artifact-tool';

const root = process.cwd();
const csvPath = path.join(root, 'codex', 'cda_google_manual_routes_20260914.csv');
const outputPath = path.join(root, 'codex', 'cda_google_manual_routes_20260914.xlsx');

const csv = await fs.readFile(csvPath, 'utf8');
const rows = parseCsv(csv);
if (rows.length !== 965) {
  throw new Error(`Expected header + 964 CDA rows, got ${rows.length}`);
}

const workbook = Workbook.create();
const sheet = workbook.worksheets.add('CDA rutas Google');
sheet.showGridLines = false;

const range = sheet.getRangeByIndexes(0, 0, rows.length, rows[0].length);
range.values = rows;

const header = sheet.getRangeByIndexes(0, 0, 1, rows[0].length);
header.format.fill.color = '#163653';
header.format.font.color = '#FFFFFF';
header.format.font.bold = true;
header.format.verticalAlignment = 'center';
header.format.wrapText = true;
header.format.borders = { preset: 'all', style: 'thin', color: '#FFFFFF' };

const body = sheet.getRangeByIndexes(1, 0, rows.length - 1, rows[0].length);
body.format.font.color = '#18314F';
body.format.verticalAlignment = 'center';
body.format.wrapText = false;
body.format.borders = { preset: 'insideHorizontal', style: 'thin', color: '#DDE7EF' };

sheet.freezePanes.freezeRows(1);

const widths = [14, 44, 16, 18, 20, 16, 62, 62, 58];
for (let col = 0; col < widths.length; col++) {
  sheet.getRangeByIndexes(0, col, rows.length, 1).format.columnWidth = widths[col];
}

sheet.getRangeByIndexes(0, 0, rows.length, 1).format.numberFormat = [['@']];
sheet.getRangeByIndexes(0, 2, rows.length, 1).format.numberFormat = [['@']];
sheet.getRangeByIndexes(0, 6, rows.length, 2).format.font.color = '#056E78';
sheet.getRangeByIndexes(0, 6, rows.length, 2).format.font.underline = true;
sheet.getRangeByIndexes(0, 0, rows.length, rows[0].length).format.autofitRows();

workbook.recalculate();

const inspect = await workbook.inspect({
  kind: 'table',
  sheetId: 'CDA rutas Google',
  range: 'A1:I6',
  include: 'values',
  tableMaxRows: 6,
  tableMaxCols: 9,
});
console.log(inspect.ndjson);

const errors = await workbook.inspect({
  kind: 'match',
  searchTerm: '#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!',
  options: { useRegex: true, maxResults: 50 },
  summary: 'final formula error scan',
});
console.log(errors.ndjson);

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(JSON.stringify({ outputPath, dataRows: rows.length - 1 }, null, 2));

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
  return rows;
}
