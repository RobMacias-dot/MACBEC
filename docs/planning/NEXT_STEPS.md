# Siguiente paso después de Fase 0

La siguiente fase pequeña y comprobable debe ser:

## Fase 1.1 — Setup admin local

Archivos a trabajar:

- `features/auth/presentation/screens/setup_admin_screen.dart`
- `features/auth/presentation/screens/login_screen.dart`
- `features/auth/application/auth_controller.dart`
- `data/local/database/app_database.dart`
- `core/security/session_storage.dart`

Objetivo:

- Crear admin local.
- Guardar usuario en SQLite.
- Guardar sesión en Secure Storage.
- Redirigir automáticamente al dashboard si ya existe sesión.
- Cerrar sesión.

No se debe implementar backend todavía.
