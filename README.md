# MACBEC — Plataforma de Herramientas para Proyectos Solares y Eléctricos

MACBEC es un conjunto de herramientas, scripts y documentación desarrollados para optimizar, automatizar y profesionalizar procesos dentro del sector de instalaciones fotovoltaicas y eléctricas. Este repositorio agrupa los módulos en constante desarrollo utilizados dentro del ecosistema MACBEC.

---

## Estructura del Proyecto

MACBEC/
│
├── solar-extractor/ # Módulo inteligente para lectura de datasheets
│ ├── extract_solar_specs_v1.py
│ ├── extract_solar_specs_v2.py
│ ├── extract_solar_specs_v3.py
│ ├── extract_solar_specs_v4.py
│ ├── extract_solar_specs_v5.py
│ ├── extract_solar_specs_v6.py
│ ├── extract_solar_specs_v7.py # Versión híbrida actual
│ ├── README.md # Documentación específica del módulo
│ └── build/ # Salidas CSV y logs (ignorado por Git)
│
├── Logos/ # Imágenes y material gráfico
├── Documentos/ # Documentos PDF, propuestas, etc.
│
└── .gitignore


---

## 🔧 Módulo principal actual: *solar-extractor*

El módulo **solar-extractor** es un sistema híbrido para la extracción automática de información técnica desde datasheets de paneles solares e inversores.

Incluye:

- OCR con Tesseract  
- Lectura nativa de PDF con PyMuPDF  
- Detección de tablas con OpenCV  
- Regex inteligente español/inglés  
- Modo híbrido (tablas + texto + OCR)  
- Corrección automática de valores  
- Exportación a CSV (`paneles.csv` e `inversores.csv`)  

Documentación del módulo:  
→ `solar-extractor/README.md`

---

## 🚀 Objetivo del repositorio

MACBEC busca centralizar:

- Flujos de trabajo automatizados  
- Scripts y herramientas internas  
- Generadores de cotizaciones  
- Extractores de datos  
- Material visual y documentación  

Todo bajo una estructura estandarizada y mantenible.

---

## 🧠 Tecnologías utilizadas

- **Python 3.x**
- PyMuPDF (fitz)
- OpenCV
- Tesseract OCR
- Pandas / NumPy
- Git y GitHub Actions *(próximamente)*
- Documentación en Markdown

---

## 📈 Futuro del proyecto

### Módulos planeados:
- 🟦 **MACBEC Web Dashboard** — Visualización de proyectos solares  
- ⚙️ **Cálculo automático de sistemas** — Inversores, paneles, cableado  
- 💲 **Cotizador inteligente** — Cálculos de energía y payback  
- 📤 **Integración API** — Envío de datos a CRM o portal web  
- 🧾 **Generador de propuestas PDF** totalmente automatizado  

### Mejoras técnicas:
- Contenedores Docker para despliegue
- Workflow CI/CD con GitHub Actions
- Tests automáticos para módulos críticos
- Uso de bases de datos SQLite / PostgreSQL

---

## 🤝 Contribuciones

Este proyecto actualmente es de uso interno.  
Sin embargo, se aceptan:

- Mejoras técnicas
- Documentación
- Nuevos módulos o scripts

Envíe un PR o abra un issue.

---

## 📄 Licencia

Este repositorio está bajo licencia **MIT**, salvo documentos comerciales privados incluidos en `/Documentos/`.



