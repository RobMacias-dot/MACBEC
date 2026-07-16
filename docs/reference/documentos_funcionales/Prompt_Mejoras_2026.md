# Prompt de mejoras — MacBec Solar App (2026)

> Grounded en: `docs/reference/documentos_funcionales/App_Cotizacion_Solar_v2.pdf` (spec original de fórmulas), un PDF de estructura generado por la app (`Estructura 6C5C2AD4`, revisión 2026-07-14), y el catálogo de precios `Plantilla_Catalogo_MacBec_ESTRUCTURA_REVISADA.xlsx` (hoja `Catalogo_Productos`, 161 productos, 45 columnas). Rutas de archivo verificadas en el código al 2026-07-14; confirmar que siguen vigentes antes de implementar.

Contexto de negocio: MacBec Solar es una app Flutter local-first (Riverpod + Drift) para cotizar instalaciones fotovoltaicas. Este prompt junta observaciones de uso real de la app más revisión de cálculos técnicos. Trabajar por fases; cada fase es independiente y puede entregarse por separado.

---

## Fase 1 — Flujo de clientes y cotización (UX/navegación)

1. **Borrar cliente.** `lib/features/clientes/presentation/screens/clientes_screen.dart` no tiene ninguna acción de eliminar (ni soft-delete) — confirmado por grep sin resultados en toda la feature. Agregar ícono de bote de basura en `_ClientCard`/`ClientesScreen` con diálogo de confirmación, y un método `delete()` (soft-delete preferible, coherente con `isDeleted` que ya usa `QuotationDraftRepository`) en el repositorio de clientes.

2. **Prospecto → Cliente (decidido: creación automática).** Al capturar el nombre de un posible cliente (flujo de "Nueva cotización") y guardarlo, debe **crearse automáticamente un registro en `Clientes`** vinculado a esa cotización — no se fusionan las entidades `QuotationDraftProspect` (`lib/features/cotizaciones/application/quotation_draft_controller.dart:27-30`) y `Cliente` (`lib/features/clientes/`), se mantienen separadas pero con creación automática de la segunda al guardar la primera. La navegación después de guardar debe llevar a continuar la cotización (no a la lista de Clientes — ver punto 4).

3. **"Nueva cotización" muestra datos viejos.** `cotizacion_prospecto_form_screen.dart:34-48` prellena los controllers leyendo `quotationDraftProspectProvider`, que es un `StateProvider` que nunca se limpia después de guardar (`cotizacion_prospecto_form_screen.dart:92`). Al entrar a "Nueva cotización" debe resetearse ese provider (`ref.read(quotationDraftProspectProvider.notifier).state = null` o equivalente) para mostrar el formulario en blanco.

4. **Guardar cliente nuevo no debe regresar a la lista.** `lib/features/clientes/presentation/screens/cliente_form_screen.dart`, método `_save()` (líneas 156-201) siempre hace `context.pop()` (línea 187) sin distinguir creación vs edición. Al **crear** un cliente nuevo debe continuar al siguiente paso del formulario (dirección, datos fiscales, etc.) en vez de volver a Clientes; al **editar** sí puede mantener el `pop()` actual.

5. **Flujo continuo de llenado.** Consecuencia directa de los puntos 2 y 4: rediseñar el alta de cliente + cotización como un flujo lineal (wizard/stepper) que no regrese a pantallas intermedias entre cada sección.

6. **Evitar preguntar los mismos datos varias veces.** Hoy el campo "Dirección" se captura por separado en tres pantallas distintas: `cliente_form_screen.dart:120-126`, `cotizacion_prospecto_form_screen.dart:187-196` ("Dirección aproximada") y `recibo_cfe_revision_screen.dart:182-198` ("Dirección del servicio"). Definir una única fuente de verdad (probablemente la dirección del cliente) y solo pedir confirmación/ajuste en los otros puntos si aplica (recordar que el recibo CFE puede pertenecer a un titular distinto al cliente, per el documento funcional §9.2).

7. **Mapa + autocomplete en "Dirección del servicio" (decidido: proveedor gratuito).** No existe integración de mapas hoy (`pubspec.yaml` no tiene `google_maps_flutter` ni Places API; grep sin resultados). Agregar autocomplete de calle → estado/colonia usando **Nominatim/OpenStreetMap** (sin costo, sin API key) en vez de Google Places, consumido vía HTTP directo (ya existe `http` en pubspec). Agregar un mapa (ej. `flutter_map` con tiles OSM, coherente con no depender de Google Maps SDK) después del campo de dirección. Tener en cuenta que Nominatim tiene límites de uso razonable (rate limiting) para uso gratuito — revisar su política de uso si el volumen de búsquedas crece.

8. **Vista previa de recibo (foto o PDF).** No se encontró un widget de previsualización en `recibo_cfe_screen.dart`/`recibo_cfe_revision_screen.dart`; el archivo se guarda pero no se muestra. Agregar preview inline: `Image.file` para imágenes, y para PDF usar el paquete `printing` ya presente en el proyecto (`PdfPreview` widget) o un thumbnail.

9. **Guardar avance de cotización hasta el último módulo trabajado.** `lib/features/cotizaciones/domain/entities/quotation_draft.dart` no tiene un campo explícito de "paso actual" — el progreso se infiere ad hoc con getters (`hasCfeReceipt`, `hasCompleteCfeReview` líneas 77-94, `hasEnergyAnalysisSettings` líneas 96-101). Agregar un campo persistido (`lastCompletedStep` o similar, en la tabla Drift de `quotation_drafts`) que se actualice al salir de cada módulo, y usarlo para reanudar directo en la pantalla correcta al reabrir un draft incompleto, en vez de que cada pantalla adivine el estado por separado.

---

## Fase 2 — OCR del recibo CFE

10. **Automatizar "Datos del recibo CFE".** El parser `lib/features/recibo_cfe/domain/cfe_receipt_text_parser.dart` ya extrae: `serviceAddress`, `rpu`, `tariff`, `billingPeriod`, `currentPeriodKwh`, `totalToPay`. **Falta el titular del servicio** (`_holderNameController` en `recibo_cfe_revision_screen.dart` no tiene sugerencia OCR — `_prefillFormIfNeeded`, líneas 373-419, nunca lo llena). Agregar heurística de extracción de "Titular del servicio" (buscar patrón típico de nombre en la cabecera del recibo CFE) y conectarlo al prefill. Revisar también la precisión general de los regex existentes contra recibos CFE reales, ya que el usuario reporta que "hay que llenarlo a mano" — puede que algunos patrones fallen con el formato real de los recibos usados en campo.

---

## Fase 3 — Cálculos técnicos generales

11. **HSP: verificar que ya usa promedio anual.** `lib/features/analisis_energetico/data/nasa_power_client.dart`, `fetchAnnualPeakSunHours()` (líneas 21-57) ya consulta NASA POWER (`ALLSKY_SFC_SW_DWN`) y toma el valor **`ANN`** (anual), no valores mensuales/diarios. **Esto ya cumple lo pedido** — la tarea aquí es auditar que ningún otro punto de la UI (pantalla de análisis energético) esté mostrando o usando un valor diario en su lugar antes de cerrar este punto como resuelto.

12. **Imágenes genéricas reales de panel e inversor (decidido: genéricas por categoría).** En "Selección técnica" mostrar una imagen real (no ilustrativa, no específica por marca/modelo) de "un panel", y en "Dimensionamiento" → "Inversor recomendado" una imagen genérica real de "un inversor". Los modelos `lib/features/catalogo_tecnico/*/solar_panel.dart` y `solar_inverter.dart` no tienen campo de imagen — agregar dos assets fijos (uno de panel, uno de inversor) en vez de un campo por SKU del catálogo.

13. **Tubería DC: +1/4" al cálculo.** `lib/features/dimensionamiento_electrico/domain/electrical_dimensioning_rules.dart`, `_calculateDcConduitRecommendation` (líneas 672-696) mapea la cantidad de conductores a un diámetro comercial (½", ¾", 1", 1¼", 1½", "2\" o mayor"). Mantener la fórmula/umbrales tal cual, pero sumar 1/4" al resultado final antes de mostrarlo, para no dejar la tubería justa. Confirmar contra el catálogo (`categoria_app = TUBERIA`) qué diámetros comerciales existen realmente (hoy solo hay 3/4" y 1" en `Catalogo_Productos`) para no recomendar un diámetro que no se compra.

14. **Cambiar ícono de gota de agua en tubería DC.** Ubicar el ícono actual (probablemente `Icons.water_drop` o similar) en la sección de tubería DC de la pantalla de dimensionamiento eléctrico y sustituirlo por uno más representativo de conducto/tubería eléctrica.

---

## Fase 4 — Estructura: rieles, ángulos, rompevientos, anclaje

**Contexto clave del catálogo** (`Catalogo_Productos`, categoría `ESTRUCTURA`, 40 productos) — **valores confirmados con el usuario, ya no hay ambigüedad**:
- **Riel nominal 5 m** → se **muestra** como "5 m" pero el cálculo usa **4.90 m reales**.
- **Riel nominal 6 m** → se muestra como "6 m", cálculo con **6.00/6.01 m reales** — confirmado, el catálogo es correcto, no requiere corrección.
- **Material de ángulo/estructura**: el usuario aclaró que la estructura puede construirse en **PTR de acero o en Ángulo de aluminio**, y **ambos materiales usan tramos comerciales de 6 m** (no hay diferencia de longitud entre las dos opciones; el 6.10 m nominal del ángulo de aluminio del catálogo es la medida de venta, pero el cálculo debe usar 6.00 m útiles igual que el PTR). El módulo de estructura debe permitir elegir el tipo de material (`PTR` o `Aluminio`) y calcular el costo según el producto de catálogo correspondiente (`PERFIL_PTR` en sus variantes de calibre, o `PERFIL_ANGULO_ALUMINIO`), pero la lógica de tramos/desperdicio (6 m, redondeo hacia arriba) es la misma para ambos.
- **Anclaje químico**: marca confirmada **Fester 890**, precio **$450 MXN** por cartucho. Actualizar la fila `EST-FIJ-ANCLAJE-QUIMICO` del catálogo con `marca = Fester`, `modelo = Fester 890`, `precio_compra = 450`, `moneda = MXN`, y quitar el estado `PENDIENTE_DEFINIR`. El cálculo de cantidad de cartuchos debe asumir **20 tuercas por cartucho**.

15. **Selector de material de estructura (PTR vs. Aluminio).** `lib/features/estructura/domain/structure_design_rules.dart` hoy calcula un único `angleMaterialMeters` sin distinguir tipo de material. Agregar una opción en la captura de estructura para elegir `PTR` o `Aluminio`; ambas usan la misma longitud de tramo (6 m) pero deben tomar el precio/producto correcto del catálogo al pasar a cotización (Fase 6). Actualizar también las filas `PENDIENTE_LONGITUD_TRAMO`/`PENDIENTE_DEFINIR` de PTR en el catálogo con `longitud_nominal_m = 6`.

16. **Cálculo de ángulo: total = patas + 2 rompevientos, redondeo al múltiplo de 6 siguiente, mismo rigor de desperdicio que rieles.** Confirmar en `structure_design_rules.dart` que `angleMaterialMeters` (que alimenta `angleSixMeterSections = (angleMaterialMeters / 6).ceil()`, línea 294) efectivamente suma el material de patas **más** `windBraceLengthMeters * windBracePiecesCount` (rompevientos, líneas 247-249) antes de dividir. Mostrar explícitamente este total en la UI/PDF (hoy solo se ve el resultado en tramos, no el total en metros). Además, reemplazar el `ceil()` simple por una lógica de optimización de desperdicio equivalente a `_optimizeRailStock` (líneas 299-340), ya que hoy el riel tiene cálculo fino de combinación de tramos y el ángulo no.

17. **Cartucho de anclaje químico = 20 tuercas.** Hoy `fixingPiecesPerTypeCount = totalLegCount * 2` (línea 264) calcula tuercas/rondanas por pata, pero no hay cálculo de cartuchos de anclaje químico. Agregar: `cartuchosNecesarios = ceil(totalTuercas / 20)`, ligado a la fila `EST-FIJ-ANCLAJE-QUIMICO` del catálogo (Fester 890, $450 MXN por cartucho, ya confirmado — no debe mostrar "-").

---

## Fase 5 — PDF de planos (diagramas técnicos)

Generado por `lib/features/documentos_pdf/data/pdf_service.dart`, método `generateStructuralPdf` (líneas 286-417): `_drawAreaPanel` (planta), `_drawSideView` (vista lateral, 471-541), `_drawFrontView` (vista frontal, 543-590), `_drawRearView` (vista trasera/rompevientos, 592-649).

18. **Separación de patas incorrecta.** En el PDF de muestra (`Estructura 6C5C2AD4`), la vista frontal marca "separación 2.14 m aprox." con 4 paneles horizontales (área de módulos 4.60×2.38 m) — el usuario indica que debería ser **1.8 m**. Fórmula de referencia del documento funcional original (pág. 8):
   ```
   distancia_entre_patas = [(valor_horizontal_total) - 1] / (No._de_paneles - 2)
   ```
   Ubicar el cálculo exacto de esta separación en `structure_design_rules.dart` (relacionado con `supportPointsPerRow`, línea 222) y compararlo contra esta fórmula con los números reales del ejemplo (4.60 m horizontal, 4 paneles) para encontrar el error — el resultado esperado del usuario (1.8 m) sugiere que puede estar usando `valor_horizontal_total` en vez de `valor_horizontal_total - 1`, o dividiendo entre `No.paneles` en vez de `No.paneles - 2`, u otra variación del denominador/numerador.

19. **Indicar separación entre patas en vista frontal Y trasera.** Hoy `_drawFrontView` (`pdf_service.dart:578-579`) ya etiqueta "Patas delanteras: N · separación X m aprox." La **vista trasera** (`_drawRearView`) no tiene esa etiqueta — agregarla ahí también.

20. **Vista lateral: distancia entre filas y largo total.** `_drawSideView` hoy solo dibuja una estructura (pata delantera/intermedia/trasera, ángulo, hipotenusa) sin mostrar la separación entre filas de estructuras (fila 1→2, fila 2→3, etc.) ni el largo total del arreglo. Agregar estas cotas cuando hay más de una fila de estructuras.

21. **Diagrama de rompevientos: forma de "V" alternada.** El usuario especifica que cada rompeviento debe ir del **punto más alto de una pata al punto más bajo (base) de la pata siguiente**, alternando: leyendo la vista trasera de izquierda a derecha, el primer rompeviento va de la parte alta de la pata 1 a la base de la pata 2, y el segundo de la base de la pata 2 a la parte alta de la pata 3 (formando una V). Revisar `_drawRearView` (`pdf_service.dart:592-649`) línea por línea contra esta descripción exacta — el PDF de muestra ya muestra una forma de "V" visualmente, pero hay que confirmar que los puntos de anclaje (alto→base→alto) sean exactamente los que describe el usuario y no una aproximación visual distinta.

---

## Fase 6 — Catálogo de precios y cotización final

22. **Importar el catálogo real de precios.** Archivo fuente: `Plantilla_Catalogo_MacBec_ESTRUCTURA_REVISADA.xlsx`, hoja `Catalogo_Productos` (161 filas, columnas clave: `categoria_app`, `subcategoria`, `marca`, `modelo`, `descripcion`, `unidad_compra`, `moneda`, `precio_compra`, `precio_mxn`, `activo`, `revisar_precio`, `estado_para_calculo`, más columnas técnicas específicas por categoría — `potencia_w`/`voc_v`/`isc_a` para paneles, `nominal_power_w`/`max_pv_power_w`/`mppt_count`/etc. para inversores, `tipo_elemento_estructura`/`longitud_nominal_m`/`longitud_util_calculo_m` para estructura). Hoy **no existe módulo de precios para materiales de estructura/eléctrico** en la app — `lib/features/cotizaciones/domain/entities/quotation_commercial_quote.dart` solo tiene costo de panel e inversor; el BOM de estructura (rieles, ángulos, clamps, tuercas, rondanas, anclaje) calculado en Fase 4 no tiene ningún precio asociado hoy. Extender el modelo de cotización comercial para incluir línea por línea todo el material calculado (paneles, inversor, estructura, protección CD/CA, tubería, cableado), jalando precio desde el catálogo importado. Evaluar si conviene extender `lib/features/proveedores_precios/presentation/screens/proveedores_screen.dart` (ya soporta importar precios de panel/inversor vía Excel) o crear un módulo paralelo para materiales de estructura/eléctrico.
    - **Regla de precio faltante:** si un producto no tiene `precio_mxn` (o `activo = NO` / `revisar_precio = SI` / `estado_para_calculo = PENDIENTE_DEFINIR`), mostrar **"-"** en la columna de precio de la cotización en vez de omitir la línea o mostrar 0. Hoy 22 de los 161 productos del catálogo están en este estado (paneles Luxen 330W/700W, Seraphin 580W, Jinko 585W, y varios ítems de estructura pendientes de definir marca/medida).
    - **Prerrequisito de datos (resuelto):** actualizar en el catálogo las filas `PENDIENTE_LONGITUD_TRAMO`/`PENDIENTE_DEFINIR` de PTR/ángulo de acero con `longitud_nominal_m = 6`, y la fila `EST-FIJ-ANCLAJE-QUIMICO` con marca **Fester 890**, precio **$450 MXN**.

23. **La cotización debe aparecer junto con los planos (decidido: un solo PDF fusionado).** Hoy se generan **tres PDFs independientes** que nunca se combinan: cotización comercial (`generateQuotationPdf`, `pdf_service.dart:23`, desde `cotizacion_cliente_preview_screen.dart:287/303`), propuesta técnica (`generateTechnicalProposalPdf`, `pdf_service.dart:60`, desde `propuesta_tecnica_screen.dart:217/234`), y planos estructurales (`generateStructuralPdf`, `pdf_service.dart:286`, desde `estructura_screen.dart:406`). **Fusionar cotización + planos en un solo documento PDF** (usando `package:pdf`, agregando las páginas de ambos a un mismo `Document` antes de exportar/compartir). La propuesta técnica queda fuera de esta fusión salvo que el usuario pida lo contrario más adelante — confirmar alcance exacto (¿solo cotización+planos, o los tres documentos?) al iniciar esta tarea si hay duda.

---

## Decisiones confirmadas (cierre de preguntas abiertas)

Todas las preguntas abiertas de la primera versión de este prompt fueron resueltas con el usuario:

| Punto | Decisión |
|---|---|
| 2/5 — Cliente vs. Prospecto | El prospecto crea automáticamente un `Cliente` al guardarse (entidades separadas, no se fusionan). |
| 7 — Proveedor de mapas | Nominatim/OpenStreetMap (gratuito, sin API key), no Google Places. |
| 12 — Imágenes panel/inversor | Genéricas por categoría (un asset de panel, un asset de inversor), no específicas por SKU. |
| 15 — Material de ángulo | La estructura puede ser PTR de acero **o** Aluminio; ambos usan tramos de 6 m. Agregar selector de tipo de material. |
| Riel de 6 m | Confirmado: 6.00/6.01 m reales, tal como está en el catálogo (no 6.10 m — ese valor es del ángulo de aluminio). |
| Anclaje químico | Marca **Fester 890**, precio **$450 MXN** por cartucho. |
| 23 — Cotización + planos | Fusionar en un solo PDF. |
