# PICORADAR — INSTRUMENTO OPERATIVO PARA CIERRE FREE 1.0 Y CONVERGENCIA GITHUB

**Fecha de corte:** 21/11/2026. **Tipo:** trabajo realizado por ChatGPT Director mientras Codex Luna ejecuta C7-V2. **NO es un nuevo prompt; NO interrumpir a Codex.**

## 1. Entregables efectivamente preparados, no solo planificados

Se implementó y probó un **comprobador de diferencias Git de solo lectura**, independiente de Dart, PHP y librerías externas. Emite `DIFF_MAIN_FUENTE.csv` y `RESUMEN_GIT.json` con los IDs de árbol, clasificación por ruta y SHA de salida. No clona ni descarga, no hace `checkout`, `merge`, `commit`, `push`, `clean`, ni escribe en el checkout. Exige una carpeta de informes fuera del repositorio y rechaza sobreescritura. El script está completo en el apéndice y también se entrega como archivo Python separado.

La prueba reproducible del comprobador utilizó dos commits de fixture **sin ancestro compartido**: comprobó 1 `IDENTICAL`, 1 `CHANGED`, 1 `SOURCE_ONLY`, 1 `MAIN_ONLY`, generó el CSV correcto y verificó las dos paradas de seguridad. **PASS del fixture**; no es certificación de un merge real de PicoRadar ni sustituye el scanner de secretos.

Se generó además una **matriz por herramienta real del catálogo Apps** a partir del archivo `mobile/lib/features/apps_launcher/data/module_registry.dart` y de `mobile/lib/app/router/app_router.dart` dentro del snapshot C6. Se comprobó la existencia de sus pantallas Dart y se contaron archivos `*_test.dart` por carpeta de feature. **Es inventario de navegación y fuentes, no aceptación de producto.**

## 2. Fuente de verdad y diff congelado C6 contra `main`

Comparación de árboles Git verificados previamente en GitHub:

| Concepto | Valor comprobado |
|---|---:|
| `main` HEAD | `e9ef37511df3110ffb0fc006ef06be781df432ac` |
| `main` tree | `3e3a6c05bf09c1b059262ba5cf311d3e6b348b6f` |
| C6 respaldo HEAD | `bc1422c7198607850a49f4a294ed67316fed0805` |
| C6 tree | `2c0fd2e7a4ef8eed5b342101afb7320982d3c07c` |
| Rutas idénticas | **806** |
| Misma ruta, SHA distinto | **408** |
| Solo fuente C6 | **668** |
| Solo `main` | **2** |
| Total rutas en el diff | **1.078** |

**No volver a contar «838 conflictos».** El respaldo C6 es un commit raíz sin parents. En el siguiente pase, el comparador debe usar **C7 final como fuente**, no asumir que los números de C6 permanecen. Los dos `main_only` requieren comprobación de consumidores y decisión explícita, sin restauración automática. El script no decide qué versión prevalece ni crea una rama de integración.

## 3. Primer inventario de las 16 herramientas visibles de Apps

**Resultado estricto: 16/16 banderas por defecto `true`, 16/16 rutas conectadas a pantallas de código presentes en C6, 0/16 certificadas por esta inspección para lanzamiento real.** No se cuentan como pantalla lista solo porque exista el archivo o haya tests en la carpeta.

| Herramienta | Ruta | Pantalla real en C6 | Pruebas en directorio* |
|---|---|---|---|
| Pico y placa | `/apps/pico` | `PicoDetailScreen` | 29 |
| Fotomultas | `/apps/module/fotomultas` | `FotomultasScreen` | 3 |
| Comparendos | `/apps/module/comparendos` | `ComparendosScreen` | 5 |
| SOAT | `/apps/module/soat` | `VehicleStatusScreen` | 21 |
| Tecnomecánica | `/apps/module/tecnomecanica` | `VehicleStatusScreen` | 21 |
| Impuestos | `/apps/module/impuestos` | `VehicleStatusScreen` | 21 |
| Documentos | `/apps/module/documentos` | `DocumentsScreen` | 15 |
| Seguro y asistencia | `/apps/module/seguro_asistencia` | `VehicleStatusScreen` | 21 |
| Defensa | `/apps/module/defensa` | `DefenseScreen` | 2 |
| CDA | `/apps/cda` | `CdaFinderScreen` | 7 |
| Servicios | `/apps/module/servicios` | `ServicesScreen` | 2 |
| Compra/Venta | `/apps/module/compra_venta` | `BuySellScreen` | 3 |
| Trámites | `/apps/module/tramites` | `TramitesScreen` | 2 |
| Peritajes | `/apps/module/peritajes` | `PeritajesScreen` | 2 |
| Talleres | `/apps/module/talleres` | `MaintenanceScreen` | 4 |
| Peajes y estado vial | `/trip` | `TripScreen` | 18 |

*Pruebas en directorio* = **cantidad de archivos** `*_test.dart` de la carpeta funcional, **no tests ejecutados ni aprobados**. Los módulos SOAT, Tecnomecánica, Impuestos y Seguro/Asistencia comparten `vehicle_status`: **no sumar sus 21 archivos cuatro veces**. Viaje/Peajes comparte área `trip`. El C6 ya tenía pruebas históricas acreditadas de otras entregas, pero esta inspección no las ejecutó de nuevo.

El resultado permite crear una medición **honesta y completa** de la app Free 1.0 a partir de requisitos del baseline: cada módulo necesitará criterios de recorrido real, permisos, servicio externo, fallback/offline y privacidad pertinentes. **No reemplazar el 58% histórico por 100% porque las rutas estén conectadas.**

## 4. Utilidad post-C7, sin pisar la ejecución actual

Una vez que Codex cierre C7-V2 y exista su SHA, el integrador podrá ejecutar el comprobador en **un clon aislado** con ambas referencias descargadas previamente. Los dos árboles deberán estar disponibles localmente; la herramienta **no hace `fetch`**. Usar `--expected-main-tree` y `--expected-source-tree` para bloquear resultados de una base distinta a la congelada.

Ejemplo de baseline C6 (para verificación de datos; en la ola siguiente sustituir C6 por C7):

```powershell
py PICORADAR_GIT_PREFLIGHT_SOLO_LECTURA.py --repo 'D:\codex\PicoRadar-aislado' --main-ref origin/main --source-ref origin/backup/picoradar-c6-source-20261120 --expected-main-tree 3e3a6c05bf09c1b059262ba5cf311d3e6b348b6f --expected-source-tree 2c0fd2e7a4ef8eed5b342101afb7320982d3c07c --out-dir 'D:\codex\_REPORTES\PicoRadar\GIT_COMPARE_C6'
```

El resultado ordenará 1.078 rutas de diff en el corte C6 si ambos árboles coinciden con esos SHA, y resumirá también las 806 rutas `IDENTICAL` sin volcarlas innecesariamente. Esto elimina pasos manuales, **no reduce mágicamente el riesgo de los 408 archivos modificados**. GitHub puede haber avanzado después de este corte.

## 5. Criterios de uso con la siguiente ola

- **No enviar herramienta ni nueva orden a Codex mientras termina C7-V2.** La nueva orden se emitirá una sola vez después de leer el ZIP de C7 y descontar las funciones ya terminadas.
- **No hacer merge automático.** Reconciliar archivos runtime con revisión de contrato, permisos, legalidad y tests causales; mantener `main` y PR #79 intactos hasta aprobación humana.
- **No pedir ni anexar APK, AAB, TAR o repositorios completos.** Evidencia ligera y hashes, con la rama remota como fuente de código.
- **No anunciar porcentaje global nuevo.** El 61/100 es evidencia local histórica; su denominador no mide los 16 módulos ni las funciones del producto. Esta matriz es una primera pieza para fijar un denominador verificable.
- **No repetir revisión de 3 pilotos ni planes previos.** Medellín, Bogotá y Cali ya están documentados como investigación acotada, separados de autorización de publicación.

## 6. Apéndice — script íntegro y reutilizable de solo lectura

Archivo extraíble: `PICORADAR_GIT_PREFLIGHT_SOLO_LECTURA.py`; Python 3.10+ y Git disponibles. El script no debe ejecutarse desde el directorio WIP protegido ni escribir dentro de él.

```python
#!/usr/bin/env python3
r"""PicoRadar: compara dos árboles Git SIN modificar repos, índices ni ramas.

Uso Windows:
  py PICORADAR_GIT_PREFLIGHT_SOLO_LECTURA.py --repo D:\\codex\\PicoRadar-aislado \
    --main-ref origin/main --source-ref origin/backup/picoradar-c6-source-20261120 \
    --out-dir D:\\codex\\_REPORTES\\PicoRadar\\GIT-COMPARE-C6

La referencia C7 sustituirá a C6 después de que Codex cierre C7-V2.
No se hace checkout, git add, commit, merge, clean, rebase, push ni fetch.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
from collections import Counter
from pathlib import Path
import subprocess
import sys


def git(repo: Path, *args: str) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if result.returncode:
        # El mensaje puede incluir rutas; no registrar tokens ni contenido del repo.
        raise RuntimeError(f"git {args[0]} devolvió exit {result.returncode}")
    return result.stdout


def tree_id(repo: Path, ref: str) -> str:
    value = git(repo, "rev-parse", "--verify", f"{ref}^{{tree}}").decode("ascii").strip()
    if not (len(value) in (40, 64) and all(c in "0123456789abcdef" for c in value)):
        raise RuntimeError("ID árbol Git inválido")
    return value


def entries(repo: Path, tree: str) -> dict[str, tuple[str, str]]:
    data = git(repo, "ls-tree", "-r", "-z", "--full-tree", tree)
    result = {}
    for item in data.split(b"\0"):
        if not item:
            continue
        meta, raw_path = item.split(b"\t", 1)
        mode, obj_type, blob = meta.decode("ascii").split(" ")
        # Git acepta bytes arbitrarios; surrogateescape garantiza round-trip.
        path = raw_path.decode("utf-8", "surrogateescape")
        if path in result:
            raise RuntimeError("Ruta duplicada en árbol Git")
        result[path] = (blob, mode + ":" + obj_type)
    return result


def category(path: str) -> str:
    if path.startswith(("mobile/lib/", "mobile/android/")):
        return "RUNTIME_MOBILE"
    if path.startswith(("server/app/", "server/routes/", "server/resources/views/")):
        return "RUNTIME_SERVER"
    if path.startswith("mobile/test/"):
        return "TEST_MOBILE"
    if path.startswith("server/tests/"):
        return "TEST_SERVER"
    if path.startswith(("mobile/assets/", "server/public/")):
        return "ASSET"
    if path.startswith("docs/") or path.endswith((".md", ".rst")):
        return "DOCUMENTATION"
    return "OTHER"


def risk(path: str, ma: tuple[str, str] | None, mb: tuple[str, str] | None) -> str:
    low = path.lower()
    if low.endswith((".key", ".pem", ".p12", ".pfx", ".jks", ".keystore", ".apk", ".aab", ".zip", ".tar.gz", ".env")) or "/.env" in low:
        return "SECURITY_REVIEW"
    if (ma and not ma[1].startswith("100644:blob") and not ma[1].startswith("100755:blob")) or (mb and not mb[1].startswith("100644:blob") and not mb[1].startswith("100755:blob")):
        return "SPECIAL_GIT_ENTRY_REVIEW"
    if path in ("mobile/lib/app/router/root_placeholder_screen.dart", "mobile/lib/features/home/presentation/home_banner_slot.dart"):
        return "CONSUMER_CHECK"
    if category(path) in ("RUNTIME_MOBILE", "RUNTIME_SERVER"):
        return "CONTRACT_REVIEW"
    return "STANDARD_REVIEW"


def refuse_inside_repository(repo: Path, out: Path) -> None:
    # No escribir informes en ningún subdirectorio del checkout productivo.
    try:
        if os.path.commonpath([str(repo.resolve()), str(out.resolve())]) == str(repo.resolve()):
            raise ValueError("out-dir está dentro del repositorio: usar _REPORTES fuera del checkout")
    except ValueError as e:
        if "out-dir" in str(e):
            raise
        # En Windows, diferentes unidades tienen commonpath indefinido; son independientes.


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--main-ref", required=True)
    parser.add_argument("--source-ref", required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--expected-main-tree", default="")
    parser.add_argument("--expected-source-tree", default="")
    args = parser.parse_args()
    repo, out = args.repo.resolve(), args.out_dir.resolve()
    if not repo.is_dir():
        raise RuntimeError("Repositorio local inexistente")
    refuse_inside_repository(repo, out)
    main_tree = tree_id(repo, args.main_ref)
    source_tree = tree_id(repo, args.source_ref)
    if args.expected_main_tree and main_tree != args.expected_main_tree:
        raise RuntimeError("Árbol main distinto del congelado; no usar datos históricos")
    if args.expected_source_tree and source_tree != args.expected_source_tree:
        raise RuntimeError("Árbol fuente distinto del congelado")
    a, b = entries(repo, main_tree), entries(repo, source_tree)
    rows = []
    status_counts: Counter[str] = Counter()
    categories: Counter[str] = Counter()
    for path in sorted(a.keys() | b.keys()):
        left, right = a.get(path), b.get(path)
        state = (
            "IDENTICAL" if left and right and left == right else
            "CHANGED" if left and right else
            "SOURCE_ONLY" if right else "MAIN_ONLY"
        )
        status_counts[state] += 1
        if state == "IDENTICAL":
            continue  # Los idénticos no requieren ejecución ni reporte por ruta.
        typ = category(path)
        categories[state + ":" + typ] += 1
        rows.append({
            "path": path,
            "status": state,
            "category": typ,
            "review_gate": risk(path, left, right),
            "main_blob": left[0] if left else "",
            "source_blob": right[0] if right else "",
            "main_mode": left[1] if left else "",
            "source_mode": right[1] if right else "",
        })
    if out.exists() and any(out.iterdir()):
        raise RuntimeError("Carpeta de salida no vacía; no sobrescribir evidencia")
    out.mkdir(parents=True, exist_ok=True)
    csv_path = out / "DIFF_MAIN_FUENTE.csv"
    with csv_path.open("x", newline="", encoding="utf-8") as fd:
        writer = csv.DictWriter(fd, fieldnames=list(rows[0]) if rows else ["path", "status", "category", "review_gate", "main_blob", "source_blob", "main_mode", "source_mode"])
        writer.writeheader()
        writer.writerows(rows)
    digest = hashlib.sha256(csv_path.read_bytes()).hexdigest()
    summary = {
        "type": "READ_ONLY_GIT_TREE_COMPARISON",
        "main_ref": args.main_ref,
        "source_ref": args.source_ref,
        "main_tree": main_tree,
        "source_tree": source_tree,
        "main_paths": len(a),
        "source_paths": len(b),
        "status_counts": dict(status_counts),
        "changed_categories": dict(categories),
        "diff_csv_sha256": digest,
        "interpretation": "Paths/blobs only; NOT a safe-merge certification or product completion metric.",
        "no_mutations_performed": True,
    }
    with (out / "RESUMEN_GIT.json").open("x", encoding="utf-8") as fp:
        json.dump(summary, fp, ensure_ascii=False, indent=2, sort_keys=True)
        fp.write("\n")
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"PREFLIGHT_STOP: {error}", file=sys.stderr)
        sys.exit(2)
```

**SIGUE: CODEX LUNA TERMINANDO C7-V2. DESPUÉS SIGUE CHATGPT DIRECTOR PARA SU AUDITORÍA DIFERENCIAL E INTEGRAR ESTE INSTRUMENTO EN UNA SOLA ORDEN.**
