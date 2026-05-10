# MacBec Solar — Fase 0 Starter

Este paquete contiene una base inicial para arrancar la app Flutter **MacBec Solar** con arquitectura modular, local-first y preparada para crecer.

> Importante: este paquete no fue generado con `flutter create` porque el entorno donde se preparó no tiene Flutter instalado. La forma correcta de usarlo es crear primero el proyecto Flutter y después copiar estos archivos encima.

## 1. Crear proyecto Flutter

```bash
flutter create macbec_solar_app
cd macbec_solar_app
```

## 2. Copiar archivos de este paquete

Copia el contenido de este paquete dentro de la raíz del proyecto generado por Flutter.

Debe quedar algo así:

```text
macbec_solar_app/
  pubspec.yaml
  analysis_options.yaml
  lib/
    main.dart
    app/
    core/
    data/
    features/
    shared/
```

## 3. Instalar dependencias

```bash
flutter pub get
```

## 4. Generar archivos de Drift

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 5. Ejecutar

```bash
flutter run
```

## Qué incluye esta Fase 0

- Estructura Clean Architecture modular por feature.
- `main.dart` con `ProviderScope`.
- `App` base con `GoRouter`.
- Tema visual inicial profesional.
- Pantallas placeholder del MVP.
- Base Drift/SQLite inicial.
- Tablas conceptuales base para local-first.
- `sync_queue` preparada para sincronización futura.
- Servicios vacíos/base para crecer sin romper.
- Repositorios iniciales de ejemplo.

## Qué NO incluye todavía

- Backend.
- Scraping.
- CFDI real.
- OCR activo.
- Generación real de PDFs.
- Lógica completa de cotizaciones.
- Migración real de catálogos desde Excel.

Estos puntos entran en fases posteriores.
