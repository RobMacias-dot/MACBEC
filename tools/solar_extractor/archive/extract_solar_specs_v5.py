import os
import re
import csv
import sys
from dataclasses import dataclass, asdict
from typing import Optional, List, Dict

import pdfplumber
from pdf2image import convert_from_path
import pytesseract
from pytesseract import Output
from PIL import Image

# ============================================================
#  Helpers numéricos
# ============================================================

def normalizar_numero(num_str: str) -> Optional[float]:
    """
    Convierte '37.1', '37,1', '1.234,56', '1 234,56', '50V', '50.0%' → float.
    """
    if not num_str:
        return None
    s = num_str.strip()
    # Quitar letras típicas (V, A, W, %, etc.)
    s = re.sub(r'[^\d,.\-]', '', s)

    if not s:
        return None

    # Caso de separador europeo: 1.234,56
    # Si hay ',' y '.' y la ',' está después del '.', interpretamos ',' como decimal.
    if ',' in s and '.' in s:
        if s.rfind(',') > s.rfind('.'):
            s = s.replace('.', '')
            s = s.replace(',', '.')
        else:
            # Caso más raro, lo tomamos como decimal inglés
            s = s.replace(',', '')
    else:
        # Si solo hay ',' lo tomamos como decimal
        if ',' in s and '.' not in s:
            s = s.replace(',', '.')

    try:
        return float(s)
    except ValueError:
        return None


# ============================================================
#  Regex por campo (similar a tu v4)
# ============================================================

REGEX_PATTERNS_PANEL: Dict[str, List[re.Pattern]] = {
    "potencia_nominal_W": [
        re.compile(
            r"potencia\s*(?:m[aá]xima|nominal|pico)(?:\s*de\s*salida)?[^\d]{0,15}"
            r"(\d{2,4}(?:[.,]\d+)?)\s*(?:k?w|wp)?\b",
            re.IGNORECASE
        ),
        re.compile(
            r"\bP\s*M?A?X\b[^\d]{0,10}"
            r"(\d{2,4}(?:[.,]\d+)?)\s*(?:k?w|wp)?\b",
            re.IGNORECASE
        ),
        re.compile(
            r"\bPM[Pp]\b[^\d]{0,10}"
            r"(\d{2,4}(?:[.,]\d+)?)\s*(?:k?w|wp)?\b",
            re.IGNORECASE
        ),
        re.compile(
            r"(?:rated|maximum|nominal|peak)\s*(?:module\s*)?power[^\d]{0,15}"
            r"(\d{2,4}(?:[.,]\d+)?)\s*(?:k?w|wp)?\b",
            re.IGNORECASE
        ),
    ],
    "Voc_V": [
        re.compile(
            r"voltaje\s*en\s*circuito\s*abierto.*?(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"\bVoc\b[^0-9]{0,10}(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE
        ),
        re.compile(
            r"open[-\s]*circuit\s*voltage.*?(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE | re.DOTALL
        ),
    ],
    "Isc_A": [
        re.compile(
            r"intensidad\s*de\s*corto\s*circuito.*?(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"\bIsc\b[^0-9]{0,10}(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE
        ),
        re.compile(
            r"(?:short|corto)[-\s]*circuit\s*current.*?(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE | re.DOTALL
        ),
    ],
    "Vmp_V": [
        re.compile(
            r"voltaje\s*a\s*potencia\s*m[aá]xima.*?(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"\bVmp\b[^0-9]{0,10}(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE
        ),
        re.compile(
            r"maximum\s*power\s*voltage.*?(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"voltage\s+at\s+pmax.*?(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE | re.DOTALL
        ),
    ],
    "Imp_A": [
        re.compile(
            r"intensidad\s*a\s*potencia\s*m[aá]xima.*?(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"\bImp\b[^0-9]{0,10}(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE
        ),
        re.compile(
            r"maximum\s*power\s*current.*?(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"current\s+at\s+pmax.*?(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE | re.DOTALL
        ),
    ],
    "peso_kg": [
        re.compile(r"peso[^\d]{0,10}([0-9.,]+)\s*kg", re.IGNORECASE),
        re.compile(r"weight[^\d]{0,10}([0-9.,]+)\s*kg", re.IGNORECASE),
    ],
    "tension_sistema_max_V": [
        re.compile(
            r"(?:max\.?\s*)?system\s*voltage[^\d]{0,12}"
            r"(\d{2,4}(?:[.,]\d+)?)\s*v\b",
            re.IGNORECASE
        ),
        re.compile(
            r"tensi[oó]n\s*de\s*sistema\s*m[aá]x[^\d]{0,12}"
            r"(\d{2,4}(?:[.,]\d+)?)\s*v\b",
            re.IGNORECASE
        ),
    ],
    "coef_temp_Voc_pct_C": [
        re.compile(
            r"coeficiente\s*de\s*temperatura\s*voc.*?([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"temp(?:erature)?\s*coef(?:ficient)?\s*(?:of\s*)?voc.*?"
            r"([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c?",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"temp\.?\s*coeff\.?\s*(?:of\s*)?voc.*?"
            r"([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c?",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"TK\s*Voc[^\d\-+]{0,10}"
            r"([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c?",
            re.IGNORECASE
        ),
    ],
    "coef_temp_Pmax_pct_C": [
        re.compile(
            r"coeficiente\s*de\s*temperatura\s*pmax.*?([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"temp(?:erature)?\s*coef(?:ficient)?\s*(?:of\s*)?pmax.*?"
            r"([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c?",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"temp\.?\s*coeff\.?\s*(?:of\s*)?pmax.*?"
            r"([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c?",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"TK\s*Pmax[^\d\-+]{0,10}"
            r"([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c?",
            re.IGNORECASE
        ),
    ],
    "ip_rating": [
        re.compile(r"\bIP\d{2}\b", re.IGNORECASE),
    ],
}

REGEX_PATTERNS_INV: Dict[str, List[re.Pattern]] = {
    "potencia_AC_nominal_W": [
        re.compile(
            r"potencia\s*nominal\s*(?:de\s*salida|de\s*ca)?[^\d]{0,15}"
            r"(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b",
            re.IGNORECASE
        ),
        re.compile(
            r"potencia\s*nominal\s*de\s*ca.*?(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"(?:rated|nominal)\s*ac\s*(?:output\s*)?power[^\d]{0,15}"
            r"(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b",
            re.IGNORECASE
        ),
    ],
    "potencia_AC_max_W": [
        re.compile(
            r"potencia\s*ac\s*m[aá]x[^\d]{0,15}"
            r"(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b",
            re.IGNORECASE
        ),
        re.compile(
            r"(?:max(?:imum)?\s*)?ac\s*power[^\d]{0,15}"
            r"(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b",
            re.IGNORECASE
        ),
        re.compile(
            r"potencia\s*aparente\s*m[aá]xima[^\d]{0,15}"
            r"(\d{2,6}(?:[.,]\d+)?)\s*kva\b",
            re.IGNORECASE
        ),
    ],
    "cantidad_mppt": [
        re.compile(
            r"(?:no\.?|number\s*of|cantidad\s*de|n[uú]mero\s*de)\s*mppt(?:s)?[^\d]{0,12}"
            r"(\d{1,2})",
            re.IGNORECASE
        ),
        re.compile(
            r"\bmppt[^0-9]{0,5}(\d{1,2})\b",
            re.IGNORECASE
        ),
        re.compile(
            r"\b(\d{1,2})\s*/\s*\d{1,2}\b"
        ),
    ],
    "Vdc_max_V": [
        re.compile(
            r"voltaje\s*m[aá]ximo\s*de\s*entrada[^\d]{0,20}"
            r"(\d{3,4}(?:[.,]\d+)?)",
            re.IGNORECASE
        ),
        re.compile(
            r"voltaje\s*m[aá]ximo\s*cd[^\d]{0,20}(\d{3,4}(?:[.,]\d+)?)",
            re.IGNORECASE
        ),
        re.compile(
            r"m[aá]ximo\s*voltaje\s*cd[^\d]{0,20}(\d{3,4}(?:[.,]\d+)?)",
            re.IGNORECASE
        ),
        re.compile(
            r"(?:max(?:imum)?\s*)?dc\s*(?:input\s*)?voltage[^\d]{0,20}"
            r"(\d{3,4}(?:[.,]\d+)?)",
            re.IGNORECASE
        ),
        re.compile(
            r"tensi[oó]n\s*m[aá]xima\s*de\s*cc[^\d]{0,40}"
            r"(\d{3,4}(?:[.,]\d+)?)\s*v",
            re.IGNORECASE
        ),
        re.compile(
            r"ucc[, ]*max[^\d]{0,20}(\d{3,4}(?:[.,]\d+)?)\s*v",
            re.IGNORECASE
        ),
    ],
    "isc_max_por_mppt_A": [
        re.compile(
            r"corriente\s*m[aá]xima\s*de\s*corto\s*circuito.*?"
            r"(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"(?:short|corto)[-\s]*circuit\s*current.*?"
            r"(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE | re.DOTALL
        ),
    ],
    "corriente_AC_max_A": [
        re.compile(
            r"corriente\s*m[aá]xima\s*de\s*salida[^\d]{0,20}"
            r"(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE
        ),
        re.compile(
            r"corriente\s*nominal\s*de\s*ca[^\d]{0,20}"
            r"(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE
        ),
        re.compile(
            r"(?:max(?:imum)?\s*)?output\s*current[^\d]{0,20}"
            r"(\d{1,3}(?:[.,]\d+)?)",
            re.IGNORECASE
        ),
    ],
    "frecuencia_Hz": [
        re.compile(
            r"frecuencia\s*nominal[^\d]{0,12}(\d{2,3}(?:[.,]\d+)?)\s*hz\b",
            re.IGNORECASE
        ),
        re.compile(
            r"(?:nominal\s*)?frequen(?:cy|cia)[^\d]{0,12}"
            r"(\d{2,3}(?:[.,]\d+)?)\s*hz\b",
            re.IGNORECASE
        ),
        re.compile(
            r"frequen(?:cy|cia)[^\d]{0,40}"
            r"(\d{2,3}(?:[.,]\d+)?)\s*hz\b",
            re.IGNORECASE
        ),
    ],
    "eficiencia_max_pct": [
        re.compile(
            r"eficiencia\s*m[aá]xima[^\d]{0,12}(\d{1,2}(?:[.,]\d+)?)\s*%\b",
            re.IGNORECASE
        ),
        re.compile(
            r"(?:max(?:imum)?\s*)?efficiency[^\d]{0,12}"
            r"(\d{1,2}(?:[.,]\d+)?)\s*%\b",
            re.IGNORECASE
        ),
    ],
    "eficiencia_CEC_pct": [
        re.compile(
            r"eficiencia\s*eu(?:ropea)?[^\d]{0,12}"
            r"(\d{1,2}(?:[.,]\d+)?)\s*%\b",
            re.IGNORECASE
        ),
        re.compile(
            r"cec\s*efficiency[^\d]{0,12}"
            r"(\d{1,2}(?:[.,]\d+)?)\s*%\b",
            re.IGNORECASE
        ),
    ],
    "pf_rango": [
        re.compile(
            r"factor\s*de\s*potencia[^:]*:\s*([0-9>.<=()\s\-a,]+)",
            re.IGNORECASE
        ),
        re.compile(
            r"power\s*factor\s*range[^:]*:\s*([0-9>.<=()\s\-a,]+)",
            re.IGNORECASE
        ),
        re.compile(
            r"factor\s*de\s*potencia[^\d]{0,40}([0-9.,]+)",
            re.IGNORECASE
        ),
        re.compile(
            r"cos\s*[φphi]+\s*[≥>=]\s*([0-9.,]+)",
            re.IGNORECASE
        ),
    ],
    "ip_rating": [
        re.compile(r"\bIP\d{2}\b", re.IGNORECASE),
    ],
    "peso_kg": [
        re.compile(r"peso[^\d]{0,10}([0-9.,]+)\s*kg", re.IGNORECASE),
        re.compile(r"weight[^\d]{0,10}([0-9.,]+)\s*kg", re.IGNORECASE),
    ],
}


# ============================================================
#  Dataclasses
# ============================================================

@dataclass
class PanelSpecs:
    filename: str
    potencia_nominal_W: Optional[float] = None
    Voc_V: Optional[float] = None
    Isc_A: Optional[float] = None
    Vmp_V: Optional[float] = None
    Imp_A: Optional[float] = None
    peso_kg: Optional[float] = None
    tension_sistema_max_V: Optional[float] = None
    coef_temp_Voc_pct_C: Optional[float] = None
    coef_temp_Pmax_pct_C: Optional[float] = None
    ip_rating: Optional[str] = None


@dataclass
class InverterSpecs:
    filename: str
    potencia_AC_nominal_W: Optional[float] = None
    potencia_AC_max_W: Optional[float] = None
    cantidad_mppt: Optional[float] = None
    Vdc_max_V: Optional[float] = None
    isc_max_por_mppt_A: Optional[float] = None
    corriente_AC_max_A: Optional[float] = None
    frecuencia_Hz: Optional[float] = None
    eficiencia_max_pct: Optional[float] = None
    eficiencia_CEC_pct: Optional[float] = None
    pf_rango: Optional[str] = None
    ip_rating: Optional[str] = None
    peso_kg: Optional[float] = None


# ============================================================
#  OCR por líneas (fallback visual tipo tabla)
# ============================================================

def ocr_text_by_lines(pdf_path: str, dpi: int = 300) -> str:
    """
    Convierte cada página a imagen, usa pytesseract.image_to_data para
    obtener palabras con coordenadas, agrupa por línea y construye un texto
    ordenado visualmente (ideal para tablas).
    """
    print(f"[DEBUG][OCR] Iniciando OCR por líneas para: {os.path.basename(pdf_path)}")
    pages = convert_from_path(pdf_path, dpi=dpi)
    all_lines = []

    for page_index, page_img in enumerate(pages):
        data = pytesseract.image_to_data(page_img, output_type=Output.DICT, lang="eng+spa")
        n = len(data["text"])

        # (block_num, par_num, line_num, page_index) → list of (x, text)
        line_map: Dict[tuple, List[tuple]] = {}
        for i in range(n):
            text = data["text"][i]
            if not text or text.isspace():
                continue
            x = data["left"][i]
            block = data["block_num"][i]
            par = data["par_num"][i]
            line = data["line_num"][i]
            key = (page_index, block, par, line)
            line_map.setdefault(key, []).append((x, text))

        for key in sorted(line_map.keys()):
            words = sorted(line_map[key], key=lambda t: t[0])
            line_txt = " ".join(w for _, w in words)
            all_lines.append(line_txt)

    result_text = "\n".join(all_lines)
    print(f"[DEBUG][OCR] OCR por líneas completado. Líneas: {len(all_lines)}")
    return result_text


# ============================================================
#  Extracción de texto nativo
# ============================================================

def extract_text_native(pdf_path: str) -> str:
    print(f"[DEBUG][PDF] Extrayendo texto nativo de: {os.path.basename(pdf_path)}")
    texts = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            txt = page.extract_text() or ""
            texts.append(txt)
    full_text = "\n".join(texts)
    print(f"[DEBUG][PDF] Texto nativo extraído. Longitud: {len(full_text)} chars")
    return full_text


# ============================================================
#  Búsqueda genérica por regex
# ============================================================

def buscar_campo_regex(
    campo: str,
    text: str,
    patterns: List[re.Pattern],
    allow_string: bool = False
) -> Optional[float | str]:
    print(f"[DEBUG][REGEX] Campo: {campo}")
    print("Probando patrones:")
    for idx, pat in enumerate(patterns, start=1):
        m = pat.search(text)
        if m:
            # Si el patrón no tiene grupo 1, tomar el match completo
            if m.groups():
                g = m.group(1).strip()
            else:
                g = m.group(0).strip()

            
            if allow_string:
                print(f"   ✔️ Patrón {idx}: {pat.pattern[:60]}... → MATCH = {g}")
                return g
            else:
                val = normalizar_numero(g)
                if val is not None:
                    print(f"   ✔️ Patrón {idx}: {pat.pattern[:60]}... → MATCH = {g}")
                    return val
                else:
                    print(f"   ⚠️ Patrón {idx}: {pat.pattern[:60]}... → coincide pero no se pudo convertir ({g})")
        else:
            print(f"   ❌ Patrón {idx}: {pat.pattern[:60]}... → no coincide")
    print("Resultado final: no se encontró coincidencia.\n")
    return None


# ============================================================
#  Clasificación panel / inversor
# ============================================================

def es_inversor(text: str, filename: str) -> bool:
    t = text.lower()
    if "inversor" in t or "inverter" in t:
        return True
    if "grid-tied" in t or "utility-interactive" in t:
        return True
    if "mppt" in t and "ac" in t:
        return True
    # Si el nombre del archivo sugiere inversor
    if re.search(r"\b(min|solis|growatt|fronius|tl-x2|inverter)\b", filename.lower()):
        return True
    return False


def es_panel(text: str, filename: str) -> bool:
    t = text.lower()
    if "module" in t or "panel" in t or "módulo" in t:
        return True
    if "stc" in t and ("isc" in t or "voc" in t or "vmp" in t):
        return True
    if re.search(r"\b(jinko|ja solar|trinasolar|canadian|longi|jingang|jst)\b", filename.lower()):
        return True
    return False


# ============================================================
#  Extracción por tipo de equipo
# ============================================================

def extraer_panel(text: str, filename: str) -> PanelSpecs:
    spec = PanelSpecs(filename=filename)

    spec.potencia_nominal_W = buscar_campo_regex(
        "Pmax / Potencia Panel",
        text,
        REGEX_PATTERNS_PANEL["potencia_nominal_W"]
    )
    spec.Voc_V = buscar_campo_regex("Voc", text, REGEX_PATTERNS_PANEL["Voc_V"])
    spec.Isc_A = buscar_campo_regex("Isc", text, REGEX_PATTERNS_PANEL["Isc_A"])
    spec.Vmp_V = buscar_campo_regex("Vmp", text, REGEX_PATTERNS_PANEL["Vmp_V"])
    spec.Imp_A = buscar_campo_regex("Imp", text, REGEX_PATTERNS_PANEL["Imp_A"])
    spec.peso_kg = buscar_campo_regex("Peso", text, REGEX_PATTERNS_PANEL["peso_kg"])
    spec.tension_sistema_max_V = buscar_campo_regex(
        "Tensión sistema máx",
        text,
        REGEX_PATTERNS_PANEL["tension_sistema_max_V"]
    )
    spec.coef_temp_Voc_pct_C = buscar_campo_regex(
        "Coef. temp Voc",
        text,
        REGEX_PATTERNS_PANEL["coef_temp_Voc_pct_C"]
    )
    spec.coef_temp_Pmax_pct_C = buscar_campo_regex(
        "Coef. temp Pmax",
        text,
        REGEX_PATTERNS_PANEL["coef_temp_Pmax_pct_C"]
    )
    # IP rating como string
    spec.ip_rating = buscar_campo_regex(
        "IP (panel)",
        text,
        REGEX_PATTERNS_PANEL["ip_rating"],
        allow_string=True
    )
    return spec


def extraer_inversor(text: str, filename: str) -> InverterSpecs:
    spec = InverterSpecs(filename=filename)

    spec.potencia_AC_nominal_W = buscar_campo_regex(
        "Potencia AC Nominal",
        text,
        REGEX_PATTERNS_INV["potencia_AC_nominal_W"]
    )
    spec.potencia_AC_max_W = buscar_campo_regex(
        "Potencia AC Máxima",
        text,
        REGEX_PATTERNS_INV["potencia_AC_max_W"]
    )
    spec.cantidad_mppt = buscar_campo_regex(
        "Cantidad MPPT",
        text,
        REGEX_PATTERNS_INV["cantidad_mppt"]
    )
    spec.Vdc_max_V = buscar_campo_regex(
        "Vdc Máximo",
        text,
        REGEX_PATTERNS_INV["Vdc_max_V"]
    )
    spec.isc_max_por_mppt_A = buscar_campo_regex(
        "Isc por MPPT",
        text,
        REGEX_PATTERNS_INV["isc_max_por_mppt_A"]
    )
    spec.corriente_AC_max_A = buscar_campo_regex(
        "Corriente AC Máxima",
        text,
        REGEX_PATTERNS_INV["corriente_AC_max_A"]
    )
    spec.frecuencia_Hz = buscar_campo_regex(
        "Frecuencia",
        text,
        REGEX_PATTERNS_INV["frecuencia_Hz"]
    )
    spec.eficiencia_max_pct = buscar_campo_regex(
        "Eficiencia Máx",
        text,
        REGEX_PATTERNS_INV["eficiencia_max_pct"]
    )
    spec.eficiencia_CEC_pct = buscar_campo_regex(
        "Eficiencia CEC/Euro",
        text,
        REGEX_PATTERNS_INV["eficiencia_CEC_pct"]
    )
    spec.pf_rango = buscar_campo_regex(
        "Rango PF",
        text,
        REGEX_PATTERNS_INV["pf_rango"],
        allow_string=True
    )
    spec.ip_rating = buscar_campo_regex(
        "IP (inversor)",
        text,
        REGEX_PATTERNS_INV["ip_rating"],
        allow_string=True
    )
    spec.peso_kg = buscar_campo_regex(
        "Peso (inversor)",
        text,
        REGEX_PATTERNS_INV["peso_kg"]
    )

    return spec


# ============================================================
#  Pipeline principal por archivo (V5 con fallback OCR visual)
# ============================================================

def procesar_pdf(pdf_path: str) -> tuple[Optional[PanelSpecs], Optional[InverterSpecs]]:
    fname = os.path.basename(pdf_path)
    print("=" * 70)
    print(f"[INFO] Procesando: {fname}")

    # 1) Texto nativo
    text_native = extract_text_native(pdf_path)

    # 2) Clasificación preliminar
    panel_flag = es_panel(text_native, fname)
    inversor_flag = es_inversor(text_native, fname)

    # 3) Extracción inicial (texto nativo)
    panel_specs = None
    inversor_specs = None

    if panel_flag and not inversor_flag:
        print(f"[DEBUG] Clasificación inicial: PANEL (por texto/filename)")
        panel_specs = extraer_panel(text_native, fname)
    elif inversor_flag and not panel_flag:
        print(f"[DEBUG] Clasificación inicial: INVERSOR (por texto/filename)")
        inversor_specs = extraer_inversor(text_native, fname)
    else:
        # Ambiguo, decidir por presencia de Voc/Isc/Vmp/Imp vs AC/mppt
        if any(k in text_native.lower() for k in ["voc", "isc", "vmp", "imp", "stc"]):
            print(f"[DEBUG] Clasificación inicial ambigua → PANEL por heurística")
            panel_specs = extraer_panel(text_native, fname)
        else:
            print(f"[DEBUG] Clasificación inicial ambigua → INVERSOR por heurística")
            inversor_specs = extraer_inversor(text_native, fname)

    # 4) Fallback OCR por líneas SOLO para campos críticos faltantes
    usar_ocr = False
    if panel_specs:
        if (panel_specs.potencia_nominal_W is None or
            panel_specs.Voc_V is None or
            panel_specs.Isc_A is None or
            panel_specs.Vmp_V is None or
            panel_specs.Imp_A is None):
            usar_ocr = True

    if inversor_specs:
        if (inversor_specs.potencia_AC_nominal_W is None or
            inversor_specs.Vdc_max_V is None or
            inversor_specs.corriente_AC_max_A is None or
            inversor_specs.cantidad_mppt is None):
            usar_ocr = True

    if usar_ocr:
        print(f"[DEBUG][FALLBACK] Activando OCR por líneas para: {fname}")
        text_ocr_lines = ocr_text_by_lines(pdf_path)

        if panel_specs:
            # Solo reintentar los campos faltantes
            if panel_specs.potencia_nominal_W is None:
                panel_specs.potencia_nominal_W = buscar_campo_regex(
                    "Pmax / Potencia Panel [OCR]",
                    text_ocr_lines,
                    REGEX_PATTERNS_PANEL["potencia_nominal_W"]
                )
            if panel_specs.Voc_V is None:
                panel_specs.Voc_V = buscar_campo_regex(
                    "Voc [OCR]",
                    text_ocr_lines,
                    REGEX_PATTERNS_PANEL["Voc_V"]
                )
            if panel_specs.Isc_A is None:
                panel_specs.Isc_A = buscar_campo_regex(
                    "Isc [OCR]",
                    text_ocr_lines,
                    REGEX_PATTERNS_PANEL["Isc_A"]
                )
            if panel_specs.Vmp_V is None:
                panel_specs.Vmp_V = buscar_campo_regex(
                    "Vmp [OCR]",
                    text_ocr_lines,
                    REGEX_PATTERNS_PANEL["Vmp_V"]
                )
            if panel_specs.Imp_A is None:
                panel_specs.Imp_A = buscar_campo_regex(
                    "Imp [OCR]",
                    text_ocr_lines,
                    REGEX_PATTERNS_PANEL["Imp_A"]
                )

        if inversor_specs:
            if inversor_specs.potencia_AC_nominal_W is None:
                inversor_specs.potencia_AC_nominal_W = buscar_campo_regex(
                    "Potencia AC Nominal [OCR]",
                    text_ocr_lines,
                    REGEX_PATTERNS_INV["potencia_AC_nominal_W"]
                )
            if inversor_specs.Vdc_max_V is None:
                inversor_specs.Vdc_max_V = buscar_campo_regex(
                    "Vdc Máximo [OCR]",
                    text_ocr_lines,
                    REGEX_PATTERNS_INV["Vdc_max_V"]
                )
            if inversor_specs.corriente_AC_max_A is None:
                inversor_specs.corriente_AC_max_A = buscar_campo_regex(
                    "Corriente AC Máxima [OCR]",
                    text_ocr_lines,
                    REGEX_PATTERNS_INV["corriente_AC_max_A"]
                )
            if inversor_specs.cantidad_mppt is None:
                inversor_specs.cantidad_mppt = buscar_campo_regex(
                    "Cantidad MPPT [OCR]",
                    text_ocr_lines,
                    REGEX_PATTERNS_INV["cantidad_mppt"]
                )

    # 5) Logs finales tipo v4
    if panel_specs:
        missing = [
            name for name, val in asdict(panel_specs).items()
            if name != "filename" and val is None
        ]
        if missing:
            print(f"[WARN][PANEL][{fname}] Campos sin dato: {', '.join(missing)}")
        print(f"[DEBUG][PANEL] Pmax={panel_specs.potencia_nominal_W} Voc={panel_specs.Voc_V} "
              f"Isc={panel_specs.Isc_A} Vmp={panel_specs.Vmp_V} Imp={panel_specs.Imp_A}")
    if inversor_specs:
        missing = [
            name for name, val in asdict(inversor_specs).items()
            if name != "filename" and val is None
        ]
        if missing:
            print(f"[WARN][INVERSOR][{fname}] Campos sin dato: {', '.join(missing)}")
        print(f"[DEBUG][INV] Vdc_max={inversor_specs.Vdc_max_V} MPPT={inversor_specs.cantidad_mppt} "
              f"IoutMax={inversor_specs.corriente_AC_max_A}")

    return panel_specs, inversor_specs


# ============================================================
#  Escritura de CSV
# ============================================================

def escribir_csv(ruta: str, registros: List[dict], fieldnames: List[str]) -> None:
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    with open(ruta, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for r in registros:
            writer.writerow(r)


# ============================================================
#  MAIN
# ============================================================

def main():
    # Directorio con PDFs (puedes ajustarlo o usar sys.argv)
    if len(sys.argv) > 1:
        pdf_dir = sys.argv[1]
    else:
        pdf_dir = "."

    paneles: List[PanelSpecs] = []
    inversores: List[InverterSpecs] = []

    for root, _, files in os.walk(pdf_dir):
        for file in files:
            if not file.lower().endswith(".pdf"):
                continue
            pdf_path = os.path.join(root, file)
            pan, inv = procesar_pdf(pdf_path)
            if pan:
                paneles.append(pan)
            if inv:
                inversores.append(inv)

    build_dir = os.path.join(os.getcwd(), "build")
    paneles_csv = os.path.join(build_dir, "paneles.csv")
    inversores_csv = os.path.join(build_dir, "inversores.csv")

    if paneles:
        escribir_csv(
            paneles_csv,
            [asdict(p) for p in paneles],
            list(asdict(paneles[0]).keys())
        )
    if inversores:
        escribir_csv(
            inversores_csv,
            [asdict(i) for i in inversores],
            list(asdict(inversores[0]).keys())
        )

    print("Listo.")
    if paneles:
        print(f" - Paneles:    {paneles_csv}")
    if inversores:
        print(f" - Inversores: {inversores_csv}")


if __name__ == "__main__":
    # Si NO se pasaron argumentos (caso típico al ejecutar desde VS Code),
    # inyectamos los valores por defecto.
    if len(sys.argv) == 1:
        sys.argv = [
            "extract", 
            r"C:\Users\macia\Documents\Proyectos\MacBec\solar-extractor\PDFS",
            "--outdir", r"C:\Users\macia\Documents\Proyectos\MacBec\solar-extractor\build",
            "--debug",
            "--dump-text",
        ]
    # Ya con sys.argv listo (sea por defecto o por CLI), llamamos a main()
    main()