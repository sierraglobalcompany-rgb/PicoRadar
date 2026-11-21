"""Synthetic tests: no real APK, Flutter SDK, device, or network required."""
from pathlib import Path
import importlib.util
import struct
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / 'android_16k_audit.py'
spec = importlib.util.spec_from_file_location('android_16k_audit', SCRIPT)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def elf64(align=16384):
    data = bytearray(120)
    data[:6] = b'\x7fELF\x02\x01'
    struct.pack_into('<Q', data, 32, 64)
    struct.pack_into('<H', data, 54, 56)
    struct.pack_into('<H', data, 56, 1)
    struct.pack_into('<IIQQQQQQ', data, 64, 1, 5, 0, 0, 0, 0, 0, align)
    return bytes(data)


def build_zip(path, aligned=True, compressed=False, is_aab=False, elf_align=16384):
    name = 'base/lib/arm64-v8a/libtest.so' if is_aab else 'lib/arm64-v8a/libtest.so'
    info = zipfile.ZipInfo(name)
    info.compress_type = zipfile.ZIP_DEFLATED if compressed else zipfile.ZIP_STORED
    if aligned and not compressed:
        extra_size = (-(30 + len(name.encode('utf-8')))) % audit.PAGE
        if extra_size < 4:
            extra_size += audit.PAGE
        info.extra = struct.pack('<HH', 0xCAFE, extra_size - 4) + b'\x00' * (extra_size - 4)
    with zipfile.ZipFile(path, 'w') as zf:
        zf.writestr(info, elf64(elf_align))


class Android16kAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)

    def path(self, name='example.apk'):
        return Path(self.temp.name) / name

    def test_aligned_stored_apk_passes_static_check(self):
        path = self.path()
        build_zip(path)
        result = audit.audit(path)
        self.assertEqual('PASS_STATIC_APK', result['status'])
        self.assertTrue(result['libraries'][0]['stored_zip_16k'])

    def test_unaligned_zip_payload_fails(self):
        path = self.path()
        build_zip(path, aligned=False)
        result = audit.audit(path)
        self.assertEqual('FAIL', result['status'])
        self.assertTrue(any('ZIP payload' in x for x in result['issues']))

    def test_four_kib_elf_fails_even_if_zip_aligned(self):
        path = self.path()
        build_zip(path, elf_align=4096)
        result = audit.audit(path)
        self.assertEqual('FAIL', result['status'])
        self.assertTrue(any('PT_LOAD' in x for x in result['issues']))

    def test_compressed_library_requires_additional_verification(self):
        path = self.path()
        build_zip(path, compressed=True)
        result = audit.audit(path)
        self.assertEqual('PENDING', result['status'])
        self.assertTrue(result['pending'])

    def test_aab_cannot_claim_full_packaging_pass(self):
        path = self.path('example.aab')
        build_zip(path, compressed=True, is_aab=True)
        result = audit.audit(path)
        self.assertEqual('PENDING', result['status'])
        self.assertIn('bundletool', str(result['pending']))

    def test_missing_or_corrupt_archive_fails_closed(self):
        path = self.path()
        path.write_bytes(b'not a zip')
        with self.assertRaises(zipfile.BadZipFile):
            audit.audit(path)

    def test_bad_elf_bounds_fails_closed(self):
        raw = bytearray(elf64())
        struct.pack_into('<Q', raw, 32, 10000)
        self.assertTrue(audit._elf_load_errors(raw))


if __name__ == '__main__':
    unittest.main()
