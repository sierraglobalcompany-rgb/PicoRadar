"""Run using the existing audit Python: python mobile/tool/comparendos_import_test.py."""

import json
import unittest
from collections import Counter

from comparendos_import import AUDIT, ROOT, name_key


class DirectoryReconciliationTest(unittest.TestCase):
    def test_word_order_and_pdf_spacing_are_equivalent(self):
        self.assertEqual(
            name_key({'name': 'SECRETARIA MUNICIPAL DE TRANSPORTES Y TRANSITO DE CALI'}),
            name_key({'name': 'SECRETARÍA DE TRÁNSITO Y TRANSPORTE MUNICIPAL DE CALI'}),
        )
        self.assertEqual(
            name_key({'name': 'INSPECCIÓNMUNICIPALDEPOLICÍAYTRÁNSITO DE AMAGÁ'}),
            name_key({'name': 'INSPECCION MUNICIPAL DE POLICIA Y TRANSITO DE AMAGA'}),
        )

    def test_entity_type_and_department_are_not_discarded(self):
        names = [
            'SECRETARIA MUNICIPAL DE TRANSITO DE IBAGUE',
            'SECRETARIA DE TRANSITO DEL TOLIMA',
            'INSPECCION MUNICIPAL DE TRANSITO DE IBAGUE',
            'CONSORCIO TRANSITO DE IBAGUE',
        ]
        self.assertEqual(len({name_key({'name': name}) for name in names}), 4)

    def test_every_extracted_row_has_one_asset_destination(self):
        extracted = json.loads((AUDIT / 'source_rows.json').read_text(encoding='utf-8'))
        asset = json.loads((ROOT / 'mobile/assets/catalogs/comparendos_authorities_v1.json').read_text(encoding='utf-8'))
        self.assertEqual(Counter(r['sourceId'] for r in extracted), {
            'fcm_organismos': 398, 'fcm_autoridades': 308, 'runt': 297,
        })
        assigned = [r for a in asset['authorities'] for r in a['sourceRecordIds']]
        self.assertEqual(Counter(assigned), Counter(r['id'] for r in extracted))
        for source, record in zip(extracted, asset['sourceRecords'], strict=True):
            self.assertEqual(source, {k: v for k, v in record.items() if k != 'authorityId'})

    def test_no_contact_columns_leak_into_application(self):
        asset = json.loads((ROOT / 'mobile/assets/catalogs/comparendos_authorities_v1.json').read_text(encoding='utf-8'))
        allowed = {'id', 'sourceId', 'page', 'row', 'name', 'department', 'officeMunicipality', 'authorityId'}
        self.assertTrue(all(set(r) == allowed for r in asset['sourceRecords']))


if __name__ == '__main__':
    unittest.main()
