# Solar Extractor – Extractor de Fichas Técnicas FV (v7)

Extractor profesional en Python para **analizar fichas técnicas en PDF** de
**paneles solares e inversores**, y convertirlas en **JSON estructurado**
listo para su uso en **cotizadores automáticos**, validación técnica y análisis.

Este proyecto utiliza un enfoque **híbrido**:
- Extracción de texto nativo (PDF digital)
- OCR avanzado (PDF escaneado)
- Detección visual de tablas con OpenCV
- Normalización y validación de datos técnicos

> ⚠️ El JSON es la **fuente única de verdad**.  
> CSV no se usa para cálculos, solo para validación humana si se requiere.

---

## 🚀 Funcionalidades principales

- Lectura automática de múltiples PDFs
- Soporte para PDFs digitales y escaneados
- Detección de tablas técnicas (modo visual)
- OCR por celda con Tesseract
- Extracción semántica por patrones (ES / EN)
- Separación por tipo de equipo:
  - Paneles solares
  - Inversores
- Salida estructurada en JSON:
  - valores
  - origen (tabla / texto)
  - nivel de confianza
- Manejo de errores por archivo (no se detiene el proceso)

---

## 📂 Estructura del proyecto

solar-extractor/
│
├── extract_solar_specs_v7.py
├── README.md
├── requirements.txt
│
├── PDFS/ # Carpeta de PDFs (entrada)
│
├── build/
│ ├── json_paneles/ # Salida JSON de paneles
│ ├── json_inversores/ # Salida JSON de inversores
│ ├── _tables/ # Debug visual de tablas
│ └── _debug/ # Logs del proceso
│
└── .venv/ # Entorno virtual (NO se sube a Git)




---

## ⚙️ Requisitos

- Python 3.9 o superior
- Tesseract OCR instalado en el sistema
- Librerías Python indicadas en `requirements.txt`

### Instalar dependencias

```bash
pip install -r requirements.txt

Instalar Tesseract (Windows)

https://github.com/UB-Mannheim/tesseract/wiki

Asegúrate de que tesseract.exe esté en el PATH.

Por cada PDF procesado se generan dos archivos JSON:

build/json_paneles/<archivo>.json
build/json_inversores/<archivo>.json

Ejemplo de estructura (panel)
{
  "meta": {
    "archivo": "JINKO_620",
    "tipo_equipo": "panel"
  },
  "modelos": [
    {
      "modelo": "JAM72D40-620",
      "electrico": {
        "Pmax": { "valor": 620, "origen": "tabla", "confianza": 0.95 }
      }
    }
  ]
}

🧠 Diseño del sistema
PDF → Extractor → JSON → Cotizador automático


Este extractor está pensado como etapa base de un sistema de:

cotización fotovoltaica

validación eléctrica

análisis técnico

generación de propuestas



