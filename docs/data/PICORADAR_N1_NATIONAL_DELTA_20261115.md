# PicoRadar N1 R1 — delta nacional LAB

**Resultado:** `PARTIAL` · **PRODUCT_RELEASE:** `NO_GO`

**Base:** `7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`

**Rama aislada:** `feat/picoradar-n1-schema2-cartagena-lab`

## Cambios

- Se agregó el marcador tipado `fullDay=true` exclusivamente para ventanas schema2 con minutos iguales entre 0 y 1439. La ventana se ancla a esa hora local y termina, de forma exclusiva, 24 horas civiles después. El marcador no se serializa en ventanas regulares.
- PHP y Python validan el marcador de forma estricta; Dart conserva el contrato legacy y el parser recibe la versión de esquema. La evaluación usa semana, paridad, vigencia y festivo de la fecha ancla. Si una regla no festiva necesita el festivo de un día distinto y no hay proveedor, devuelve `UNKNOWN`.
- La evaluación diaria segmenta medianoche y la hora ancla. El resumen general de ciudad pone `CALENDAR_COMPLEXITY_HOLD` para fullDay y no crea intervalos de longitud cero ni un “Libre” engañoso. El detalle solo expresa “24 h, de HH:mm a HH:mm siguiente” cuando una evaluación segura identifica una ventana; la ambigüedad se muestra como “Por verificar”. El contador usa el fin del ancla siguiente, no medianoche.
- Se añadió la cobertura LAB `Cartagena / motorcycle / private` con cinco reglas oficiales de lunes a viernes, último dígito 1/2, 3/4, 5/6, 7/8 y 9/0, de 05:00 a 23:00, excluyendo festivos. Las cinco reglas conservan `inside_scope_ref` sin afirmar cobertura geográfica o exenciones completas.
- Se preservaron la rotación de carros, sus fechas y sus horas. La cobertura nueva es `partial`; no se infiere permiso fuera de la ventana ni por falta de datos.

## Fuentes y decisiones

- La [Alcaldía de Cartagena, comunicado del 6 de octubre de 2026](https://cartagena.gov.co/noticias/cambia-rotacion-pico-placa-para-motos-vehiculos-particulares-cartagena-0) confirma la rotación vigente hasta el 22 de enero de 2027, los pares por día, el horario de carros 07:00–09:00 y 18:00–20:00, el horario de motos 05:00–23:00 y la excepción de fines de semana y festivos.
- El [anuncio oficial de enero de 2026](https://www.cartagena.gov.co/noticias/conozca-el-nuevo-pico-placa-para-particulares-sus-rotaciones-durante-el-2026) había previsto un periodo especial de 24 horas del 11 de diciembre al 22 de enero. La comunicación oficial de [junio de 2026](https://www.cartagena.gov.co/noticias/pico-placa-no-sera-24-horas-datt-reitera-que-mantiene-medida-vigente-establecida-horario-fraccionado) solo negó la aplicación de 24 horas para mitad de año. La publicación de octubre reafirma el horario regular, pero no resuelve expresamente diciembre. Por eso `N1_SEASONAL=HOLD_OFFICIAL_RECONFIRMATION`; no se añadió esa regla estacional.
- La [información oficial del permiso DATT](https://cartagena.gov.co/tramites-y-servicios/permiso-pico-placa) y el decreto anunciado en enero evidencian condiciones de circulación nocturna para motos. No se transformaron en un permiso general de 23:00–05:00: `NIGHT_MOTORCYCLE=LEGAL_HOLD`.
- La [Alcaldía de Medellín](https://www.medellin.gov.co/es/secretaria-de-movilidad/pico-y-placa-medellin-2023-segundo-semestre/) describe la rotación quincenal de taxis, de 06:00 a 20:00 en días hábiles. El snapshot nacional no contiene cobertura de taxis de Medellín: queda `ENGINE_GAP`, sin inventar un ciclo.

## Snapshot y verificaciones

`national_bulk_n1_2026-11-15.json` se generó desde el manifiesto explícito N1 con `--write` y se verificó después con `--check`. Resultado: **14 autoridades, 33 códigos DIVIPOLA, 22 coberturas parciales y 120 reglas**. Las otras 13 autoridades son semánticamente idénticas al snapshot V6R4; la cobertura de carros de Cartagena también es idéntica. La nueva fuente tiene SHA-256 `277db4ac0540814df3b553c6febf5e3baea0e931f62f49436d9a05f081a4e8e8`; el snapshot tiene SHA-256 `5db2bcd75c258247ddc3b54a6af94413da9f6918ca2ceca037e89ca9b84ae487`.

PHP: `php -l` pasó; el archivo PHPUnit focal completo pasó (**13 tests / 37 assertions**). Python: el módulo focal completo pasó (**16 tests**); `--write` y `--check` del snapshot pasaron. Las invocaciones PHP/Python incluyeron casos previos de esos archivos además de los nuevos; no se ejecutaron suites globales. `git diff --check` pasó antes del cierre final. Hay pruebas Dart nuevas para parser, motor, proyección diaria, resumen de ciudad y el contador de 06:00 a 06:00; no se ejecutaron porque el entorno no tiene Flutter ni Dart. Por ello `N1_ENGINE_24H=PARTIAL_NOT_RUN_ENV` y `N1_NO_FALSE_ALLOWED=NOT_RUN_ENV`: no se declara PASS de los consumidores móviles ni de análisis Flutter.

El rechazo de cobertura schema2 `complete` permanece en el ensamblador; los validadores de release/publicación y las dependencias no se modificaron. No hubo build, APK, Android, ADB, Mi A3, Git remoto ni publicación. El ciclo OTA real y la aptitud de release siguen pendientes.
