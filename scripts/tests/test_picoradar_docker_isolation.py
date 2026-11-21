"""Dependency-free, static guardrails for PicoRadar's one-shot QA Compose setup."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
COMPOSE = (ROOT / 'infra/docker/compose.qa.yml').read_text(encoding='utf-8')
DOCKERFILE = (ROOT / 'server/Dockerfile.qa').read_text(encoding='utf-8')
WRAPPER = (ROOT / 'scripts/run_picoradar_docker_qa.ps1').read_text(encoding='utf-8')
IGNORE = (ROOT / 'server/.dockerignore').read_text(encoding='utf-8')


class IsolationContractTests(unittest.TestCase):
    def test_unique_project_name_required(self):
        self.assertIn('name: ${PICORADAR_QA_PROJECT:?', COMPOSE)
        self.assertIn("[Guid]::NewGuid()", WRAPPER)
        self.assertIn("'--project-name', $project", WRAPPER)

    def test_never_publish_ports_or_reuse_container_names(self):
        self.assertNotRegex(COMPOSE, r'(?m)^\s*(ports|container_name|network_mode|external):')
        self.assertIn('internal: true', COMPOSE)
        self.assertIn('networks: [qa_private]', COMPOSE)

    def test_no_persistent_database_or_host_mounts(self):
        self.assertIn('/var/lib/mysql:size=536870912', COMPOSE)
        self.assertNotRegex(COMPOSE, r'(?m)^\s*(volumes|devices|privileged|pid):')
        self.assertIn('MARIADB_RANDOM_ROOT_PASSWORD', COMPOSE)
        self.assertIn('PICORADAR_QA_DB_PASSWORD:?', COMPOSE)

    def test_php_is_copied_inside_image_and_synthetic(self):
        self.assertIn('COPY . .', DOCKERFILE)
        self.assertIn('pdo_mysql pdo_sqlite', DOCKERFILE)
        for toggle in ['CAMPAIGN_PUBLIC_CATALOG_ENABLED', 'PARTNER_INQUIRIES_ENABLED',
                       'PICORADAR_ACCOUNTS_ENABLED', 'PICORADAR_MARKETING_SEND_ENABLED']:
            self.assertRegex(COMPOSE, rf'{toggle}: .false.')

    def test_secrets_and_mutable_files_excluded_from_build(self):
        for pattern in ('.env', '.env.*', 'vendor', 'node_modules', 'database/*.sqlite', 'public/storage'):
            self.assertIn(pattern, IGNORE)
        self.assertIn('!.env.example', IGNORE)
        self.assertIn('function New-HexSecret', WRAPPER)
        self.assertIn('function New-AppKey', WRAPPER)
        self.assertIn('$env:PICORADAR_QA_DB_PASSWORD = New-HexSecret', WRAPPER)
        self.assertIn('$env:PICORADAR_QA_APP_KEY = New-AppKey', WRAPPER)
        self.assertNotIn('--env-file', WRAPPER)

    def test_clean_checkout_and_scoped_operations_only(self):
        self.assertIn('git -C $repo status --porcelain', WRAPPER)
        self.assertIn("@('build', 'app')", WRAPPER)
        self.assertIn('docker @composeArgs down', WRAPPER)
        self.assertNotRegex(WRAPPER, r'(?im)^\s*&?\s*docker\s+system\s+prune')
        self.assertNotRegex(WRAPPER, r'(?i)docker\s+compose\s+down\s+-v\b')

    def test_generated_qa_env_is_process_scoped_and_restored(self):
        self.assertIn("[Environment]::GetEnvironmentVariable($qaName, 'Process')", WRAPPER)
        self.assertIn("[Environment]::SetEnvironmentVariable($qaName, $qaEnvBefore[$qaName], 'Process')", WRAPPER)
        self.assertIn("$env:PICORADAR_QA_PROJECT = $project", WRAPPER)
        self.assertNotIn('$envFile', WRAPPER)
        self.assertNotIn('WriteAllText', WRAPPER)

    def test_focused_tests_and_migrations_are_distinct(self):
        self.assertIn("[ValidateSet('schema', 'test')]", WRAPPER)
        self.assertIn("'migrate', '--force'", WRAPPER)
        self.assertIn("'test', '--filter', $Filter", WRAPPER)
        self.assertIn('No MariaDB service is started in the focused test mode.', WRAPPER)
        self.assertIn("'up', '-d', '--wait', 'db'", WRAPPER)

    def test_phpunit_sqlite_not_overridden_by_compose_mariadb(self):
        # PHPunit.xml env entries are not forced; container variables win.
        # Thus focused test mode must override the Compose service DB env.
        self.assertIn("'-e', 'DB_CONNECTION=sqlite'", WRAPPER)
        self.assertIn("'-e', 'DB_DATABASE=:memory:'", WRAPPER)
        self.assertIn("'-e', 'DB_URL='", WRAPPER)
        self.assertRegex(WRAPPER, r"(?s)@\('run', '--rm', '--no-deps',.*?'DB_CONNECTION=sqlite'.*?'app', 'php', 'artisan', 'test'")


if __name__ == '__main__':
    unittest.main()
