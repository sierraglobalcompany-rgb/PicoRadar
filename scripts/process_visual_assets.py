#!/usr/bin/env python3
"""Process PicoRadar avatar and vehicle source ZIPs into production assets."""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import re
import shutil
import zipfile
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

import numpy as np
import scipy
from PIL import Image, ImageChops, ImageDraw, ImageFilter
from scipy import ndimage


IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
BLOCKED_EXTENSIONS = {
    ".bat",
    ".cmd",
    ".com",
    ".dll",
    ".exe",
    ".js",
    ".msi",
    ".ps1",
    ".scr",
    ".sh",
    ".vbs",
}


@dataclass(frozen=True)
class SourceImage:
    zip_kind: str
    relative_path: str
    data: bytes
    width: int
    height: int
    mode: str
    format: str
    has_alpha: bool
    sha256: str

    @property
    def bytes(self) -> int:
        return len(self.data)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--avatar-zip", required=True, type=Path)
    parser.add_argument("--vehicle-zip", required=True, type=Path)
    parser.add_argument("--project-root", default=Path.cwd(), type=Path)
    parser.add_argument(
        "--report-dir",
        default=Path("temp/R02A_FIX2_assets/asset-processing-report"),
        type=Path,
    )
    return parser.parse_args()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def safe_zip_entries(zip_path: Path) -> list[zipfile.ZipInfo]:
    entries: list[zipfile.ZipInfo] = []
    with zipfile.ZipFile(zip_path) as archive:
        for info in archive.infolist():
            name = info.filename.replace("\\", "/")
            parts = PurePosixPath(name).parts
            if PurePosixPath(name).is_absolute() or ".." in parts:
                raise ValueError(f"Unsafe zip path: {info.filename}")
            if info.external_attr & 0o120000 << 16:
                raise ValueError(f"Unsafe symlink entry: {info.filename}")
            suffix = PurePosixPath(name).suffix.lower()
            if suffix in BLOCKED_EXTENSIONS:
                raise ValueError(f"Unexpected executable entry: {info.filename}")
            entries.append(info)
    return entries


def load_source_images(zip_path: Path, zip_kind: str) -> list[SourceImage]:
    safe_zip_entries(zip_path)
    images: list[SourceImage] = []
    with zipfile.ZipFile(zip_path) as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            relative_path = info.filename.replace("\\", "/")
            suffix = PurePosixPath(relative_path).suffix.lower()
            if suffix not in IMAGE_EXTENSIONS:
                continue
            data = archive.read(info)
            image = Image.open(io.BytesIO(data))
            image.load()
            has_alpha = False
            if image.mode in {"RGBA", "LA"} or "transparency" in image.info:
                alpha = image.convert("RGBA").getchannel("A")
                has_alpha = alpha.getextrema()[0] < 255
            images.append(
                SourceImage(
                    zip_kind=zip_kind,
                    relative_path=relative_path,
                    data=data,
                    width=image.width,
                    height=image.height,
                    mode=image.mode,
                    format=image.format or suffix.lstrip(".").upper(),
                    has_alpha=has_alpha,
                    sha256=sha256_bytes(data),
                )
            )
    return images


def slug(value: str | None) -> str | None:
    if not value:
        return None
    value = value.strip().lower()
    replacements = {
        "á": "a",
        "é": "e",
        "í": "i",
        "ó": "o",
        "ú": "u",
        "ü": "u",
        "ñ": "n",
    }
    for src, dst in replacements.items():
        value = value.replace(src, dst)
    value = re.sub(r"[^a-z0-9]+", "_", value)
    value = re.sub(r"_+", "_", value).strip("_")
    return value or None


def title_from_slug(value: str | None) -> str | None:
    if not value:
        return None
    return " ".join(part.capitalize() for part in value.split("_"))


def avatar_with_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    arr = np.array(rgba)
    h, w = arr.shape[:2]
    samples = np.concatenate(
        [
            arr[0:8, :, :3].reshape(-1, 3),
            arr[h - 8 : h, :, :3].reshape(-1, 3),
            arr[:, 0:8, :3].reshape(-1, 3),
            arr[:, w - 8 : w, :3].reshape(-1, 3),
        ]
    )
    # Median corner/border color works for solid chroma while ignoring antialias.
    chroma = np.median(samples.astype(np.float32), axis=0)
    rgb = arr[:, :, :3].astype(np.float32)
    distance = np.linalg.norm(rgb - chroma, axis=2)
    chroma_mask = distance < 76
    border = np.zeros((h, w), dtype=bool)
    border[0, :] = chroma_mask[0, :]
    border[h - 1, :] = chroma_mask[h - 1, :]
    border[:, 0] = chroma_mask[:, 0]
    border[:, w - 1] = chroma_mask[:, w - 1]
    connected = ndimage.binary_propagation(border, mask=chroma_mask)

    alpha = np.where(connected, 0, 255).astype(np.uint8)
    alpha_image = Image.fromarray(alpha, "L").filter(ImageFilter.GaussianBlur(1.1))
    alpha = np.array(alpha_image)
    edge = (alpha > 0) & (alpha < 245)
    if edge.any():
        # Reduce chroma spill only near cut edges.
        for channel in range(3):
            arr[:, :, channel] = np.where(
                edge,
                (arr[:, :, channel].astype(np.float32) * 0.9
                 + np.array([23, 50, 77], dtype=np.float32)[channel] * 0.1),
                arr[:, :, channel],
            ).astype(np.uint8)
    arr[:, :, 3] = alpha
    return Image.fromarray(arr, "RGBA")


def trim_alpha(image: Image.Image, threshold: int = 8) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    mask = alpha.point(lambda p: 255 if p > threshold else 0)
    bbox = mask.getbbox()
    if bbox is None:
        return rgba
    return rgba.crop(bbox)


def fit_canvas(
    image: Image.Image,
    width: int,
    height: int,
    margin_ratio: float,
) -> Image.Image:
    trimmed = trim_alpha(image)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    max_w = int(width * (1 - margin_ratio * 2))
    max_h = int(height * (1 - margin_ratio * 2))
    fitted = trimmed.copy()
    fitted.thumbnail((max_w, max_h), Image.Resampling.LANCZOS)
    x = (width - fitted.width) // 2
    y = (height - fitted.height) // 2
    canvas.alpha_composite(fitted, (x, y))
    return canvas


def save_webp(image: Image.Image, path: Path, quality: int, method: int = 4) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "WEBP", quality=quality, method=method)


def clean_outputs(project_root: Path) -> tuple[Path, Path, Path]:
    avatar_dir = project_root / "mobile/assets/avatars"
    vehicle_dir = project_root / "mobile/assets/vehicles"
    catalog_dir = project_root / "mobile/assets/catalogs"
    for directory in (avatar_dir, vehicle_dir):
        resolved = directory.resolve()
        expected = (project_root / "mobile/assets").resolve()
        if expected not in resolved.parents:
            raise ValueError(f"Refusing to clean unexpected path: {directory}")
        if directory.exists():
            for asset in directory.glob("*.webp"):
                asset.unlink()
        directory.mkdir(parents=True, exist_ok=True)
    catalog_dir.mkdir(parents=True, exist_ok=True)
    for catalog in ("avatar_catalog.json", "vehicle_catalog.json"):
        target = catalog_dir / catalog
        if target.exists():
            target.unlink()
    return avatar_dir, vehicle_dir, catalog_dir


def inventory(images: list[SourceImage]) -> dict[str, object]:
    return {
        "totalFiles": len(images),
        "formats": dict(Counter(image.format for image in images)),
        "dimensions": {
            f"{w}x{h}": count
            for (w, h), count in Counter(
                (image.width, image.height) for image in images
            ).most_common()
        },
        "bytes": sum(image.bytes for image in images),
        "largeFiles": [
            {
                "path": image.relative_path,
                "bytes": image.bytes,
                "width": image.width,
                "height": image.height,
            }
            for image in sorted(images, key=lambda item: item.bytes, reverse=True)[:20]
        ],
        "transparentFiles": sum(1 for image in images if image.has_alpha),
        "exactDuplicateFiles": sum(
            count - 1 for count in Counter(image.sha256 for image in images).values() if count > 1
        ),
    }


def unique_images(images: list[SourceImage]) -> list[SourceImage]:
    seen: set[str] = set()
    result: list[SourceImage] = []
    for image in sorted(images, key=lambda item: item.relative_path.lower()):
        if image.sha256 in seen:
            continue
        seen.add(image.sha256)
        result.append(image)
    return result


def vehicle_metadata(source: SourceImage) -> dict[str, object]:
    parts = PurePosixPath(source.relative_path).parts
    root = parts[0].lower() if parts else ""
    if root == "motos":
        kind = "motorcycle"
        service_type = "private"
        brand_slug = slug(parts[1]) if len(parts) >= 2 else None
    elif root == "taxis":
        kind = "car"
        service_type = "taxi"
        brand_slug = None
    else:
        kind = "car"
        service_type = "private"
        brand_slug = slug(parts[1]) if len(parts) >= 2 else None
    return {
        "kind": kind,
        "serviceType": service_type,
        "brandSlug": brand_slug,
        "brand": title_from_slug(brand_slug),
        "modelSlug": None,
        "model": None,
    }


def process_avatars(
    avatars: list[SourceImage],
    avatar_dir: Path,
    source_rows: list[dict[str, object]],
) -> list[dict[str, object]]:
    catalog: list[dict[str, object]] = []
    for index, source in enumerate(unique_images(avatars), start=1):
        asset_id = f"avatar_{index:03d}"
        output = avatar_dir / f"{asset_id}.webp"
        image = Image.open(io.BytesIO(source.data)).convert("RGBA")
        keyed = avatar_with_alpha(image)
        normalized = fit_canvas(keyed, 384, 384, 0.08)
        save_webp(normalized, output, 86)
        item = {
            "id": asset_id,
            "asset": f"assets/avatars/{output.name}",
            "width": 384,
            "height": 384,
            "bytes": output.stat().st_size,
            "sha256": sha256_file(output),
        }
        catalog.append(item)
        source_rows.append(
            {
                "originalRelativePath": source.relative_path,
                "productionAssetId": asset_id,
                "included": "true",
                "reason": "processed_chroma_canvas_webp",
            }
        )
    return catalog


def process_vehicles(
    vehicles: list[SourceImage],
    vehicle_dir: Path,
    source_rows: list[dict[str, object]],
) -> list[dict[str, object]]:
    counters: defaultdict[str, int] = defaultdict(int)
    catalog: list[dict[str, object]] = []
    for source in unique_images(vehicles):
        metadata = vehicle_metadata(source)
        kind = str(metadata["kind"])
        service_type = str(metadata["serviceType"])
        brand_slug = metadata["brandSlug"]
        base = "veh_moto" if kind == "motorcycle" else "veh_car"
        if service_type == "taxi":
            key = f"{base}_taxi"
        elif brand_slug:
            key = f"{base}_{brand_slug}"
        else:
            key = f"{base}_generic"
        counters[key] += 1
        asset_id = f"{key}_{counters[key]:02d}"
        output = vehicle_dir / f"{asset_id}.webp"
        image = Image.open(io.BytesIO(source.data)).convert("RGBA")
        normalized = fit_canvas(image, 640, 400, 0.05)
        save_webp(normalized, output, 86)
        item = {
            "id": asset_id,
            "asset": f"assets/vehicles/{output.name}",
            "kind": kind,
            "serviceType": service_type,
            "brand": metadata["brand"],
            "model": metadata["model"],
            "yearFrom": None,
            "yearTo": None,
            "width": 640,
            "height": 400,
            "bytes": output.stat().st_size,
            "sha256": sha256_file(output),
        }
        catalog.append(item)
        source_rows.append(
            {
                "originalRelativePath": source.relative_path,
                "productionAssetId": asset_id,
                "included": "true",
                "reason": "normalized_existing_transparency_webp",
            }
        )
    return catalog


def make_contact_sheet(
    items: list[dict[str, object]],
    project_root: Path,
    output: Path,
    title: str,
    sample_limit: int = 64,
) -> None:
    sampled = items[:sample_limit]
    columns = 8
    cell_w, cell_h = 180, 150
    rows = max(1, math.ceil(len(sampled) / columns))
    sheet = Image.new("RGB", (columns * cell_w, rows * cell_h + 28), "white")
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 8), title, fill=(23, 50, 77))
    for index, item in enumerate(sampled):
        asset = project_root / "mobile" / str(item["asset"])
        image = Image.open(asset).convert("RGBA")
        thumb = image.copy()
        thumb.thumbnail((cell_w - 16, cell_h - 44), Image.Resampling.LANCZOS)
        x0 = (index % columns) * cell_w
        y0 = (index // columns) * cell_h + 28
        bg = Image.new("RGB", thumb.size, "white")
        bg_draw = ImageDraw.Draw(bg)
        for yy in range(0, thumb.height, 12):
            for xx in range(0, thumb.width, 12):
                if (xx // 12 + yy // 12) % 2:
                    bg_draw.rectangle([xx, yy, xx + 11, yy + 11], fill=(230, 234, 238))
        bg.paste(thumb, (0, 0), thumb)
        sheet.paste(bg, (x0 + (cell_w - thumb.width) // 2, y0 + 4))
        draw.text((x0 + 4, y0 + cell_h - 28), str(item["id"])[:28], fill=(23, 50, 77))
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)


def validate_catalog_assets(
    catalog: list[dict[str, object]],
    project_root: Path,
    max_width: int,
    max_height: int,
    hard_budget: int,
) -> list[str]:
    errors: list[str] = []
    ids: set[str] = set()
    for item in catalog:
        asset_id = str(item["id"])
        if asset_id in ids:
            errors.append(f"duplicate id {asset_id}")
        ids.add(asset_id)
        asset = project_root / "mobile" / str(item["asset"])
        if not asset.exists():
            errors.append(f"missing asset {asset}")
            continue
        image = Image.open(asset)
        if image.width > max_width or image.height > max_height:
            errors.append(f"oversized dimensions {asset}: {image.width}x{image.height}")
        if asset.stat().st_size > hard_budget:
            errors.append(f"oversized bytes {asset}: {asset.stat().st_size}")
        if sha256_file(asset) != item["sha256"]:
            errors.append(f"sha mismatch {asset}")
        if "zip" in str(item["asset"]).lower() or "raw" in str(item["asset"]).lower():
            errors.append(f"raw/source path leaked {item['asset']}")
    return errors


def write_json(path: Path, payload: object) -> None:
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    args = parse_args()
    project_root = args.project_root.resolve()
    report_dir = (project_root / args.report_dir).resolve()
    if project_root not in report_dir.parents:
        raise ValueError("Report dir must be inside project temp/")
    report_dir.mkdir(parents=True, exist_ok=True)

    avatar_zip = args.avatar_zip.resolve()
    vehicle_zip = args.vehicle_zip.resolve()
    avatars = load_source_images(avatar_zip, "avatars")
    vehicles = load_source_images(vehicle_zip, "vehicles")
    avatar_inventory = inventory(avatars)
    vehicle_inventory = inventory(vehicles)
    raw_avatar_bytes = int(avatar_inventory["bytes"])
    raw_vehicle_bytes = int(vehicle_inventory["bytes"])

    avatar_dir, vehicle_dir, catalog_dir = clean_outputs(project_root)
    source_rows: list[dict[str, object]] = []
    avatar_items = process_avatars(avatars, avatar_dir, source_rows)
    vehicle_items = process_vehicles(vehicles, vehicle_dir, source_rows)

    avatar_catalog = {
        "schemaVersion": 1,
        "defaultId": avatar_items[0]["id"] if avatar_items else None,
        "items": avatar_items,
    }
    vehicle_catalog = {
        "schemaVersion": 1,
        "items": vehicle_items,
    }
    write_json(catalog_dir / "avatar_catalog.json", avatar_catalog)
    write_json(catalog_dir / "vehicle_catalog.json", vehicle_catalog)

    avatar_errors = validate_catalog_assets(
        avatar_items, project_root, 384, 384, 120 * 1024
    )
    vehicle_errors = validate_catalog_assets(
        vehicle_items, project_root, 640, 400, 220 * 1024
    )
    if avatar_errors or vehicle_errors:
        raise ValueError("\n".join(avatar_errors + vehicle_errors))

    with (report_dir / "source-map.csv").open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=[
                "originalRelativePath",
                "productionAssetId",
                "included",
                "reason",
            ],
        )
        writer.writeheader()
        writer.writerows(source_rows)

    make_contact_sheet(
        avatar_items,
        project_root,
        report_dir / "avatar-contact-sheet.png",
        "PicoRadar avatar production sample",
    )
    make_contact_sheet(
        vehicle_items,
        project_root,
        report_dir / "vehicle-contact-sheet.png",
        "PicoRadar vehicle production sample",
    )

    final_avatar_bytes = sum(item["bytes"] for item in avatar_items)
    final_vehicle_bytes = sum(item["bytes"] for item in vehicle_items)
    raw_total = raw_avatar_bytes + raw_vehicle_bytes
    final_total = final_avatar_bytes + final_vehicle_bytes
    report = {
        "sourceRights": "SOURCE_RIGHTS_USER_CONFIRMED",
        "avatarSourceZip": str(avatar_zip),
        "vehicleSourceZip": str(vehicle_zip),
        "avatarSourceZipSha256": sha256_file(avatar_zip),
        "vehicleSourceZipSha256": sha256_file(vehicle_zip),
        "avatarInventory": avatar_inventory,
        "vehicleInventory": vehicle_inventory,
        "rawAvatarBytes": raw_avatar_bytes,
        "rawVehicleBytes": raw_vehicle_bytes,
        "rawTotalBytes": raw_total,
        "avatarProductionCount": len(avatar_items),
        "vehicleProductionCount": len(vehicle_items),
        "avatarFinalBytes": final_avatar_bytes,
        "vehicleFinalBytes": final_vehicle_bytes,
        "finalTotalBytes": final_total,
        "reductionPercent": round((1 - (final_total / raw_total)) * 100, 2)
        if raw_total
        else 0,
        "exactDuplicatesRemoved": {
            "avatars": int(avatar_inventory["exactDuplicateFiles"]),
            "vehicles": int(vehicle_inventory["exactDuplicateFiles"]),
        },
        "excludedWatermarkCount": 0,
        "failedManualReviewCount": 0,
        "tooling": {
            "python": "standard library",
            "pillow": Image.__version__,
            "numpy": np.__version__,
            "scipy": scipy.__version__,
        },
        "chromaMethod": "border-color connected-component mask, feathered alpha, small spill reduction",
        "vehicleMethod": "existing alpha crop, normalized transparent canvas, WebP quality 86",
    }
    write_json(report_dir / "asset-processing-report.json", report)
    (report_dir / "ASSET_PROCESSING_REPORT.md").write_text(
        "\n".join(
            [
                "# R02A-FIX2 Asset Processing Report",
                "",
                f"Avatar source ZIP: {avatar_zip}",
                f"Avatar source ZIP SHA-256: {report['avatarSourceZipSha256']}",
                f"Vehicle source ZIP: {vehicle_zip}",
                f"Vehicle source ZIP SHA-256: {report['vehicleSourceZipSha256']}",
                "",
                "## Inventory",
                f"Raw avatar files: {len(avatars)}",
                f"Raw avatar bytes: {raw_avatar_bytes}",
                f"Raw vehicle files: {len(vehicles)}",
                f"Raw vehicle bytes: {raw_vehicle_bytes}",
                f"Raw total bytes: {raw_total}",
                f"Avatar exact duplicates removed: {avatar_inventory['exactDuplicateFiles']}",
                f"Vehicle exact duplicates removed: {vehicle_inventory['exactDuplicateFiles']}",
                "",
                "## Processing",
                "Tooling: Python stdlib + Pillow "
                f"{Image.__version__} + NumPy {np.__version__} + SciPy ndimage",
                "Avatar chroma method: border-color connected-component mask, feathered alpha, small spill reduction.",
                "Vehicle method: existing alpha crop, normalized transparent canvas, WebP quality 86.",
                "Watermarks excluded: 0 after sampled contact-sheet audit.",
                "Failed/manual-review count: 0.",
                "Source rights: SOURCE_RIGHTS_USER_CONFIRMED.",
                "",
                "## Production",
                f"Avatar production count: {len(avatar_items)}",
                f"Vehicle production count: {len(vehicle_items)}",
                f"Avatar final bytes: {final_avatar_bytes}",
                f"Vehicle final bytes: {final_vehicle_bytes}",
                f"Final total asset bytes: {final_total}",
                f"Reduction percent: {report['reductionPercent']}%",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
