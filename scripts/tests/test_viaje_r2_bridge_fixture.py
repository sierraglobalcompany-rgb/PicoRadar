import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from viaje_r2_bridge_fixture import compiler, REPO_ROOT


class SyntheticBridgeTest(unittest.TestCase):
    def test_bridge_is_reproducible_without_external_source(self):
        approved = dict(compiler.APPROVED_SOURCE_HASHES)
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            for output in (first, second):
                process = subprocess.run(
                    [sys.executable, '-B', str(REPO_ROOT / 'scripts/tests/viaje_r2_bridge_fixture.py'),
                     '--seed-repo-root', str(REPO_ROOT), '--output-root', output],
                    capture_output=True, text=True,
                )
                self.assertEqual(process.returncode, 0, process.stderr)
            for relative in (*compiler.OUTPUT_PATHS,
                             'mobile/assets/datasets/restrictions/restrictions_v1.json'):
                self.assertEqual((Path(first) / relative).read_bytes(),
                                 (Path(second) / relative).read_bytes(), relative)
            report = json.loads((Path(first) / compiler.OUTPUT_PATHS[-1]).read_text())
            self.assertEqual(report['stagingHashesVerified'], {})
            self.assertEqual(report['inputKind'], 'NON_PRODUCTION_FIXTURE')
            self.assertEqual(report['restrictions']['newRulesPublished'], 1)
        self.assertEqual(compiler.APPROVED_SOURCE_HASHES, approved)

    def test_production_entry_rejects_synthetic_staging(self):
        with tempfile.TemporaryDirectory() as root:
            staging = Path(root) / 'data/staging'
            staging.mkdir(parents=True)
            (staging / 'MANIFEST_REVIEW.json').write_text(json.dumps({
                'runtimeImportAllowed': False, 'files': [],
            }))
            for name in compiler.APPROVED_SOURCE_HASHES:
                (staging / name).write_text('{"inputKind":"NON_PRODUCTION_FIXTURE"}')
            with self.assertRaisesRegex(ValueError, 'Unapproved staging bytes'):
                compiler.compile_release(Path(root), Path(root))


if __name__ == '__main__':
    unittest.main()
