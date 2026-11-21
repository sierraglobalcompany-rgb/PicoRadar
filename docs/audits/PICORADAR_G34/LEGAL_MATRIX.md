# G34 — matriz legal focal

**Corte de revisión:** 2026-11-10 (UTC). Esta matriz documenta cinco pares ciudad/modalidad, no cobertura nacional. Cada cobertura del JSON es `partial`; no se crea estado `ALLOWED` por ausencia de regla.

## Reglas representadas

| Ciudad y par | Ámbito y fechas representadas | Rotación y hora | Datos y límites |
|---|---|---|---|
| Medellín · carro particular | Lunes a viernes, 2026-08-03 a 2026-12-31 | Último dígito: lun 5/8, mar 1/4, mié 0/2, jue 3/6, vie 7/9. 05:00–20:00. | La página oficial 2026 S2 describe carros particulares y motos de 2/4 tiempos, vías exentas y corregimientos no sujetos. No se resolvió en el sidecar la ubicación de vías o excepciones; se conserva parcial. |
| Medellín · moto particular | Mismas fechas y días | Primer dígito numérico: lun 5/8, mar 1/4, mié 0/2, jue 3/6, vie 7/9. 05:00–20:00. | La página oficial cubre motos de 2/4 tiempos; motos de domicilios y otros supuestos requieren verificación individual. No se codifican exenciones como permiso general. |
| Cartagena · carro particular | Lunes a viernes, 2026-10-05 a 2026-12-10 | Último dígito: lun 1/2, mar 3/4, mié 5/6, jue 7/8, vie 9/0. 07:00–09:00 y 18:00–20:00. | Se limita la propuesta a 10-dic por la regla estacional 11-dic–22-ene descrita en la noticia del Decreto 0015. El aviso DATT de octubre da la rotación regular hasta 22-ene y menciona disposiciones especiales. Se requiere el texto operativo firmado/confirmación DATT antes de codificar el periodo estacional. |
| Cartagena · moto particular | Lunes a viernes, 2026-10-05 a 2026-12-10 | Último dígito, misma rotación de lunes a viernes. 05:00–23:00. | Fuera de la propuesta quedan la restricción nocturna/permiso laboral y la restricción en el centro amurallado descritas por el Decreto 0015. La cobertura parcial impide convertir una coincidencia de rotación en autorización global. |
| Manizales · carro particular | Lunes a viernes, 2026-11-03 a 2026-11-30 | Último dígito: lun 1/2, mar 3/4, mié 5/6, jue 7/8, vie 9/0. 06:00–20:00. | Verificación oficial complementaria (2026-11-10): la publicación municipal confirma fechas, horario, rotación, vías municipales y exclusión de corredores nacionales como Panamericana; también enlaza el Decreto 0357. No se verificó cláusula por cláusula el texto operativo íntegro del PDF ni se mapeó el ámbito vial a datos del motor; excepciones y alcance individual siguen sin resolverse. La cobertura sigue parcial. |

Fuentes oficiales enlazadas desde los JSON y sus SHA se registran en `EDITORIAL_APPROVAL_AUDIT.md` y en cada archivo de propuesta.

## Fechas, festivos y calendario

- 11-nov-2026 es miércoles, 12-nov jueves y 13-nov viernes. Cartagena declaró esas fechas cívicas para el disfrute de las fiestas y suspendió trabajo de servidores distritales, según el aviso oficial citado. Ese aviso no declara suspensión de tránsito ni de pico y placa. La propuesta conserva la rotación normal en esas fechas por la regla DATT de lunes a viernes salvo festivos nacionales; es una inferencia de dos avisos oficiales, no una confirmación DATT específica para esos tres días, por lo que el calendario queda parcial hasta esa confirmación.
- El calendario oficial del Ministerio de Hacienda lista el festivo nacional de Independencia de Cartagena el lunes 16-nov-2026. Los JSON marcan `appliesOnHolidays=false`; el motor debe aplicar su calendario festivo, sin inferir que los días cívicos 11–13 equivalgan a festivo nacional.
- La fuente general de Cartagena exceptúa días festivos. La rotación y el manejo exacto del día 11 no se extienden más allá del alcance escrito por la autoridad de tránsito.

## Incertidumbres que siguen cerradas

1. No existe verificación de vías, corredores ni límites mediante los puntos DANE; son referencias derivadas de centroides.
2. En Cartagena, no se incorpora la temporada especial del 11-dic-2026 al 22-ene-2027 mientras la instrucción operativa vigente no quede confirmada de forma inequívoca.
3. En Manizales, la publicación oficial resume el Decreto 0357 y enlaza el PDF, pero esta revisión no completó una lectura cláusula por cláusula ni resolvió el ámbito espacial para cada recorrido; no declarar completa la cobertura ni inferir permisos individuales.
4. Las coberturas de taxi, servicio oficial, camión, bus, permisos individuales y demás categorías no presentadas en la tabla continúan desconocidas o sin confirmar.
5. Ninguna de estas cinco reglas se ha publicado ni validado dentro del motor Flutter en esta ejecución.

## Fuentes oficiales

- [Medellín — Pico y Placa segundo semestre 2026](https://www.medellin.gov.co/es/secretaria-de-movilidad/pico-y-placa-medellin-2023-segundo-semestre/): rotación, horario, categorías, vías exentas y corregimientos.
- [Medellín — metadatos oficiales de vías exentas](https://www.medellin.gov.co/giscatalogacion/srv/api/records/2d9cb19a-e7c7-4e1d-8a38-fb055997b043): metadatos GIS; no se usó como prueba de cobertura vial del motor.
- [Cartagena DATT — rotación vigente desde el 5-oct](https://www.cartagena.gov.co/noticias/datt-refuerza-controles-invita-cumplir-el-pico-placa-cartagena): categorías, horarios y excepciones por festivos.
- [Cartagena — Decreto 0015 y temporadas especiales](https://www.cartagena.gov.co/noticias/conozca-el-nuevo-pico-placa-para-particulares-sus-rotaciones-durante-el-2026): calendario de rotación y regla estacional descrita para carros.
- [Cartagena — días cívicos 11–13-nov](https://www.cartagena.gov.co/noticias/el-marco-fiestas-independencia-alcaldia-mayor-cartagena-declara-civicos-dias-11-12-13-noviembre-0): descanso laboral distrital; no anuncia suspensión de tránsito.
- [Manizales — regla temporal y Decreto 0357](https://centrodeinformacion.manizales.gov.co/como-funciona-el-pico-y-placa-en-manizales-durante-noviembre-de-2026/): publicación oficial consultada el 2026-11-10 que resume fechas, horarios, rotación, ámbito y exclusión de vías nacionales; enlaza el PDF del decreto. La revisión legal no completó una lectura exhaustiva del PDF.
- [Ministerio de Hacienda — festivos nacionales 2026](https://sedeelectronica.minhacienda.gov.co/SedeElectronica/info/inicio.do?formAction=btDiasInhabiles&target=print): 16-nov-2026.
- [DANE — DIVIPOLA/MGN 2025](https://portalgis.dane.gov.co/mparcgis/rest/services/Divipola/Serv_DIVIPOLA_MGN_2025/FeatureServer): referencia geográfica, nunca prueba de vía o excepción.
