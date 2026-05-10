# Fase 0 — Preparación técnica

## Objetivo

Dejar una base Flutter limpia, modular, local-first y preparada para MVP.

## Orden recomendado

1. Crear proyecto con `flutter create`.
2. Copiar este scaffold.
3. Ejecutar `flutter pub get`.
4. Ejecutar `dart run build_runner build --delete-conflicting-outputs`.
5. Ejecutar app.
6. Verificar navegación base.
7. Verificar creación de base local.
8. Empezar Fase 1: setup admin + login real local.

## Decisiones aplicadas

- No backend.
- No scraping.
- No CFDI real.
- No OCR obligatorio.
- SQLite/Drift como fuente de verdad local.
- `sync_queue` creada desde el inicio.
- Documentos fuera de SQLite, solo metadatos en DB.
- Cotización preparada para snapshot de precios.
