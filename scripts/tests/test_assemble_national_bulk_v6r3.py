import copy
import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'qa' / 'assemble_national_bulk_v6r3.py'
spec = importlib.util.spec_from_file_location('national_lab_assembler', SCRIPT)
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)


def write_json(path, value):
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8',
        newline='\n',
    )


def synthetic_jurisdiction():
    source_url = 'https://example.gov.co/restrictions'
    return {
        'schemaVersion': 2,
        'id': 'co-test-example',
        'name': 'Municipio sintético QA',
        'municipalityCodes': ['99999'],
        'consultationEnabled': True,
        'coverages': [
            {
                'vehicleKind': 'car',
                'serviceType': 'private',
                'coverageCompleteness': 'partial',
                'verifiedAt': '2026-11-13T09:00:00-05:00',
                'staleAfter': '2026-11-19T23:59:59-05:00',
                'sourceUrls': [source_url],
                'rules': [
                    {
                        'id': 'test-car-mon',
                        'priority': 100,
                        'effect': 'restrict',
                        'validFrom': '2026-11-13T00:00:00-05:00',
                        'weekdays': [1],
                        'digitPosition': 'lastNumeric',
                        'digits': [1],
                        'timeWindows': [{'startMinute': 360, 'endMinute': 1200}],
                        'appliesOnHolidays': False,
                        'sourceUrl': source_url,
                        'verifiedAt': '2026-11-13T09:00:00-05:00',
                        'conditions': [
                            {
                                'type': 'inside_scope_ref',
                                'value': 'synthetic-scope-unverified@qa-v1',
                            },
                        ],
                    },
                ],
            },
        ],
    }


def synthetic_manifest(source_file, source_hash, enabled=True):
    return {
        'schemaVersion': 1,
        'release': {
            'version': 'LAB-SYNTHETIC-20261113',
            'generatedAt': '2026-11-13T10:00:00-05:00',
            'outputFile': 'synthetic-snapshot.json',
            'shaFile': 'synthetic-snapshot.sha256',
        },
        'sources': [
            {
                'jurisdictionId': 'co-test-example',
                'file': source_file,
                'enabled': enabled,
                'expectedSha256': source_hash,
                'provenance': 'Fixture sintético temporal para demostrar el contrato declarativo.',
                'editorialDate': '2026-11-13',
            },
        ],
    }


class NationalBulkAssemblerTest(unittest.TestCase):
    def jurisdictions(self):
        payload, details = qa.build()
        return json.loads(payload)['jurisdictions'], details

    def test_deterministic_snapshot_preserves_v5_and_adds_dosquebradas(self):
        payload, details = qa.build()
        self.assertEqual(
            {key: details[key] for key in ('jurisdictions', 'enabledMunicipalityCodes', 'coverages', 'rules')},
            {'jurisdictions': 14, 'enabledMunicipalityCodes': 33, 'coverages': 21, 'rules': 115},
        )
        self.assertEqual(payload, qa.lab_path(qa.LAB, details['outputFile'], 'output').read_bytes())
        manifest = json.loads(qa.DEFAULT_MANIFEST.read_text(encoding='utf-8'))
        sources = {item['jurisdictionId']: item for item in manifest['sources']}
        self.assertEqual(
            sources['co-vac-cali']['expectedSha256'],
            '84d5ae34ba45bb1258b259f504fe580d69b0ac2ada6a26eb53a31f7726893b99',
        )
        self.assertEqual(
            sources['co-ris-pereira']['expectedSha256'],
            '4719aedccf73c758647addd59380d040111172c841a5be2ec85848812312ba12',
        )

    def test_dosquebradas_is_partial_and_uses_its_own_schedule(self):
        jurisdictions, details = self.jurisdictions()
        row = next(item for item in jurisdictions if item['id'] == 'co-ris-dosquebradas')
        self.assertEqual(row['municipalityCodes'], ['66170'])
        self.assertTrue(row['consultationEnabled'])
        self.assertEqual(details['coverages'], 21)
        self.assertEqual(len(row['coverages']), 2)
        expected_digits = [[0, 1], [2, 3], [4, 5], [6, 7], [8, 9]]
        for coverage in row['coverages']:
            self.assertEqual(coverage['coverageCompleteness'], 'partial')
            self.assertEqual(len(coverage['rules']), 5)
            self.assertEqual([rule['weekdays'] for rule in coverage['rules']], [[1], [2], [3], [4], [5]])
            self.assertEqual([rule['digits'] for rule in coverage['rules']], expected_digits)
            self.assertTrue(all(rule['appliesOnHolidays'] for rule in coverage['rules']))
            self.assertTrue(all(rule['validFrom'] == '2026-09-28T00:00:00-05:00' for rule in coverage['rules']))
            self.assertTrue(all('validUntil' not in rule for rule in coverage['rules']))
            self.assertTrue(all(rule['timeWindows'] == [{'startMinute': 360, 'endMinute': 1200}] for rule in coverage['rules']))
            self.assertTrue(all(
                {'type': 'inside_scope_ref', 'value': 'dosquebradas-current-road-scope-unverified@2026-retorno'}
                in rule['conditions']
                for rule in coverage['rules']
            ))
        self.assertEqual(
            {item['vehicleKind']: item['rules'][0]['digitPosition'] for item in row['coverages']},
            {'car': 'lastNumeric', 'motorcycle': 'firstNumeric'},
        )

    def test_rejects_unknown_schema_key(self):
        jurisdictions, _ = self.jurisdictions()
        bad = copy.deepcopy(jurisdictions[0])
        bad['unrecognized'] = True
        with self.assertRaisesRegex(ValueError, 'Unsupported jurisdiction key'):
            qa.validate_jurisdiction(bad, {}, set())

    def test_rejects_rule_date_without_timezone(self):
        jurisdictions, _ = self.jurisdictions()
        bad = copy.deepcopy(jurisdictions[0])
        bad['coverages'][0]['rules'][0]['validFrom'] = bad['coverages'][0]['rules'][0]['validFrom'][:19]
        with self.assertRaisesRegex(ValueError, 'validFrom .* explicit timezone'):
            qa.validate_jurisdiction(bad, {}, set())

    def test_rejects_duplicate_rule_id(self):
        jurisdictions, _ = self.jurisdictions()
        bad = copy.deepcopy(jurisdictions[0])
        cov = next(c for c in bad['coverages'] if len(c['rules']) > 1)
        cov['rules'][1]['id'] = cov['rules'][0]['id']
        with self.assertRaisesRegex(ValueError, 'duplicate global rule id'):
            qa.validate_jurisdiction(bad, {}, set())

    def test_rejects_duplicate_semantic_rule(self):
        jurisdictions, _ = self.jurisdictions()
        bad = copy.deepcopy(jurisdictions[0])
        cov = next(c for c in bad['coverages'] if len(c['rules']) > 1)
        duplicate = copy.deepcopy(cov['rules'][0])
        duplicate['id'] += '-duplicate'
        cov['rules'].append(duplicate)
        with self.assertRaisesRegex(ValueError, 'Duplicate semantic rule'):
            qa.validate_jurisdiction(bad, {}, set())

    def test_rejects_duplicate_vehicle_service_pair(self):
        jurisdictions, _ = self.jurisdictions()
        bad = copy.deepcopy(jurisdictions[0])
        bad['coverages'].append(copy.deepcopy(bad['coverages'][0]))
        with self.assertRaisesRegex(ValueError, 'Duplicate vehicle/service coverage'):
            qa.validate_jurisdiction(bad, {}, set())

    def test_rejects_enabled_divipola_collision(self):
        jurisdictions, _ = self.jurisdictions()
        seen_codes, seen_rules, seen_signatures = {}, set(), set()
        first = copy.deepcopy(jurisdictions[0])
        second = copy.deepcopy(jurisdictions[1])
        second['municipalityCodes'] = first['municipalityCodes']
        qa.validate_jurisdiction(first, seen_codes, seen_rules, seen_signatures)
        with self.assertRaisesRegex(ValueError, 'Enabled DIVIPOLA collision'):
            qa.validate_jurisdiction(second, seen_codes, seen_rules, seen_signatures)

    def test_rejects_partial_rule_without_spatial_scope(self):
        jurisdictions, _ = self.jurisdictions()
        bad = copy.deepcopy(jurisdictions[0])
        bad['coverages'][0]['rules'][0].pop('conditions')
        with self.assertRaisesRegex(ValueError, 'lacks unresolved spatial scope'):
            qa.validate_jurisdiction(bad, {}, set())

    def test_rejects_expiry_without_timezone(self):
        with self.assertRaisesRegex(ValueError, 'expiresAt must be ISO-8601'):
            qa.validate_expires_at({'expiresAt': '2026-12-01T00:00:00'})

    def test_new_source_is_manifest_only_and_disabling_omits_it(self):
        with tempfile.TemporaryDirectory(prefix='picoradar-manifest-qa-') as directory:
            root = Path(directory)
            source_path = root / 'synthetic.json'
            write_json(source_path, synthetic_jurisdiction())
            source_hash = hashlib.sha256(source_path.read_bytes()).hexdigest()
            manifest_path = root / 'manifest.json'
            manifest = synthetic_manifest(source_path.name, source_hash)
            write_json(manifest_path, manifest)

            enabled_bytes, enabled_details = qa.build(manifest_path)
            enabled = json.loads(enabled_bytes)
            self.assertEqual(enabled_details['jurisdictions'], 1)
            self.assertEqual(enabled['jurisdictions'][0]['id'], 'co-test-example')

            manifest['sources'][0]['enabled'] = False
            write_json(manifest_path, manifest)
            disabled_bytes, disabled_details = qa.build(manifest_path)
            disabled = json.loads(disabled_bytes)
            self.assertEqual(disabled_details['jurisdictions'], 0)
            self.assertEqual(disabled_details['disabledSources'], 1)
            self.assertEqual(disabled['jurisdictions'], [])
            self.assertNotEqual(enabled_bytes, disabled_bytes)

    def test_rejects_manifest_path_traversal(self):
        with tempfile.TemporaryDirectory(prefix='picoradar-manifest-qa-') as directory:
            root = Path(directory)
            source = root / 'synthetic.json'
            write_json(source, synthetic_jurisdiction())
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            manifest_path = root / 'manifest.json'
            manifest = synthetic_manifest('../synthetic.json', digest)
            write_json(manifest_path, manifest)
            with self.assertRaisesRegex(ValueError, 'cannot traverse outside LAB'):
                qa.build(manifest_path)

    def test_rejects_duplicate_manifest_id_and_wrong_sha(self):
        with tempfile.TemporaryDirectory(prefix='picoradar-manifest-qa-') as directory:
            root = Path(directory)
            source = root / 'synthetic.json'
            write_json(source, synthetic_jurisdiction())
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            manifest_path = root / 'manifest.json'
            manifest = synthetic_manifest(source.name, digest)
            duplicate_id = copy.deepcopy(manifest['sources'][0])
            duplicate_id['file'] = 'synthetic-copy.json'
            manifest['sources'].append(duplicate_id)
            write_json(manifest_path, manifest)
            with self.assertRaisesRegex(ValueError, 'Duplicate source jurisdictionId'):
                qa.build(manifest_path)

            manifest['sources'] = [manifest['sources'][0]]
            manifest['sources'][0]['expectedSha256'] = '0' * 64
            write_json(manifest_path, manifest)
            with self.assertRaisesRegex(ValueError, 'Source SHA-256 mismatch'):
                qa.build(manifest_path)

    def test_rejects_generated_at_before_verified_source(self):
        with tempfile.TemporaryDirectory(prefix='picoradar-manifest-qa-') as directory:
            root = Path(directory)
            source = root / 'synthetic.json'
            write_json(source, synthetic_jurisdiction())
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            manifest_path = root / 'manifest.json'
            manifest = synthetic_manifest(source.name, digest)
            manifest['release']['generatedAt'] = '2026-11-13T08:00:00-05:00'
            write_json(manifest_path, manifest)
            with self.assertRaisesRegex(ValueError, 'earlier than the latest enabled source verifiedAt'):
                qa.build(manifest_path)

    def test_schema2_accepts_only_explicit_full_day_marker_for_equal_minutes(self):
        payload = synthetic_jurisdiction()
        rule = payload['coverages'][0]['rules'][0]
        rule['timeWindows'] = [{'startMinute': 360, 'endMinute': 360, 'fullDay': True}]

        self.assertEqual(qa.validate_jurisdiction(payload, {}, set()), (1, 1))

        complete = copy.deepcopy(payload)
        complete['coverages'][0]['coverageCompleteness'] = 'complete'
        with self.assertRaisesRegex(ValueError, 'must remain partial'):
            qa.validate_jurisdiction(complete, {}, set())

        invalid_windows = [
            {'startMinute': 360, 'endMinute': 360},
            {'startMinute': 360, 'endMinute': 360, 'fullDay': False},
            {'startMinute': 360, 'endMinute': 360, 'fullDay': None},
            {'startMinute': 360, 'endMinute': 360, 'fullDay': 'true'},
            {'startMinute': 360, 'endMinute': 360, 'fullDay': 1},
            {'startMinute': 360, 'endMinute': 420, 'fullDay': True},
            {'startMinute': 1440, 'endMinute': 1440, 'fullDay': True},
        ]
        for window in invalid_windows:
            with self.subTest(window=window):
                invalid = copy.deepcopy(payload)
                invalid['coverages'][0]['rules'][0]['timeWindows'] = [window]
                with self.assertRaisesRegex(ValueError, 'time window'):
                    qa.validate_jurisdiction(invalid, {}, set())

    def test_schema1_source_with_full_day_marker_is_rejected(self):
        payload = synthetic_jurisdiction()
        payload['schemaVersion'] = 1
        payload['coverages'][0]['rules'][0]['timeWindows'] = [
            {'startMinute': 360, 'endMinute': 360, 'fullDay': True}
        ]

        with self.assertRaisesRegex(ValueError, 'schema2'):
            qa.validate_jurisdiction(payload, {}, set())


if __name__ == '__main__':
    unittest.main()
