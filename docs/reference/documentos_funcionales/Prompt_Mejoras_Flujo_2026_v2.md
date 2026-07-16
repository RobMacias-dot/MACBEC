# Prompt de mejoras — Flujo cliente/cotización (v2, julio 2026)

> Sustituye a la Fase 1 de `Prompt_Mejoras_2026.md`, cuyo diagnóstico ya fue aplicado (borrado de cliente, creación automática de Cliente desde el prospecto, `lastCompletedStep` para reanudar, vista previa de recibo, holder-name por OCR). Este documento parte de una relectura del código al 2026-07-15 y del feedback de uso real del usuario. Grounded en lectura directa de archivo/línea citada en cada punto — verificar que sigan vigentes antes de implementar, ya que el código pudo moverse entre esta redacción y la ejecución.
>
> Contexto de negocio: MacBec Solar, app Flutter local-first (Riverpod + Drift) para cotizar instalaciones fotovoltaicas. Entidades relevantes: `Cliente` (`lib/features/clientes/`) 1—N `Proyecto` (`lib/features/proyectos/`, tiene `clientId`) 1—1 `QuotationDraft` (`lib/features/cotizaciones/domain/entities/quotation_draft.dart`, tiene `projectId`, no tiene `clientId` directo — hay que resolverlo vía Proyecto).
>
> **Modo de trabajo:** este es el prompt a *definir*; no ejecutar cambios de código hasta confirmar las decisiones abiertas de la sección final con el usuario.

---

## Punto 1 — Flujo continuo sin entrar/salir de la pantalla de cotización

**Hallazgo:** el avance automático entre pasos es asimétrico. Los primeros 4 módulos SÍ empujan al usuario directo al siguiente (`context.push(...)` tras guardar):
- `cotizacion_prospecto_form_screen.dart` → recibo CFE
- `recibo_cfe_screen.dart:217,352` → `AppRoutes.reciboCfeRevision`
- `recibo_cfe_revision_screen.dart:184,366,514` → `AppRoutes.analisisConsumo`

Pero a partir de "Análisis energético" el patrón cambia: `cotizacion_interna_screen.dart:70`, `seleccion_tecnica_screen.dart:44`, `dimensionamiento_electrico_screen.dart:63`, `documentos_pdf/propuesta_tecnica_screen.dart:45`, `contrato_screen.dart:47`, `prefactura_screen.dart:67` y `cotizacion_cliente_preview_screen.dart:46` solo tienen un botón de **"volver al hub"** (`context.go(AppRoutes.cotizacion)`) — el usuario tiene que regresar manualmente a `CotizacionScreen` y tocar la siguiente tarjeta de paso cada vez. Esto es justo la fricción que reporta el usuario.

**Secuencia real confirmada (verificado en código, 2026-07-15):** el hub (`cotizacion_screen.dart`) solo lista 6 pasos visibles, pero `QuotationDraftStep` (quotation_draft.dart:19-27) define 9. Se rastreó la navegación real de los 3 pasos faltantes:

`analisis_consumo_screen.dart:339` (`context.go(AppRoutes.seleccionTecnica)`) → `seleccion_tecnica_screen.dart:275` (`context.go(AppRoutes.dimensionamientoElectrico)`) → `dimensionamiento_electrico_screen.dart:430-439` (`context.push(AppRoutes.estructura, extra: StructureDesignContext(...))`) → `estructura_screen.dart` **guarda pero no navega a ningún lado** (solo snackbar "Diseño de estructura guardado.", sin `context.push`/`go` de avance) — es un callejón sin salida real, coincide exactamente con la queja del usuario. Aparte, `cotizacion_screen.dart:100` empuja a `cotizacionInterna` de forma independiente desde el hub; `cotizacion_interna_screen.dart` sí lee `structureResult`/`structureSelection` (líneas 375-376) para las líneas de materiales de estructura, así que depende de esos datos aunque no dependa de la navegación.

**Secuencia completa confirmada:** `prospect → cfeReceipt → cfeReview → energyAnalysis → technicalSelection → electricalDimensioning → structure → commercialQuote → clientPreview`.

**Tarea:** reemplazar los botones "volver al hub" de `cotizacion_interna_screen.dart:70`, `seleccion_tecnica_screen.dart:44` (ya avanza bien, revisar que sea push y no solo back-link), `dimensionamiento_electrico_screen.dart:63`, `documentos_pdf/propuesta_tecnica_screen.dart:45`, `contrato_screen.dart:47`, `prefactura_screen.dart:67`, `cotizacion_cliente_preview_screen.dart:46` por `context.push` directo a la siguiente pantalla de la secuencia confirmada arriba (mismo patrón que los primeros 4 módulos). **Prioridad alta:** cerrar el callejón sin salida de `estructura_screen.dart` — su acción de guardado debe hacer `context.push(AppRoutes.cotizacionInterna)` al terminar. El hub queda como pantalla de *resumen/reanudación* únicamente (ver Punto 5 y decisión 5 más abajo), no como parada obligatoria entre cada paso.

---

## Punto 2 — "Guardar y continuar cotización" en datos mínimos del prospecto → recibo CFE

**Hallazgo:** `cotizacion_prospecto_form_screen.dart`, método `_saveProspect()` (líneas 67-157) ya crea Cliente + Proyecto + QuotationDraft (85-113) y marca `lastCompletedStep = prospect` (115-118), pero al terminar hace `pop()` o `context.go(AppRoutes.cotizacion)` (137-141) — regresa al hub, no avanza. Existe un botón "Guardar pendiente de recibo CFE" (label línea 256) pero no lleva directo a la pantalla de recibo.

**Tarea:** cambiar la navegación post-guardado de `_saveProspect()` para hacer `context.push(AppRoutes.reciboCfe)` (o `pushReplacement` si no se quiere permitir volver atrás al formulario ya guardado) en vez de volver al hub.

**Decidido:** renombrar el botón a **"Guardar y continuar"** (línea 256) — el texto actual "Guardar pendiente de recibo CFE" asumía que el siguiente paso quedaba pendiente para después; ahora avanza directo.

---

## Punto 3 — Botón manual de OCR en "Revisión CFE"

**Hallazgo:** hoy el OCR corre automáticamente al capturar/cargar el recibo, dentro de `recibo_cfe_screen.dart`, método `_runOcrSuggestion()` (líneas 396-434), invocado desde `_captureReceiptWithCamera()` (137-228) y `_saveReceiptFile()` (297-363). El resultado se guarda en `cfeOcrSuggestionProvider` y `recibo_cfe_revision_screen.dart._prefillFormIfNeeded()` (400-461) lo consume para rellenar los campos vacíos, incluido el titular (419-421, ya implementado — el punto 10 del prompt viejo quedó resuelto). **No existe ningún botón manual** en la pantalla de revisión; la extracción es "disparar y olvidar" en el momento de la captura.

**Tarea:** agregar un botón "Obtener información" en `recibo_cfe_revision_screen.dart` que vuelva a ejecutar la extracción (reusar la lógica de `_runOcrSuggestion`, hoy privada a `recibo_cfe_screen.dart` — conviene moverla a un servicio/controlador compartido, p. ej. dentro de `ocrServiceProvider` o un nuevo `CfeOcrController`) sobre el documento ya guardado (`draft.cfeReceiptDocumentId`), y volver a rellenar los campos vacíos del formulario con el resultado. Mostrar el mismo indicador de progreso que ya existe en `recibo_cfe_screen.dart:115-128` mientras corre.

**Decidido:** el botón manual **coexiste** con el auto-OCR al capturar (no lo reemplaza) — cubre el caso de reintento/draft viejo sin sugerencia.

**Motor OCR — confirmado, no cambiar:** el proyecto ya usa `google_mlkit_text_recognition` (on-device, sin nube) en vez de Tesseract — es la mejor opción disponible para este caso (fotos de campo con ángulo/sombra, arquitectura local-first, sin costo). El punto de apalancamiento para mejorar la efectividad **no es el motor**, sino: (a) preprocesar la imagen antes de mandarla a ML Kit (recorte al área del recibo, contraste, deskear) y (b) seguir afinando los regex de `cfe_receipt_text_parser.dart` contra recibos reales. Si se quiere abordar (a), agregar un paso de preprocesamiento en `OcrService.extractTextDraft` (`ocr_service.dart:21-34`) antes de `TextRecognizer.processImage`.

**Decidido — regla de revisión manual:** el comentario "regla permanente" en `ocr_service.dart:17-19` (los datos de OCR nunca alimentan cálculos ni se guardan directo, siempre pasan por revisión editable en `recibo_cfe_revision_screen.dart`) **se mantiene sin cambios**. "Que siempre lea y coloque los valores automáticamente" significa: autofill más completo/agresivo de los campos del formulario de revisión (Punto 3), no eliminar el paso de confirmación del usuario — un dígito mal leído en kWh o total a pagar sí impacta cálculos de la cotización, así que la validación manual se queda como salvaguarda.

---

## Punto 4 — Botón "Continuar cotización" en tarjeta de cliente incompleto

**Hallazgo:** `clientes_screen.dart` (`_ClientCard`, líneas 72-153) no tiene ninguna noción de cliente "incompleto" ni acción de continuar cotización — solo nombre/contacto/dirección y borrar. Toda la lógica de reanudación ya existe pero vive en el hub de cotización: `cotizacion_screen.dart`, sección "Prospectos pendientes" (119-170, `_DraftCard` en 299-426), `onSelectDraft` (143-166) y `_routeForCompletedStep` (207-229, traduce `lastCompletedStep` a la ruta correcta).

**Tarea:** en `_ClientCard`, resolver si el cliente tiene un `QuotationDraft` activo sin terminar (vía `Proyecto.clientId` → `projectId` → `QuotationDraft`, cruce que hoy no existe en ningún repositorio — probablemente agregar un método tipo `quotationDraftRepository.findActiveByClientId(clientId)` o extender `clientsControllerProvider` para incluir el draft asociado). Si existe, mostrar un botón "Continuar cotización" en la tarjeta que reutilice la misma lógica de `_routeForCompletedStep` para navegar directo al paso correcto (mover esa función a un lugar compartido, p. ej. `lib/features/cotizaciones/application/quotation_draft_navigation.dart`, para no duplicarla entre `cotizacion_screen.dart` y `clientes_screen.dart`).

---

## Punto 5 — Separar "Nueva cotización" de "Prospectos pendientes"; simplificar el hub de cotización

**Hallazgo A (entrada "Nueva cotización"):** el botón vive en el dashboard (`dashboard_screen.dart:27-37`), resetea `activeQuotationDraftIdProvider`/`quotationDraftProspectProvider` y navega a `AppRoutes.cotizacion` (el hub), no directo al formulario de prospecto — el usuario ve el hub con la lista de 6 pasos (todos bloqueados salvo el 1) más la sección de prospectos pendientes debajo, lo cual el usuario describe como confuso.

**Hallazgo B (bloqueo de pasos):** `cotizacion_screen.dart`, `_FlowStepCard` (428-522) muestra `lock_outline` cuando `onTap` es `null`, pero el único gate real es un booleano `hasProspect` (línea 21, calculado 62-113) — en cuanto existe *cualquier* prospecto guardado, los pasos 2-6 se muestran todos como "Disponible" sin validar que el paso anterior esté realmente completo. Es decir, el candado visual no refleja una regla de negocio real más allá del primer paso — coincide con el reclamo del usuario de que "ya no sirve poner el estado de pendiente bloqueado".

**Hallazgo C (prospectos pendientes):** la sección vive en `cotizacion_screen.dart:119-170,299-426` (`_DraftsListView`/`_DraftCard`), alimentada por `quotationDraftsControllerProvider.getAllActive()`, con `_statusText` (406-425) para el chip de estado.

**Tareas:**
1. Cambiar el botón "Nueva cotización" del dashboard (`dashboard_screen.dart:27-37`) para navegar directo a `AppRoutes.cotizacionProspectoForm` (no al hub) — "Nueva cotización" pasa a significar exclusivamente "dar de alta un cliente/prospecto nuevo y arrancar su flujo". **Decidido:** el hub (`AppRoutes.cotizacion`) deja de ser una ruta de menú visitable en cualquier momento — solo se llega a él automáticamente al reanudar un draft activo (p. ej. desde "Continuar cotización" en Clientes, Punto 4, o al terminar de guardar un paso). Quitar cualquier entrada de menú/dashboard que apunte al hub sin un draft ya seleccionado.
2. Quitar la sección "Prospectos pendientes" completa de `cotizacion_screen.dart` (119-170, 299-426, `onSelectDraft` 143-166, `_nextRouteForDraft` 176-202) y trasladar esa función a `ClientesScreen`, como **3 pestañas: "Sin cotización" / "Pendiente" / "Completa"** (ver decisión 4 resuelta más abajo para el criterio exacto de cada una). El botón "Continuar cotización" del Punto 4 cubre la reanudación puntual por tarjeta; las pestañas cubren la vista general y el filtrado.
3. Rediseñar `_FlowStepCard`/la lista de pasos del hub: quitar el candado binario basado solo en `hasProspect` y sustituirlo por un indicador de progreso más simple y honesto — p. ej. estado por paso (`Completado` / `Actual` / `Próximo`) sin bloquear el tap (dejar que el usuario navegue libremente entre pasos ya alcanzados, ya que la validación real de datos falta ya ocurre dentro de cada pantalla). El hub queda como resumen del draft activo únicamente — ya no muestra otros drafts.

---

## Decisiones — todas resueltas (2026-07-15)

| # | Pregunta | Resolución |
|---|---|---|
| 1 | Secuencia real de los 9 `QuotationDraftStep`. | **Verificado en código:** `prospect → cfeReceipt → cfeReview → energyAnalysis → technicalSelection → electricalDimensioning → structure → commercialQuote → clientPreview`. Bug encontrado de paso: `estructura_screen.dart` no avanza a ningún lado tras guardar — prioridad alta en Punto 1. |
| 2 | Nombre del botón del Punto 2. | **"Guardar y continuar"** (reemplaza "Guardar pendiente de recibo CFE"). |
| 3 | Botón manual de OCR: ¿coexiste o reemplaza? ¿Se mantiene la revisión manual? ¿Cambiar de motor OCR? | **Coexiste** con el auto-OCR al capturar. Motor se queda en **Google ML Kit** (ya implementado, mejor que Tesseract para este caso — offline, mejor con fotos de campo). **Revisión manual se mantiene** como salvaguarda: el autofill se vuelve más completo, pero el usuario sigue confirmando antes de que alimente cálculos de la cotización. |
| 4 | Criterio de pestañas en Clientes. | **3 pestañas: "Sin cotización" / "Pendiente" / "Completa"**. Sin cotización = cliente sin ningún `QuotationDraft`. Pendiente = tiene un `QuotationDraft` activo con `lastCompletedStep` antes de `clientPreview`. Completa = draft con `lastCompletedStep = clientPreview` (o equivalente a cotización finalizada). |
| 5 | ¿El hub de cotización sigue siendo ruta de menú siempre visitable? | **No** — solo se llega a él automáticamente al reanudar un draft activo (desde "Continuar cotización" en Clientes, o al completar un paso). "Nueva cotización" ya no pasa por ahí; va directo al formulario de prospecto. |

Con esto el prompt queda **listo para ejecutar** — no quedan decisiones abiertas sobre el flujo de clientes/cotización. La importación del nuevo catálogo (nota al final) sigue pendiente de confirmar por separado si se incluye en el mismo trabajo.

---

## Nota aparte — catálogo de precios

El usuario adjuntó una nueva plantilla de catálogo (`Catalogo_MacBec_Profesional_Enerpoint_Junio_2026.xlsx`, hoja `Catalogo_Productos`: 389 filas × 45 columnas — mismas columnas que la plantilla anterior de 161 filas referenciada en `Prompt_Mejoras_2026.md`, más hojas nuevas `Resumen_Analisis`, `Fuentes_Datasheets`, `Revision_Estructura`, `Parametros_Calculo`, `Control_Calidad_Tecnica`). No se incluye en este prompt porque los 5 puntos pedidos son de flujo/UX, no de catálogo — si se quiere abordar la importación de esta plantilla (Fase 6 del prompt viejo, item 22) como parte del mismo trabajo o por separado, confirmarlo aparte.
