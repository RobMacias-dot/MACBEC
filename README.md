# MacBec Solar App

Aplicación móvil interna para **cotización, análisis técnico y gestión de proyectos fotovoltaicos en México**, desarrollada para el flujo operativo de **MacBec Soluciones en Energía**.

El objetivo del proyecto es reducir el tiempo necesario para generar cotizaciones, estandarizar cálculos técnicos, organizar expedientes y preparar la base para propuestas técnicas, contratos, pre-facturación y documentación de proyectos solares.

---

## Filosofía del proyecto

- **Simple primero.**
- **Automático después.**
- **Confiable siempre.**
- **Trabajar menos de forma innecesaria.**
- **No automatizar antes de tener una base confiable.**
- **Separar datos técnicos de cálculo y datos comerciales/precios.**

La app no busca ser únicamente una calculadora solar. El objetivo es construir una herramienta interna de operación que acompañe el proceso completo:

```text
Prospecto → Recibo CFE → Análisis energético → Selección técnica
→ Dimensionamiento eléctrico → Cotización → Propuesta/contrato → Expediente
```

---

## Estado actual del proyecto

El proyecto ya cuenta con una base funcional local-first y flujo técnico preliminar.

### Funciones implementadas

- Login local.
- Sesión persistente.
- Configuración inicial de administrador.
- Cotización provisional.
- Captura y revisión de datos de recibo CFE.
- Revisión CFE bloqueada con opción de editar.
- Análisis energético.
- Persistencia de consumos históricos.
- Persistencia de horas solares pico y potencia de panel.
- Persistencia del resultado fotovoltaico en SQLite.
- Navegación inteligente hacia la última pantalla útil.
- Catálogo local-first de paneles solares.
- CRUD de paneles.
- Búsqueda y filtros de paneles.
- Catálogo local-first de inversores.
- Importador de Excel estándar.
- Importación de paneles e inversores desde catálogo comercial.
- Detección de categorías comerciales futuras.
- Separación entre catálogo comercial y referencias técnicas.
- Selección técnica dentro del flujo de cotización.
- Selección de panel real.
- Recomendación y selección preliminar de inversor.
- Dimensionamiento eléctrico preliminar:
  - Potencia FV total.
  - Uso del inversor.
  - Reserva disponible.
  - Validación por Voc, Isc y MPPT.
  - Paneles máximos por string.
  - Paralelos máximos por MPPT.
  - Strings requeridos.
  - Fusible DC preliminar.
  - Cable DC preliminar.
  - Tubería/conduit preliminar.
  - Lado AC básico.
  - Caída de tensión preliminar.
  - Snapshot técnico preliminar copiable.
- Navegación global con botón de regreso y acceso al menú principal.

---

## Alcance técnico actual

La app trabaja con un enfoque **local-first**:

- SQLite local como fuente principal de datos.
- Drift para acceso tipado a base de datos.
- Archivos y documentos fuera de SQLite, usando metadatos cuando aplique.
- Preparada para sincronización futura, pero sin backend obligatorio en el MVP.
- OCR, CFDI real, portal web y sincronización quedan como fases posteriores.

---

## Stack principal

- **Flutter**
- **Dart**
- **Riverpod**
- **GoRouter**
- **Drift**
- **SQLite**
- **File Picker**
- **Arquitectura modular por features**

---

## Estructura general

```text
macbec_solar_app/
  lib/
    app/
      router/
      theme/
    core/
    data/
      local/
    features/
      analisis_energetico/
      auth/
      catalogo_tecnico/
      clientes/
      cotizaciones/
      dashboard/
      dimensionamiento_electrico/
      expediente/
      proveedores_precios/
      proyectos/
      recibo_cfe/
      seleccion_tecnica/
    shared/
  assets/
    branding/
    seeds/
  docs/
    planning/
    reference/
      catalogos/
      documentos_funcionales/
      pdfs/
  tools/
    solar_extractor/
```

---

## Módulos principales

### Autenticación local

Permite configurar un administrador inicial, iniciar sesión y conservar la sesión localmente.

### Cotización provisional

Permite iniciar una cotización sin obligar todavía a tener toda la información del cliente o expediente final.

### Recibo CFE

Permite capturar y revisar datos del recibo CFE. La revisión manual es importante porque el OCR o la captura automática no deben usarse sin validación humana.

### Análisis energético

Calcula consumo anual, consumo diario, generación fotovoltaica por panel y número de paneles requeridos.

### Catálogo técnico

Maneja productos técnicos y comerciales como paneles e inversores. El catálogo está preparado para crecer hacia cables, tuberías, protecciones, materiales eléctricos, estructura y mano de obra.

### Actualización de precios

Permite importar un Excel estándar de catálogo comercial. Actualmente se trabaja con paneles e inversores; el resto de categorías se detecta para fases futuras.

### Selección técnica

Permite seleccionar un panel real del catálogo y usarlo para continuar con el dimensionamiento.

### Dimensionamiento eléctrico preliminar

Calcula y muestra una base técnica inicial:

- Compatibilidad de inversores.
- Uso del inversor.
- Reserva disponible.
- Validaciones con Voc, Isc y MPPT.
- Strings.
- Fusible DC.
- Cable DC.
- Tubería DC.
- Lado AC.
- Caída de tensión.
- Snapshot técnico.

> Los cálculos eléctricos actuales son preliminares. Deben validarse contra normativas aplicables, condiciones reales de instalación, temperatura, canalización, datasheets completos y criterio final de ingeniería.

---

## Catálogos y referencias

El proyecto separa dos tipos de información:

### Catálogo comercial

Productos con precio, proveedor, marca, modelo y datos de venta.

Ejemplos:

- Panel solar.
- Inversor.
- Cable como producto comercial.
- Tubería como producto comercial.
- Fusibles.
- ITM.
- Material eléctrico.
- Accesorios de estructura.
- Mano de obra.

### Referencias técnicas

Tablas usadas para cálculo, no necesariamente como productos de venta.

Ejemplos:

- Ampacidad de cables.
- Capacidad de tuberías.
- Radiación solar.

Los archivos de referencia técnica se encuentran en:

```text
docs/reference/catalogos/
```

Ejemplos actuales:

```text
docs/reference/catalogos/Cables.xlsx
docs/reference/catalogos/Tuberias.xlsx
```

---

## Herramienta auxiliar: Solar Extractor

El proyecto puede incluir una herramienta auxiliar en Python para analizar fichas técnicas de paneles e inversores desde PDF y generar datos estructurados.

Esa herramienta debe tratarse como apoyo al catálogo técnico, no como el enfoque principal del README raíz.

Ubicación recomendada:

```text
tools/solar_extractor/
```

---

## Requisitos de desarrollo

Antes de ejecutar el proyecto, instala Flutter y verifica el entorno:

```bash
flutter doctor
```

Instala dependencias:

```bash
flutter pub get
```

Genera archivos de Drift cuando aplique:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Ejecuta la app:

```bash
flutter run
```

Analiza el proyecto:

```bash
flutter analyze
```

Formatea el código:

```bash
dart format lib
```

---

## Ruta local de desarrollo

Ruta usada durante el desarrollo en Windows:

```text
C:\Users\macia\Documents\FlutterProjects\macbec_solar_app
```

Repositorio oficial:

```text
https://github.com/RobMacias-dot/MACBEC
```

---

## Flujo funcional actual

```text
Inicio / sesión
  ↓
Dashboard
  ↓
Nueva cotización
  ↓
Recibo CFE
  ↓
Revisión CFE
  ↓
Análisis energético
  ↓
Selección técnica
  ↓
Dimensionamiento eléctrico
  ↓
Snapshot técnico preliminar
```

---

## Roadmap inmediato

Próximas fases recomendadas:

1. Guardar snapshot técnico definitivo en SQLite.
2. Conectar dimensionamiento con cotización económica.
3. Integrar precios, utilidad, IVA, mano de obra y comisión.
4. Generar propuesta técnica PDF.
5. Desarrollar módulo de estructura.
6. Conectar expediente final.
7. Preparar contratos y firma.
8. Preparar pre-factura.
9. Evaluar OCR real para recibos CFE y datasheets.
10. Preparar sincronización futura.

---

## Notas importantes

- El MVP no depende de backend.
- La app debe funcionar sin conexión.
- La información técnica debe conservar snapshots para que una cotización histórica no cambie si después se actualizan precios o datasheets.
- El cliente final no debe ver costos internos, utilidad ni márgenes comerciales.
- El CFDI real queda para una fase futura con backend/PAC.
- Los cálculos técnicos deben mantenerse auditables y revisables.

---

## Estado de estabilidad

Al cierre de la Fase 6:

```text
flutter analyze
```

debe quedar sin errores reales. Pueden existir avisos informativos como `prefer_const_constructors` o deprecaciones menores, los cuales no bloquean el funcionamiento.

---

## Licencia / uso

Proyecto interno en desarrollo para MacBec Soluciones en Energía.

No usar como cálculo eléctrico definitivo sin revisión técnica profesional.
