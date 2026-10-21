#!/usr/bin/env python3
from __future__ import annotations

import shutil
import sys
import zipfile
from pathlib import Path, PurePosixPath


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify_hostinger_zip_linux.py <zip> <output>")

    archive_path = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)

    with zipfile.ZipFile(archive_path) as archive:
        names = [entry.filename for entry in archive.infolist()]
        if not names or len(names) != len(set(names)):
            raise RuntimeError("ZIP entries are empty or duplicated")
        for name in names:
            path = PurePosixPath(name)
            if "\\" in name or path.is_absolute() or ".." in path.parts:
                raise RuntimeError(f"unsafe or non-portable ZIP entry: {name}")
        archive.testzip()
        archive.extractall(output)

    for required in (
        "picoradar_app/current/artisan",
        "picoradar_app/current/vendor/autoload.php",
        "picoradar_app/current/deploy/hostinger/routing.htaccess",
        "public_html/picoradar/index.php",
        "public_html/picoradar/_setup/index.php",
        "package-manifest.json",
    ):
        if not (output / required).is_file():
            raise RuntimeError(f"missing extracted entry: {required}")

    print(f"PASS: Linux extracted {len(names)} portable entries without repair")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
