# Reporte de revisión Fase 0 - MacBec Solar

## Resultado de cotejo

La carpeta organizada sí contiene los recursos útiles del ZIP original: documentación funcional, PDFs de referencia, catálogos Excel, logos, semillas CSV preliminares y el extractor Python. Lo que se dejó fuera fue basura técnica o archivos no convenientes para el proyecto Flutter: `.git`, entornos virtuales `.venv`, cachés de Python/Pytest y archivos temporales.

## Correcciones aplicadas

- Se agregó `assets/branding/logo_macbec_app.png`, generado a partir del logo oficial para usarlo dentro de la app sin márgenes excesivos.
- La pantalla inicial ahora usa el logo oficial de MacBec en lugar del ícono genérico de panel solar.
- La pantalla de login también muestra el logo oficial.
- Se ajustó la paleta visual inicial para acercarse más al azul/teal del logo MacBec.
- Se corrigió `EnergyAnalysisRules.requiredPanels()`: ahora usa `.ceil()` correctamente.
- Se corrigió el conflicto entre la entidad de dominio `Client` y la clase generada por Drift.
- Se agregó `test/widget_test.dart` actualizado para evitar el error de `MyApp`.
- Se limpiaron imports no usados en pantallas placeholder.

## Estado recomendado

Esta carpeta sigue siendo Fase 0: estructura base, navegación, pantallas placeholder, base Drift inicial y assets reales. Todavía no es Fase 1 funcional. El siguiente paso es implementar Setup Admin real con SQLite y sesión local.
