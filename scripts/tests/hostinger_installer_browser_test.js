'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');
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
const scenario = process.env.PICORADAR_TEST_SCENARIO || 'happy';
const privateRoot = requiredEnv('PICORADAR_TEST_PRIVATE_ROOT');
const statePath = requiredEnv('PICORADAR_TEST_STATE_PATH');
const mutationLockPath = requiredEnv('PICORADAR_TEST_MUTATION_LOCK_PATH');

async function exerciseAdminContent(page, context) {
  const fixtures = {
    json: requiredEnv('PICORADAR_TEST_RULES_JSON'),
    csv: requiredEnv('PICORADAR_TEST_RULES_CSV'),
    xlsx: requiredEnv('PICORADAR_TEST_RULES_XLSX'),
  };
  for (const [format, filePath] of Object.entries(fixtures)) {
    await page.goto(`${baseUrl}/admin/restrictions/import`);
    await page.getByLabel('Archivo JSON, CSV o XLSX').setInputFiles(filePath);
    if (format === 'xlsx') {
      await page.getByLabel('Hoja XLSX (opcional)').fill('Rules');
    }
    await page.getByRole('button', { name: 'Analizar' }).click();
    await page.getByText('Medellín').waitFor();
    await page.getByText(/1 filas/).waitFor();
  }

  await page.getByRole('button', { name: 'Crear borradores seleccionados' }).click();
  await page.getByRole('heading', { name: 'Reglas por ciudad' }).waitFor();
  const medellinRow = page.locator('tr', { hasText: 'Medellín' });
  await medellinRow.getByRole('link', { name: 'Abrir' }).click();
  await page.getByRole('button', { name: 'Validar' }).click();
  await page.goto(`${baseUrl}/admin/restrictions`);
  await page.getByLabel('Publicar Medellín').check();
  await page.getByRole('button', { name: 'Revisar selección' }).click();
  await page.getByRole('heading', { name: 'Revisar publicación selectiva' }).waitFor();
  await page.getByRole('button', { name: 'Publicar ciudades seleccionadas' }).click();
  await page.getByRole('heading', { name: 'Historial de publicaciones' }).waitFor();

  const datasetManifestResponse = await context.request.get(`${baseUrl}/v1/manifest.json`);
  if (datasetManifestResponse.status() !== 200) throw new Error('Dataset manifest was not published.');
  const datasetManifest = await datasetManifestResponse.json();
  const restrictionEntry = datasetManifest.datasets?.restrictions;
  if (!restrictionEntry || !String(restrictionEntry.url).startsWith(`${baseUrl}/storage/`)) {
    throw new Error(`Restriction manifest is not consumable by mobile: ${JSON.stringify(restrictionEntry)}`);
  }

  await page.goto(`${baseUrl}/admin/sponsors/create`);
  await page.getByLabel('Nombre').fill('Patrocinador B07 sintético');
  await page.getByLabel('Contacto privado').fill('Contacto de prueba');
  await page.getByLabel('Correo privado').fill('partner-b07@example.test');
  await page.getByRole('button', { name: 'Guardar', exact: true }).click();
  await page.getByRole('heading', { name: 'Patrocinador B07 sintético' }).waitFor();

  await page.goto(`${baseUrl}/admin/campaigns/create`);
  await page.getByLabel('Patrocinador').selectOption({ label: 'Patrocinador B07 sintético' });
  await page.getByLabel('Etiqueta').fill('DEMOSTRACIÓN LOCAL');
  await page.getByLabel('Titulo').fill('Aliado B07 sintético');
  await page.getByLabel('Subtitulo').fill('Campaña publicada desde el panel local aislado.');
  await page.getByLabel('Texto CTA').fill('Ver demostración');
  await page.getByLabel('Destino HTTPS').fill('https://example.test/b07');
  await page.getByLabel('Prioridad').fill('10');
  await page.getByLabel('Alcance').selectOption('national');
  await page.getByLabel('Inicio').fill('2026-09-20T00:00');
  await page.getByLabel('Fin').fill('2026-12-31T23:59');
  await page.getByLabel(/Imagen C11/).setInputFiles(requiredEnv('PICORADAR_TEST_CAMPAIGN_IMAGE'));
  await page.getByRole('button', { name: 'Guardar borrador' }).click();
  await page.getByRole('heading', { name: 'Aliado B07 sintético' }).waitFor();
  await page.getByRole('button', { name: 'Activar' }).click();
  await page.getByText('Campana activada y catalogo publicado.').waitFor();

  const campaignManifestResponse = await context.request.get(`${baseUrl}/storage/campaigns/v1/catalog.json`);
  if (campaignManifestResponse.status() !== 200) throw new Error('Campaign manifest was not published.');
  const campaignManifest = await campaignManifestResponse.json();
  if (!String(campaignManifest.url).startsWith(`${baseUrl}/storage/`)) {
    throw new Error(`Campaign manifest is not consumable by mobile: ${JSON.stringify(campaignManifest)}`);
  }
  const campaignCatalogResponse = await context.request.get(campaignManifest.url);
  const campaignCatalog = await campaignCatalogResponse.json();
  if (!campaignCatalog.campaigns?.some((campaign) => campaign.title === 'Aliado B07 sintético')) {
    throw new Error('The activated campaign did not reach the published catalog.');
  }
  await captureEvidence(page, 'admin-campaign-active');
  process.stdout.write('PASS: browser imported JSON/CSV/XLSX and published restrictions plus a C11 campaign.\n');
}

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function waitForFile(filePath, timeoutMilliseconds = 5000) {
  const deadline = Date.now() + timeoutMilliseconds;
  while (Date.now() < deadline) {
    if (fs.existsSync(filePath)) return;
    await sleep(25);
  }
  throw new Error(`Timed out waiting for ${filePath}.`);
}

function waitForProcess(child) {
  return new Promise((resolve, reject) => {
    let stderr = '';
    child.stderr?.on('data', (chunk) => { stderr += chunk.toString(); });
    child.once('error', reject);
    child.once('exit', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`Lock helper failed (${code}): ${stderr.trim()}`));
    });
  });
}

async function holdInstallerLock(seconds) {
  const readyPath = path.join(os.tmpdir(), `picoradar-lock-ready-${process.pid}-${Date.now()}`);
  const child = spawn(requiredEnv('PICORADAR_TEST_PHP'), [
    requiredEnv('PICORADAR_TEST_HOLD_LOCK_SCRIPT'),
    mutationLockPath,
    readyPath,
    String(seconds),
  ], { stdio: ['ignore', 'ignore', 'pipe'] });
  await waitForFile(readyPath);
  fs.rmSync(readyPath, { force: true });
  return { child, completion: waitForProcess(child) };
}

async function captureEvidence(page, name) {
  if (!evidenceDirectory) return;
  fs.mkdirSync(evidenceDirectory, { recursive: true });
  await page.locator('body').screenshot({
    path: `${evidenceDirectory}/${name}.png`,
    animations: 'disabled',
    timeout: 15000,
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

    if (scenario === 'migration-failure') {
      const environmentPath = path.join(privateRoot, '.env');
      const environment = fs.readFileSync(environmentPath, 'utf8');
      fs.writeFileSync(
        environmentPath,
        environment.replace(/^DB_PASSWORD=.*$/m, 'DB_PASSWORD=invalid-migration-password'),
        'utf8',
      );
      await first.getByRole('button', { name: 'Ejecutar migraciones' }).click();
      await first.getByText('La migración falló.').waitFor();
      const failedState = JSON.parse(fs.readFileSync(statePath, 'utf8'));
      if (failedState.stage !== 'failed'
          || failedState.retryStage !== 'new'
          || failedState.errorCode !== 'migration_failed') {
        throw new Error('A real migration failure was not recorded while the request owned the lock.');
      }
      process.stdout.write('PASS: a real migration failure under the owned lock is recorded for a fresh database retry.\n');
      await secondContext.close();
      await firstContext.close();
      return;
    }

    await second.reload();
    await second.getByText('Crear estructura').waitFor();

    const stateBeforeContention = fs.readFileSync(statePath);
    const heldLock = await holdInstallerLock(8);
    if (heldLock.child.exitCode !== null) {
      throw new Error('The contention helper exited before the installer request started.');
    }
    await second.getByRole('button', { name: 'Ejecutar migraciones' }).click();
    await second.getByText('Hay otra operación de instalación en curso.').waitFor();
    const stateAfterContention = fs.readFileSync(statePath);
    if (!stateBeforeContention.equals(stateAfterContention)) {
      throw new Error('A request without the mutation lock changed installation state.');
    }
    await heldLock.completion;

    await first.reload();
    await second.reload();
    await first.getByText('Crear estructura').waitFor();
    await second.getByText('Crear estructura').waitFor();
    await Promise.all([
      first.getByRole('button', { name: 'Ejecutar migraciones' }).click(),
      second.getByRole('button', { name: 'Ejecutar migraciones' }).click(),
    ]);
    const migratedState = JSON.parse(fs.readFileSync(statePath, 'utf8'));
    if (migratedState.stage !== 'migrated' || migratedState.errorCode !== null) {
      throw new Error('Concurrent migration requests did not converge on the migrated stage.');
    }
    await first.getByText('Primer operador').waitFor();
    await second.getByText('Primer operador').waitFor();

    await first.getByLabel('Nombre').fill(operator.name);
    await first.getByLabel('Correo').fill(operator.email);
    await first.getByLabel('Contraseña', { exact: true }).fill(operator.password);
    await first.getByLabel('Confirmación').fill(operator.password);
    await first.getByRole('button', { name: 'Crear operador' }).click();
    await first.getByText('Preparación final').waitFor();
    await second.reload();
    await second.getByText('Preparación final').waitFor();
    await Promise.all([
      first.getByRole('button', { name: 'Completar y bloquear instalador' }).click(),
      second.getByRole('button', { name: 'Completar y bloquear instalador' }).click(),
    ]);
    let completedPage = null;
    for (const page of [first, second]) {
      if (await page.getByRole('heading', { name: 'Instalación completada', exact: true }).isVisible().catch(() => false)) {
        completedPage = page;
        break;
      }
    }
    if (!completedPage) throw new Error('Concurrent finalization did not render a completed result.');
    const completedState = JSON.parse(fs.readFileSync(statePath, 'utf8'));
    if (completedState.stage !== 'completed' || completedState.errorCode !== null) {
      throw new Error('Concurrent finalization requests did not converge on the completed stage.');
    }
    await captureEvidence(completedPage, 'installer-completed');

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
    const loginAction = await first.locator('form').getAttribute('action');
    if (new URL(loginAction, baseUrl).origin !== new URL(baseUrl).origin) {
      throw new Error(`Login form action escaped the isolated origin: ${loginAction}`);
    }
    await first.getByRole('button', { name: 'Sign in' }).click();
    try {
      await first.getByText('Operator dashboard').waitFor({ timeout: 15000 });
      if (!new URL(first.url()).pathname.startsWith('/admin')) {
        throw new Error(`Unexpected authenticated path: ${first.url()}`);
      }
    } catch {
      const body = (await first.locator('body').innerText()).replace(/\s+/g, ' ').slice(0, 500);
      throw new Error(`Login did not reach the admin panel. URL=${first.url()} BODY=${body}`);
    }
    await first.getByText(/PicoRadar/i).first().waitFor();
    await captureEvidence(first, 'admin-panel');
    if (scenario === 'admin-content') {
      await exerciseAdminContent(first, firstContext);
    }
    await first.getByRole('button', { name: 'Log out' }).click({ force: true });
    await first.getByRole('button', { name: 'Sign in' }).waitFor();
    if (new URL(first.url()).pathname !== '/login') {
      throw new Error(`Logout did not return to login: ${first.url()}`);
    }

    await secondContext.close();
    await firstContext.close();
    process.stdout.write('PASS: HTTPS browser wizard, private barrier, two sessions, login, panel, health, and private-path negatives verified.\n');
  } finally {
    await browser.close();
  }
})().catch((error) => {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exit(1);
});
