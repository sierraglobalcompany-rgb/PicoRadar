'use strict';

const fs = require('fs');
const { chromium } = require('playwright');

const [baseUrl, tokenFile] = process.argv.slice(2);
const requiredEnv = (key) => {
  const value = process.env[key];
  if (!value) throw new Error(`Missing test environment: ${key}`);
  return value;
};

const token = fs.readFileSync(tokenFile, 'utf8')
  .split(/\r?\n/)
  .find((line) => /^[A-Za-z0-9_-]{40,}$/.test(line));
if (!token) throw new Error('Local installation token is unavailable.');

const basic = {
  username: requiredEnv('PICORADAR_TEST_BASIC_USER'),
  password: requiredEnv('PICORADAR_TEST_BASIC_PASSWORD'),
};
const database = {
  host: '127.0.0.1',
  port: requiredEnv('PICORADAR_TEST_DB_PORT'),
  name: requiredEnv('PICORADAR_TEST_DB_NAME'),
  user: requiredEnv('PICORADAR_TEST_DB_USER'),
  password: requiredEnv('PICORADAR_TEST_DB_PASSWORD'),
};
const operator = {
  name: 'Browser QA Owner',
  email: 'browser-owner@example.test',
  password: requiredEnv('PICORADAR_TEST_OPERATOR_PASSWORD'),
};
const evidenceDirectory = process.env.PICORADAR_BROWSER_EVIDENCE_DIR;

async function captureEvidence(page, name) {
  if (!evidenceDirectory) return;
  fs.mkdirSync(evidenceDirectory, { recursive: true });
  await page.screenshot({
    path: `${evidenceDirectory}/${name}.png`,
    fullPage: true,
  });
}

async function unlock(page) {
  await page.goto(`${baseUrl}/_setup/`);
  await page.getByLabel('Token de instalación').fill(token);
  await page.getByRole('button', { name: 'Verificar acceso' }).click();
  await page.getByText('Base de datos exclusiva y vacía').waitFor();
}

(async () => {
  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.PICORADAR_TEST_CHROMIUM || undefined,
  });
  try {
    const publicContext = await browser.newContext({ ignoreHTTPSErrors: true });
    for (const path of ['/', '/login', '/_setup/']) {
      const response = await publicContext.request.get(`${baseUrl}${path}`);
      if (response.status() !== 401) throw new Error(`Private barrier failed for ${path}.`);
    }
    await publicContext.close();

    const firstContext = await browser.newContext({ ignoreHTTPSErrors: true, httpCredentials: basic });
    const first = await firstContext.newPage();
    await first.goto(`${baseUrl}/_setup/`);
    await first.getByLabel('Token de instalación').fill('invalid-token');
    await first.getByRole('button', { name: 'Verificar acceso' }).click();
    await first.getByText('Token inválido o vencido.').waitFor();
    await first.getByLabel('Token de instalación').fill(token);
    await first.getByRole('button', { name: 'Verificar acceso' }).click();
    await first.getByText('Base de datos exclusiva y vacía').waitFor();

    const secondContext = await browser.newContext({ ignoreHTTPSErrors: true, httpCredentials: basic });
    const second = await secondContext.newPage();
    await unlock(second);

    await first.getByLabel('Host').fill(database.host);
    await first.getByLabel('Puerto').fill(database.port);
    await first.getByLabel('Base de datos').fill(database.name);
    await first.getByLabel('Usuario').fill(database.user);
    await first.getByLabel('Contraseña', { exact: true }).fill(database.password);
    await first.getByRole('button', { name: 'Probar conexión y base vacía' }).click();
    await first.getByText('Comprobación vigente.').waitFor();
    await first.getByLabel('Confirmar contraseña').fill(database.password);
    await first.getByRole('button', { name: 'Guardar configuración privada' }).click();
    await first.getByText('Crear estructura').waitFor();

    await second.reload();
    await second.getByText('Crear estructura').waitFor();
    await Promise.all([
      first.getByRole('button', { name: 'Ejecutar migraciones' }).click(),
      second.getByRole('button', { name: 'Ejecutar migraciones' }).click(),
    ]);
    await first.getByText('Primer operador').waitFor();
    await second.getByText('Primer operador').waitFor();

    await first.getByLabel('Nombre').fill(operator.name);
    await first.getByLabel('Correo').fill(operator.email);
    await first.getByLabel('Contraseña', { exact: true }).fill(operator.password);
    await first.getByLabel('Confirmación').fill(operator.password);
    await first.getByRole('button', { name: 'Crear operador' }).click();
    await first.getByText('Preparación final').waitFor();
    await first.getByRole('button', { name: 'Completar y bloquear instalador' }).click();
    await first.getByRole('heading', { name: 'Instalación completada', exact: true }).waitFor();
    await captureEvidence(first, 'installer-completed');

    const locked = await firstContext.request.get(`${baseUrl}/_setup/`);
    if (locked.status() !== 404) throw new Error('Completed installer remains reusable.');
    const health = await firstContext.request.get(`${baseUrl}/api/v1/health`);
    const healthBody = await health.json();
    if (health.status() !== 200 || healthBody.status !== 'ok') throw new Error('Health contract failed.');

    for (const path of ['/.env', '/package-manifest.json', '/picoradar_app/current/.env']) {
      const response = await firstContext.request.get(`${baseUrl}${path}`);
      if (response.status() !== 404) throw new Error(`Private path became public: ${path}.`);
    }

    await first.goto(`${baseUrl}/login`);
    await first.getByLabel('Email').fill(operator.email);
    await first.getByLabel('Password').fill(operator.password);
    await first.locator('form').evaluate((form) => form.setAttribute('action', '/login'));
    await first.getByRole('button', { name: 'Sign in' }).click();
    await first.waitForURL(/\/admin/);
    await first.getByText(/PicoRadar/i).first().waitFor();
    await captureEvidence(first, 'admin-panel');

    await secondContext.close();
    await firstContext.close();
    process.stdout.write('PASS: HTTPS browser wizard, private barrier, two sessions, login, panel, health, and private-path negatives verified.\n');
  } finally {
    await browser.close();
  }
})().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exit(1);
});
