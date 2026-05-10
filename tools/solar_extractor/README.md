# Solar Extractor — herramienta auxiliar

Este módulo Python se conserva como herramienta de apoyo para extraer información técnica desde fichas PDF de paneles e inversores.

## Importante

Esta herramienta **no forma parte del MVP móvil Flutter**. En el MVP, los catálogos técnicos deben cargarse manualmente o mediante semillas validadas. La extracción automática solo debe usarse como sugerencia para revisión humana.

## Instalación local

```bash
cd tools/solar_extractor
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

También necesitas Tesseract OCR instalado en el sistema.

## Uso

```bash
python extract_solar_specs.py pdfs --debug
```

## Estructura

- `extract_solar_specs.py`: versión actual limpia basada en v8.
- `archive/`: versiones históricas del extractor.
- `pdfs/`: fichas técnicas de referencia.
- `tests/`: pruebas básicas existentes.
- `build/`: carpeta de salida local, no se debe versionar con resultados pesados.
