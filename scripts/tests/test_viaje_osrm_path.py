import json
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]


class OsrmCanonicalPathTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which('powershell'), 'Windows PowerShell required')
    def test_status_reads_canonical_metadata_with_external_tools_stubbed(self):
        script = str(ROOT / 'scripts/viaje_osrm_pilot.ps1').replace("'", "''")
        process = subprocess.run([
            'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
            "function docker { }; function Get-CimInstance { "
            "[pscustomobject]@{FreePhysicalMemory=1} }; "
            "function Test-NetConnection { $false }; "
            f"& '{script}' -Mode status"
        ], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(process.returncode, 0, process.stderr)
        metadata = json.loads((ROOT / 'data/sources/osrm/source.json').read_text(encoding='utf-8-sig'))
        self.assertIn(metadata['pbfSha256'], process.stdout)


if __name__ == '__main__':
    unittest.main()
