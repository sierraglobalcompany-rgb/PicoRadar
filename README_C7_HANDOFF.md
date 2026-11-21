# PicoRadar C7 V2 — handoff local

**Task:** `PICORADAR-C7-V2-IMPLEMENTACION-NACIONAL-20261121`
**Rama:** `feat/C7-national-review-20261121`
**Base exacta:** C6 `bc1422c7198607850a49f4a294ed67316fed0805`, tree `2c0fd2e7a4ef8eed5b342101afb7320982d3c07c`.
**Commit de implementación:** `e79a5b06a2756b8f407d8be0ec25edbec8e98ed4`, tree `3a792d081c2acf178d1270621b64efe1ec1ef7cb`.

## Gates

- **A — `PASS_NEW_RUNTIME`:** matriz GET `/admin/restrictions/municipalities`, enlazada desde la bandeja Pico y Placa; `datasets.view`; filtros de texto/departamento/gestión/evidencia; página de hasta 50; UNKNOWN explícito; varias jurisdicciones y categorías separadas; releases leídos solo de publicaciones reales; enlaces GET según rol. Verificados por 3 pruebas focales/41 aserciones, `php -l`, Pint y navegación local con datos sintéticos.
- **B — `PARTIAL_OFFICIAL`:** Medellín y Bogotá accesibles. Medellín identifica Decreto 1490/2026, pero no se obtuvo texto íntegro; Bogotá entrega un calendario semanal, no el acto jurídico. Cali devolvió 403 en la nota y en el boletín; no se superó el bloqueo. No se creó borrador porque ninguna fuente entregó texto íntegro verificable para sustentar carga legal tipada.
- **Comparación Bogotá:** regla local noviembre coincide con la página oficial del 16–22 de noviembre para carros particulares y taxis en los días/horarios cubiertos. Transporte especial, carga y pico y placa regional del festivo no están en la cobertura local comparada; motocicleta local no tiene reglas y su revisión está vencida.
- **C — Android:** `BLOCKED_EXTERNAL`: el único preflight ADB read-only registró cero dispositivos; no hay emulador utilizable. APK C6 queda local y no se instaló.
- **C — HTTPS:** `BLOCKED_EXTERNAL`: no hay staging autorizado con dominio/certificado verificables. No se agregó TLS local.
- **D — GitHub:** push no forzado a la rama C7 y PR Draft contra `backup/picoradar-c6-source-20261120`, nunca contra `main`. Sin Actions, merge ni publicación. El hash remoto y PR se registran en el informe C7.

## Decisión

`RELEASE=NO_GO`; `MAIN_INTEGRATION=HOLD_COMPATIBILITY`; `ADS_PAYMENTS_PREMIUM=OFF`. No se modificaron motor, reglas, datos legales, API, esquema, dependencias ni otro checkout. Siguiente: ChatGPT Director revisa el ZIP C7, decide cobertura jurídica posterior y define compatibilidad antes de cualquier integración con `main`.
