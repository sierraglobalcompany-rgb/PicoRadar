# PicoRadar — Auditoría forense de estado

Fecha: 2026-08-27

## Veredicto ejecutivo

El proyecto NO está mal encaminado técnicamente, pero sí existe una desviación importante entre el producto visual acordado y la implementación Flutter actual.

Estado aproximado:

| Área | Estado | Lectura |
|---|---:|---|
| Dominio/local-first | 8/10 | Motor, Drift, preferencias, crypto y datasets van bien. |
| Funcionalidad móvil C00–C12 | 8/10 | Se ha seguido el orden técnico general. |
| Fidelidad UI/UX | 3/10 | La app funciona, pero no reproduce la gramática visual aprobada. |
| Backend/control plane | 1/10 | Existe prácticamente solo el scaffold Laravel. |
| Trazabilidad de plan | 7/10 | Lotes siguen el orden, pero E10 backend quedó demasiado postergado. |
| Higiene de repo | 5/10 | Existen artefactos bootstrap/hashes/documentos duplicados que ya no aportan capacidad. |
| Gate visual/QA | 2/10 | Se validan tests y APK, pero no existe un gate fuerte de screenshot vs mockup aprobado. |

## Evidencia principal de desviación visual

El baseline visual exige:

- radios de card de 20–24 px;
- padding de card 20–24 px;
- H1 24–28 sp;
- H2 18–22 sp;
- display 32–40 sp;
- componentes raíz reutilizables: AppHeader, StatusCard, VehicleCard, DocumentExpiryCard, AppLauncherTile, SourceBadge, EmptyState y PermissionSheet;
- Inicio con jerarquía: estado de circulación → próxima restricción → vencimientos/accesos → CTA único Conducir;
- Garaje como dashboard visual de vehículos + circulación + SOAT + RTM + impuestos;
- interfaz clara/luminosa y Conducir como superficie oscura dedicada.

La implementación actual contiene, entre otros síntomas:

- `AppRadius.card = 8.0`, contradiciendo 20–24 px;
- ThemeData con tipografía incompleta: solo `headlineMedium` y `bodyMedium` están definidos explícitamente;
- uso repetido de Material `Card`, `ListTile`, `FilledButton` y layouts específicos sin una capa de componentes visuales equivalentes a los del Design System;
- pantallas grandes construidas directamente por feature, por ejemplo Home y status vehicle, lo que hace que el comportamiento funcione pero la composición termine pareciendo Material por defecto;
- ausencia de un proceso obligatorio de comparación visual screenshot-a-screenshot antes de cerrar los lotes.

Conclusión: el problema NO requiere reescribir motor, DB o navegación. Requiere una fase de rescate visual controlada.

## Cumplimiento del plan original

El orden técnico ejecutado hasta C12 sigue razonablemente `C00 → C12`. Eso coincide con el plan secuencial original.

La desviación está en dos puntos:

1. E00 decía `Fundación + Design System`, pero en la práctica solo se implementó una fracción mínima del Design System.
2. E10 `Backend/control plane` debía acompañar en paralelo a los lotes móviles según necesidad; hoy el backend sigue prácticamente en scaffold.

Por tanto, seguir añadiendo features C14+ sin corregir estas dos desviaciones aumentaría retrabajo.

## Backend real encontrado

En `server/` existe Laravel, pero el control plane funcional todavía no existe.

Estado actual observado:

- Controllers: solo Controller base.
- Models: solo User por defecto.
- Migrations: usuarios/cache/jobs por defecto.
- Routes: web/console del scaffold; no API funcional propia.
- Sin datasets admin.
- Sin publisher.
- Sin fuentes/jurisdicciones administrables.
- Sin releases/versiones de datasets en servidor.
- Sin auditoría admin.
- Sin proxy Routes/Places.
- Sin endpoints de reportes de dato incorrecto.
- Sin mecanismo de invalidación push.

Esto significa que el `control plane liviano` definido por el baseline aún está pendiente casi completo.

## Qué NO debe ir al backend

Mantener local-first:

- vehículos;
- preferencias;
- documentos privados;
- pólizas/fechas locales del usuario;
- recorrido GPS;
- posición GPS continua;
- estado de conducción por segundo;
- documentos cifrados;
- historial de ruta por defecto.

El backend NO debe convertirse en un SaaS de usuario antes de Free 1.0.

## Deuda estructural importante

### 1. Gate visual inexistente

Un lote visual no puede volver a cerrarse únicamente con `flutter test + APK`.

Debe existir:

`mockup aprobado → implementación → screenshot real → comparación → mismatch ledger → corrección`.

### 2. Documentación antigua/no canónica

El repo conserva archivos de bootstrap y handoff temprano que Git ya preserva históricamente. Si no son usados por scripts ni contratos actuales, mantenerlos en el árbol activo solo aumenta ruido.

Candidatos a revisión/eliminación segura, previa búsqueda de referencias:

- `00_CODEX_ONECLICK_EXECUTE_C00.md`
- `00_CODEX_ONECLICK_EXECUTE_C01.md`
- `C00_APPROVAL_BY_CHATGPT.md`
- `C00_EXACT_PROMPT_PICORADAR_FOR_CODEX.md`
- `C00_HANDOFF_SUMMARY_FOR_CHATGPT.md`
- `C01_EXACT_PROMPT_PICORADAR_FOR_CODEX.md`
- `PACKAGE_AUDIT.json`
- `PACKAGE_AUDIT_C01.json`
- READMEs de bootstrap que ya estén supersedidos
- screenshots de handoff antiguos si no son referencia visual vigente
- `SHA256SUMS.txt` y `manifest_sha256.txt` si se confirma que ningún proceso actual los consume

Regla: si puede borrarse y Git conserva la historia sin perder una capacidad operativa, debe salir del árbol activo.

## Recomendación de control inmediato

Después de revisar/mergear C13, pausar temporalmente C14 y ejecutar una fase de recuperación:

- R00 Auditoría + repo hygiene + SOP.
- R01 Design System Flutter 2.0.
- R02 Rediseño fiel de Inicio/Garaje/Apps/Onboarding.
- R03 Rediseño fiel de Pico/SOAT/RTM/Seguro/Impuestos.
- R04 Visual regression + physical screenshot gate.

En paralelo, sin tocar los mismos archivos Flutter:

- B00 Backend control-plane foundation.
- B01 Dataset registry + publisher + CDN manifest.

Después se retoma C14+.

## Regla KISS forense

Antes de añadir cualquier archivo, tabla, abstracción o documento preguntar:

> ¿Puede borrarse o fusionarse sin perder una capacidad, contrato, prueba o decisión vigente?

Si la respuesta es sí, no debe existir como pieza separada.

Presupuesto recomendado por lote:

- 0–1 dependencias directas nuevas;
- 0–1 migración DB;
- preferiblemente ≤5 archivos de producción nuevos;
- una sola representación de dominio por concepto;
- no Repository + Service + Manager + UseCase para la misma operación;
- no duplicar estado derivable;
- no guardar historiales técnicos que Git ya conserva.
