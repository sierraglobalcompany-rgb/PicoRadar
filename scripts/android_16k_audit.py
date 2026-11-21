#!/usr/bin/env python3
"""Read-only, offline APK/AAB native-library 16 KiB alignment preflight.

Does not sign, rebuild, install, or upload the artifact. AAB packaging requires
separate bundletool dump config verification; device QA is never implied.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct
import sys
import zipfile

PAGE = 16 * 1024
ELF64_PHDR = struct.Struct('<IIQQQQQQ')
ELF32_PHDR = struct.Struct('<IIIIIIII')
MAX_LIB_BYTES = 128 * 1024 * 1024


def _elf_load_errors(raw: bytes) -> list[str]:
    """Check little-endian ELF PT_LOAD p_align and p_offset/vaddr congruence."""
    if len(raw) < 64 or raw[:4] != b'\x7fELF':
        return ['not an ELF shared object']
    elf_class, encoding = raw[4], raw[5]
    if encoding != 1 or elf_class not in (1, 2):
        return ['unsupported ELF byte order or class']
    if elf_class == 2:
        header_bytes = 64
        phoff, = struct.unpack_from('<Q', raw, 32)
        entsize, phnum = struct.unpack_from('<HH', raw, 54)
        phdr, min_size = ELF64_PHDR, ELF64_PHDR.size
    else:
        header_bytes = 52
        phoff, = struct.unpack_from('<I', raw, 28)
        entsize, phnum = struct.unpack_from('<HH', raw, 42)
        phdr, min_size = ELF32_PHDR, ELF32_PHDR.size
    if len(raw) < header_bytes or phnum == 0 or phnum == 0xffff or entsize < min_size:
        return ['invalid or extended ELF program header table']
    if phoff > len(raw) or phnum * entsize > len(raw) - phoff:
        return ['ELF program headers exceed file bounds']
    found = False
    errors = []
    for index in range(phnum):
        values = phdr.unpack_from(raw, phoff + index * entsize)
        if values[0] != 1:  # PT_LOAD
            continue
        found = True
        if elf_class == 2:
            offset, vaddr, align = values[2], values[3], values[7]
        else:
            offset, vaddr, align = values[1], values[2], values[7]
        if align < PAGE or (offset - vaddr) % PAGE:
            errors.append(f'PT_LOAD[{index}]: p_align={align}, offset={offset}, vaddr={vaddr}')
    if not found:
        errors.append('ELF contains no PT_LOAD segments')
    return errors


def _data_offset(archive, info: zipfile.ZipInfo) -> int:
    """Use the local header (not central-directory metadata) to find payload."""
    archive.fp.seek(info.header_offset)
    header = archive.fp.read(30)
    if len(header) != 30 or header[:4] != b'PK\x03\x04':
        raise ValueError('invalid local ZIP header')
    name_len, extra_len = struct.unpack_from('<HH', header, 26)
    return info.header_offset + 30 + name_len + extra_len


def audit(path: Path) -> dict:
    """FAIL != PENDING. Neither means release was verified."""
    if path.suffix.lower() not in ('.apk', '.aab'):
        raise ValueError('Expected a local .apk or .aab file')
    is_apk = path.suffix.lower() == '.apk'
    issues: list[str] = []
    libraries = []
    pending = []
    with zipfile.ZipFile(path, 'r') as zf:
        for info in zf.infolist():
            name = info.filename
            segments = name.split('/')
            if info.is_dir() or not name.endswith('.so'):
                continue
            apk_lib = len(segments) == 3 and segments[0] == 'lib'
            aab_lib = len(segments) == 4 and segments[1] == 'lib'
            if not (apk_lib if is_apk else aab_lib):
                continue
            if info.file_size > MAX_LIB_BYTES:
                issues.append(f'{name}: native library exceeds safety bound')
                continue
            try:
                raw = zf.read(info)
            except (ValueError, RuntimeError, zipfile.BadZipFile) as error:
                issues.append(f'{name}: archive entry cannot be read ({type(error).__name__})')
                continue
            elf_errors = _elf_load_errors(raw)
            issues.extend(f'{name}: {msg}' for msg in elf_errors)
            compressed = info.compress_type != zipfile.ZIP_STORED
            zip_aligned = None
            if is_apk and not compressed:
                try:
                    zip_aligned = _data_offset(zf, info) % PAGE == 0
                except ValueError as error:
                    issues.append(f'{name}: {error}')
                if zip_aligned is False:
                    issues.append(f'{name}: uncompressed ZIP payload is not 16 KiB aligned')
            if is_apk and compressed:
                pending.append(f'{name}: compressed; verify extractNativeLibs and installation behavior')
            libraries.append({'name': name, 'elf_16k': not elf_errors, 'stored_zip_16k': zip_aligned})
    if not libraries and not issues:
        pending.append('No native .so files found; confirm artifact and runtime scope')
    if not is_apk:
        pending.append('AAB: check bundletool dump config for PAGE_ALIGNMENT_16K and generated APKs')
    status = 'FAIL' if issues else 'PENDING' if pending else 'PASS_STATIC_APK'
    return {'artifact_type': 'APK' if is_apk else 'AAB', 'status': status,
            'native_library_count': len(libraries), 'libraries': libraries,
            'issues': issues, 'pending': pending,
            'limits': 'Static alignment only; does not certify device QA, Play upload or signing'}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artifact', type=Path, help='Local APK/AAB path; never uploaded')
    args = parser.parse_args()
    try:
        report = audit(args.artifact)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        report = {'status': 'FAIL', 'issues': [f'Cannot audit artifact: {error}']}
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return {'PASS_STATIC_APK': 0, 'FAIL': 1, 'PENDING': 2}[report['status']]


if __name__ == '__main__':
    sys.exit(main())
