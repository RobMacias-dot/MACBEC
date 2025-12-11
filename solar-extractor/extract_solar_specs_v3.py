#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
extract_solar_specs_final.py (versión híbrida)
----------------------------------------------
Extractor de especificaciones para paneles e inversores desde PDFs.

- Intenta primero TEXTO NATIVO (PyMuPDF, pdfplumber).
- Si no hay texto útil, hace FALLBACK a OCR (pdf2image + OpenCV + Tesseract).
- Suma texto de TABLAS (pdfplumber) para mejorar coincidencias.
- Clasificación por puntaje + opción de forzar tipo (--force-type o meta.csv).
- Flags de depuración (--debug, --dump-text).
- Salida en dos CSV: paneles e inversores con headers alineados a la propuesta.
"""

import re
import csv
import sys
import argparse
from pathlib import Path
from typing import Dict, List, Optional

# =====================
# Campos de salida
# =====================

PANEL_FIELDS = [
    "fabricante","modelo","potencia_nominal_W","Voc_V","Isc_A","Vmp_V","Imp_A",
    "dim_vertical_mm","dim_horizontal_mm","tension_sistema_max_V",
    "coef_temp_Voc_pct_C","coef_temp_Pmax_pct_C","peso_kg",
    "tipo_conector","celdas","ip_rating","ficha_tecnica_url"
]

INV_FIELDS = [
    "fabricante","modelo",
    "potencia_AC_nominal_W","potencia_AC_max_W","mppt_cantidad",
    "Vdc_max","isc_max_por_mppt_A","salida_corriente_max_A","tipo_fase",
    "eficiencia_max_pct","eficiencia_CEC_pct",
    "tension_salida_nominal_V","frecuencia_Hz",
    "pf_range","ip_rating","ficha_tecnica_url"
]

# =====================
# Utilidades
# =====================

def ocr_pdf_text(path: Path) -> str:
    """
    Lee el PDF usando OCR (Tesseract + OpenCV).
    Convierte todas las páginas a imagen y extrae texto.
    """
    from pdf2image import convert_from_path
    import pytesseract
    import cv2
    import numpy as np

    pages = convert_from_path(str(path))
    texts = []

    for page in pages:
        # Pillow Image → numpy array → BGR
        img = np.array(page)
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

        # === PREPROCESAMIENTO ===
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        # Binarización adaptativa
        thresh = cv2.adaptiveThreshold(
            gray, 255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY,
            35, 11
        )

        # Reducción de ruido
        denoised = cv2.fastNlMeansDenoising(thresh, h=20)

        # Aumentar nitidez
        kernel = np.array([[0, -1, 0],
                           [-1, 5, -1],
                           [0, -1, 0]])
        sharp = cv2.filter2D(denoised, -1, kernel)

        # === OCR ===
        text = pytesseract.image_to_string(sharp, lang="spa+eng")
        texts.append(text)

    full_text = "\n".join(texts)
    full_text = full_text.replace("\x0c", "")
    return full_text


def read_pdf_text(path: Path) -> str:
    """
    HÍBRIDO:
    1) Intenta texto nativo con PyMuPDF.
    2) Si es insuficiente, intenta texto con pdfplumber.
    3) Si sigue pobre o vacío, usa OCR con Tesseract.
    """
    # ---- 1) PyMuPDF ----
    try:
        import fitz  # PyMuPDF
        doc = fitz.open(str(path))
        chunks = []
        for page in doc:
            chunks.append(page.get_text("text") or "")
        text = "\n".join(chunks)
        text_clean = text.replace("\x0c", "").strip()
        # Si hay suficiente texto, lo usamos
        if len(text_clean) > 200:
            return text_clean
    except Exception:
        pass

    # ---- 2) pdfplumber ----
    try:
        import pdfplumber
        chunks = []
        with pdfplumber.open(str(path)) as pdf:
            for page in pdf.pages:
                t = page.extract_text() or ""
                chunks.append(t)
        text = "\n".join(chunks)
        text_clean = text.replace("\x0c", "").strip()
        if len(text_clean) > 200:
            return text_clean
    except Exception:
        pass

    # ---- 3) Fallback: OCR ----
    return ocr_pdf_text(path)


def norm(s: str) -> str:
    if not s:
        return ""
    s = s.replace("\t", " ")
    s = re.sub(r"[ ]+", " ", s)
    return s


def to_float_safe(x: Optional[str]) -> Optional[float]:
    if not x:
        return None
    x = x.strip().replace(",", ".")
    x = re.sub(r"[^0-9.\-]", "", x)
    if x in ("", ".", "-", "-.", ".-"):
        return None
    try:
        return float(x)
    except Exception:
        return None


def find_first(patterns, text: str) -> Optional[str]:
    for p in patterns:
        m = p.search(text)
        if m:
            gs = m.groups()
            if gs:
                for g in reversed(gs):
                    if g and re.search(r"[0-9]", g):
                        return g
            return m.group(0)
    return None

# =====================
# Patrones (paneles)
# =====================

PAT_POT_PANEL = [
    # Español genérico
    re.compile(
        r"potencia\s*(?:m[aá]xima|nominal|pico)"
        r"(?:\s*de\s*salida)?[^\d]{0,15}"
        r"(\d{2,4}(?:[.,]\d+)?)\s*(?:k?w|wp)?\b",
        re.I
    ),
    # Pmax / Pmpp sueltos
    re.compile(
        r"\bP\s*M?A?X\b[^\d]{0,10}(\d{2,4}(?:[.,]\d+)?)\s*(?:k?w|wp)?\b",
        re.I
    ),
    re.compile(
        r"\bPM[Pp]\b[^\d]{0,10}(\d{2,4}(?:[.,]\d+)?)\s*(?:k?w|wp)?\b",
        re.I
    ),
    # Inglés: Maximum / Nominal / Peak / Rated module power
    re.compile(
        r"(?:rated|maximum|nominal|peak)\s*(?:module\s*)?power"
        r"[^\d]{0,15}(\d{2,4}(?:[.,]\d+)?)\s*(?:k?w|wp)?\b",
        re.I
    ),
]

PAT_VOC = [
    re.compile(r"voltaje\s*en\s*circuito\s*abierto.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"\bVoc\b[^0-9]{0,10}(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"open[-\s]*circuit\s*voltage.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
]

PAT_ISC = [
    re.compile(r"intensidad\s*de\s*corto\s*circuito.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"\bIsc\b[^0-9]{0,10}(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"(?:short|corto)[-\s]*circuit\s*current.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
]

PAT_VMP = [
    re.compile(r"voltaje\s*a\s*potencia\s*m[aá]xima.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"\bVmp\b[^0-9]{0,10}(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"maximum\s*power\s*voltage.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"voltage\s+at\s+pmax.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
]

PAT_IMP = [
    re.compile(r"intensidad\s*a\s*potencia\s*m[aá]xima.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"\bImp\b[^0-9]{0,10}(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"maximum\s*power\s*current.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"current\s+at\s+pmax.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
]

PAT_DIMENSIONS = [
    # Dimension / Dimensions 1956 x 992 x 50 mm
    re.compile(
        r"dimensi[oó]n(?:es)?[^\d]{0,30}"
        r"(\d{3,4})(?:\s*[±+−\-]\s*\d+)?\s*mm?\s*[x×]\s*"
        r"(\d{3,4})(?:\s*[±+−\-]\s*\d+)?\s*mm?\s*[x×]\s*"
        r"(\d{1,3})\s*mm\b",
        re.I
    ),
    re.compile(
        r"dimensions?[^\d]{0,30}"
        r"(\d{3,4})(?:\s*[±+−\-]\s*\d+)?\s*mm?\s*[x×]\s*"
        r"(\d{3,4})(?:\s*[±+−\-]\s*\d+)?\s*mm?\s*[x×]\s*"
        r"(\d{1,3})\s*mm\b",
        re.I
    ),
    # Fallback: solo tres números con x o × y mm al final
    re.compile(
        r"(\d{3,4})\s*[x×]\s*(\d{3,4})\s*[x×]\s*(\d{1,3})\s*mm\b",
        re.I
    ),
]

PAT_SYSTEM_VOLT = [
    re.compile(r"(?:max\.?\s*)?system\s*voltage[^\d]{0,12}(\d{2,4}(?:[.,]\d+)?)\s*v\b", re.I),
    re.compile(r"tensi[oó]n\s*de\s*sistema\s*m[aá]x[^\d]{0,12}(\d{2,4}(?:[.,]\d+)?)\s*v\b", re.I),
]

PAT_TEMP_COEF_VOC = [
    re.compile(r"coeficiente\s*de\s*temperatura\s*voc.*?([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c", re.I),
    re.compile(r"temp(?:erature)?\s*coef(?:ficient)?\s*(?:of\s*)?voc.*?([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c", re.I),
    re.compile(r"temp\.?\s*coeff\.?\s*(?:of\s*)?voc.*?([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c?", re.I),
    re.compile(r"TK\s*Voc[^\d\-+]{0,10}([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c?", re.I),
]

PAT_TEMP_COEF_PMAX = [
    re.compile(r"coeficiente\s*de\s*temperatura\s*pmax.*?([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c", re.I),
    re.compile(r"temp(?:erature)?\s*coef(?:ficient)?\s*(?:of\s*)?pmax.*?([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c", re.I),
    re.compile(r"temp\.?\s*coeff\.?\s*(?:of\s*)?pmax.*?([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c?", re.I),
    re.compile(r"TK\s*Pmax[^\d\-+]{0,10}([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c?", re.I),
]

PAT_WEIGHT = [
    re.compile(r"peso[^\d]{0,10}([0-9.,]+)\s*kg", re.I),
    re.compile(r"weight[^\d]{0,10}([0-9.,]+)\s*kg", re.I),
]

PAT_IP_PANEL = [
    re.compile(r"\bIP\d{2}\b", re.I),
]

# =====================
# Patrones (inversores)
# =====================

PAT_P_AC_NOM = [
    # Español
    re.compile(
        r"potencia\s*nominal\s*(?:de\s*salida|de\s*ca)?"
        r"[^\d]{0,15}(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b",
        re.I
    ),
    re.compile(
        r"potencia\s*nominal\s*de\s*ca.*?(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b",
        re.I
    ),
    re.compile(
        r"potencia\s*nominal\s*de\s*ca\s*PCA[^\d]{0,15}"
        r"(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b",
        re.I
    ),
    re.compile(
        r"potencia\s*nominal\s*de\s*salida[^\d]{0,15}"
        r"(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b",
        re.I
    ),
    # Inglés
    re.compile(
        r"(?:rated|nominal)\s*ac\s*(?:output\s*)?power"
        r"[^\d]{0,15}(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b",
        re.I
    ),
]

PAT_P_AC_MAX = [
    re.compile(r"potencia\s*ac\s*m[aá]x[^\d]{0,15}(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b", re.I),
    re.compile(r"(?:max(?:imum)?\s*)?ac\s*power[^\d]{0,15}(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b", re.I),
    re.compile(r"potencia\s*aparente\s*m[aá]xima[^\d]{0,15}(\d{2,6}(?:[.,]\d+)?)\s*kva\b", re.I),
]

PAT_MPPT_CNT = [
    re.compile(r"(?:no\.?|number\s*of|cantidad\s*de|n[uú]mero\s*de)\s*mppt(?:s)?[^\d]{0,12}(\d{1,2})\b", re.I),
    re.compile(r"\bmppt[^0-9]{0,5}(\d{1,2})\b", re.I),
    re.compile(r"\b(\d{1,2})\s*/\s*\d{1,2}\b", re.I),
]

PAT_VDC_MAX = [
    re.compile(r"voltaje\s*m[aá]ximo\s*de\s*entrada[^\d]{0,20}(\d{3,4}(?:[.,]\d+)?)", re.I),
    re.compile(r"voltaje\s*m[aá]ximo\s*cd[^\d]{0,20}(\d{3,4}(?:[.,]\d+)?)", re.I),
    re.compile(r"m[aá]ximo\s*voltaje\s*cd[^\d]{0,20}(\d{3,4}(?:[.,]\d+)?)", re.I),
    re.compile(r"(?:max(?:imum)?\s*)?dc\s*(?:input\s*)?voltage[^\d]{0,20}(\d{3,4}(?:[.,]\d+)?)", re.I),
    re.compile(r"tensi[oó]n\s*m[aá]xima\s*de\s*cc[^\d]{0,40}(\d{3,4}(?:[.,]\d+)?)\s*v", re.I),
    re.compile(r"ucc[, ]*max[^\d]{0,20}(\d{3,4}(?:[.,]\d+)?)\s*v", re.I),
]

PAT_ISC_PER_MPPT = [
    re.compile(r"corriente\s*m[aá]xima\s*de\s*corto\s*circuito.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"(?:short|corto)[-\s]*circuit\s*current.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
]

PAT_AC_OUT_CURRENT_MAX = [
    re.compile(r"corriente\s*m[aá]xima\s*de\s*salida[^\d]{0,20}(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"corriente\s*nominal\s*de\s*ca[^\d]{0,20}(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"(?:max(?:imum)?\s*)?output\s*current[^\d]{0,20}(\d{1,3}(?:[.,]\d+)?)", re.I),
]

PAT_EFF_MAX = [
    re.compile(r"eficiencia\s*m[aá]xima[^\d]{0,12}(\d{1,2}(?:[.,]\d+)?)\s*%\b", re.I),
    re.compile(r"(?:max(?:imum)?\s*)?efficiency[^\d]{0,12}(\d{1,2}(?:[.,]\d+)?)\s*%\b", re.I),
]

PAT_EFF_CEC = [
    re.compile(r"eficiencia\s*eu(?:ropea)?[^\d]{0,12}(\d{1,2}(?:[.,]\d+)?)\s*%\b", re.I),
    re.compile(r"cec\s*efficiency[^\d]{0,12}(\d{1,2}(?:[.,]\d+)?)\s*%\b", re.I),
]

PAT_VOUT = [
    re.compile(r"tensi[oó]n\s*nominal\s*de\s*la\s*red[^\d]{0,20}(\d{2,4}(?:[.,]\d+)?)\s*v\b", re.I),
    re.compile(r"voltaje\s*nominal\s*ca[^\d]{0,20}(\d{2,4}(?:[.,]\d+)?)\s*v\b", re.I),
    re.compile(r"(?:nominal\s*)?ac\s*output\s*voltage[^\d]{0,20}(\d{2,4}(?:[.,]\d+)?)\s*v\b", re.I),
    re.compile(r"voltaje\s*nominal[^\d]{0,20}(\d{2,4}(?:[.,]\d+)?)\s*k?v\b", re.I),
]

PAT_FREQ = [
    re.compile(r"frecuencia\s*nominal[^\d]{0,12}(\d{2,3}(?:[.,]\d+)?)\s*hz\b", re.I),
    re.compile(r"(?:nominal\s*)?frequen(?:cy|cia)[^\d]{0,12}(\d{2,3}(?:[.,]\d+)?)\s*hz\b", re.I),
    re.compile(r"frequen(?:cy|cia)[^\d]{0,40}(\d{2,3}(?:[.,]\d+)?)\s*hz\b", re.I),
]

PAT_PF_RANGE = [
    re.compile(r"factor\s*de\s*potencia[^:]*:\s*([0-9>.<=()\s\-a,]+)", re.I),
    re.compile(r"power\s*factor\s*range[^:]*:\s*([0-9>.<=()\s\-a,]+)", re.I),
    re.compile(r"factor\s*de\s*potencia[^\d]{0,40}([0-9.,]+)", re.I),
    # cos φ ≥ 0,99
    re.compile(r"cos\s*[φphi]+\s*[≥>=]\s*([0-9.,]+)", re.I),
]

PAT_IP_INV = [
    re.compile(r"\bIP\d{2}\b", re.I),
]

# Patrón para tablas tipo JUSTSolar: 
#   650W
#   45.58V
#   18.16A
#   37.61V
#   17.28A
#   20.92%
PAT_PANEL_TABLE_BLOCK = re.compile(
    r"(\d{3,4})\s*W\s+"                   # Pmax (W)
    r"(\d{2,3}(?:[.,]\d+)?)\s*V\s+"       # Vmp
    r"(\d{1,2}(?:[.,]\d+)?)\s*A\s+"       # Imp
    r"(\d{2,3}(?:[.,]\d+)?)\s*V\s+"       # Voc
    r"(\d{1,2}(?:[.,]\d+)?)\s*A\s+"       # Isc
    r"(\d{1,2}(?:[.,]\d+)?)\s*%",         # Eficiencia (no la usamos, pero la capturamos)
    re.I | re.S
)


# =====================
# Extractores
# =====================

def extract_panel(text: str) -> Dict[str, Optional[str]]:
    out = {k: None for k in PANEL_FIELDS}

    # Potencia nominal
    pmax_val = None
    for p in PAT_POT_PANEL:
        m = p.search(text)
        if m:
            raw = m.group(1)
            num = to_float_safe(raw)
            if num is None:
                continue
            whole = m.group(0).lower()
            if "kw" in whole and num < 1000:
                num *= 1000.0
            pmax_val = num
            break
    out["potencia_nominal_W"] = pmax_val

    # Parámetros eléctricos básicos
    out["Voc_V"] = to_float_safe(find_first(PAT_VOC, text))
    out["Isc_A"] = to_float_safe(find_first(PAT_ISC, text))
    out["Vmp_V"] = to_float_safe(find_first(PAT_VMP, text))
    out["Imp_A"] = to_float_safe(find_first(PAT_IMP, text))

        # ---------- Fallback de tabla tipo JUSTSolar ----------
    # Si alguno de los parámetros clave no se encontró,
    # intentamos detectar el bloque numérico "650W / Vmp / Imp / Voc / Isc / %"
    if (
        out["potencia_nominal_W"] is None or
        out["Voc_V"] is None or
        out["Isc_A"] is None or
        out["Vmp_V"] is None or
        out["Imp_A"] is None
    ):
        m_tab = PAT_PANEL_TABLE_BLOCK.search(text)
        if m_tab:
            try:
                pmax_str, vmp_str, imp_str, voc_str, isc_str, eff_str = m_tab.groups()

                # Solo rellenamos los que falten, para no pisar buenos valores
                if out["potencia_nominal_W"] is None:
                    out["potencia_nominal_W"] = to_float_safe(pmax_str)
                if out["Vmp_V"] is None:
                    out["Vmp_V"] = to_float_safe(vmp_str)
                if out["Imp_A"] is None:
                    out["Imp_A"] = to_float_safe(imp_str)
                if out["Voc_V"] is None:
                    out["Voc_V"] = to_float_safe(voc_str)
                if out["Isc_A"] is None:
                    out["Isc_A"] = to_float_safe(isc_str)
                # La eficiencia (eff_str) por ahora no la usamos en el CSV
            except Exception:
                pass


    # Dimensiones
    for p in PAT_DIMENSIONS:
        m = p.search(text)
        if m:
            gs = [g for g in m.groups() if g]
            if len(gs) >= 2:
                try:
                    a = float(gs[0])
                    b = float(gs[1])
                except ValueError:
                    continue
                if a >= b:
                    out["dim_vertical_mm"], out["dim_horizontal_mm"] = a, b
                else:
                    out["dim_vertical_mm"], out["dim_horizontal_mm"] = b, a
            break

    # Peso
    w = find_first(PAT_WEIGHT, text)
    out["peso_kg"] = to_float_safe(w) if w else None

    # Tensión de sistema y coeficientes
    out["tension_sistema_max_V"] = to_float_safe(find_first(PAT_SYSTEM_VOLT, text))
    out["coef_temp_Voc_pct_C"] = to_float_safe(find_first(PAT_TEMP_COEF_VOC, text))
    out["coef_temp_Pmax_pct_C"] = to_float_safe(find_first(PAT_TEMP_COEF_PMAX, text))

    # IP rating
    out["ip_rating"] = find_first(PAT_IP_PANEL, text)

    # Conector
    m_conn = re.search(r"conectores?\s*([^\n\r]+)", text, re.I)
    if m_conn:
        out["tipo_conector"] = m_conn.group(1).strip()
    else:
        if re.search(r"\bMC4\b", text, re.I):
            out["tipo_conector"] = "MC4 compatible"

    # Celdas
    m_cells = re.search(r"c[eé]lulas?\s*([0-9]{2,3}(?:\s*=\s*[0-9xX×]+)?)", text, re.I)
    if not m_cells:
        m_cells = re.search(r"\b(\d{2,3})\s*cells?\b", text, re.I)
    if m_cells:
        out["celdas"] = m_cells.group(1).strip()

    return out


def guess_phase(s: str) -> Optional[str]:
    s_low = s.lower()
    if re.search(r"\btrif[aá]sico|\bthree[-\s]?phase|3[phФ]", s_low):
        return "trifasico"
    if re.search(r"\bbif[aá]sico|\bbi[-\s]?phase|2[phФ]", s_low):
        return "bifasico"
    if re.search(r"\bmonof[aá]sico|\bsingle[-\s]?phase|1[phФ]", s_low):
        return "monofasico"
    return None


def extract_inversor(text: str) -> Dict[str, Optional[str]]:
    out = {k: None for k in INV_FIELDS}

    # Potencia AC nominal
    pot_nom = None
    for p in PAT_P_AC_NOM:
        m = p.search(text)
        if m:
            raw = m.group(1)
            num = to_float_safe(raw)
            if num is None:
                continue
            whole = m.group(0).lower()
            if ("kw" in whole or "kva" in whole) and num < 1000:
                num *= 1000.0
            pot_nom = num
            break
    out["potencia_AC_nominal_W"] = pot_nom

    # Potencia AC máxima
    pot_max = None
    for p in PAT_P_AC_MAX:
        m = p.search(text)
        if m:
            raw = m.group(1)
            num = to_float_safe(raw)
            if num is None:
                continue
            whole = m.group(0).lower()
            if ("kw" in whole or "kva" in whole) and num < 1000:
                num *= 1000.0
            pot_max = num
            break
    out["potencia_AC_max_W"] = pot_max

    # MPPT
    mppt = find_first(PAT_MPPT_CNT, text)
    try:
        out["mppt_cantidad"] = int(float(mppt)) if mppt else None
    except ValueError:
        out["mppt_cantidad"] = None

    # Lado DC
    out["Vdc_max"] = to_float_safe(find_first(PAT_VDC_MAX, text))
    out["isc_max_por_mppt_A"] = to_float_safe(find_first(PAT_ISC_PER_MPPT, text))

    # Lado AC
    out["salida_corriente_max_A"] = to_float_safe(find_first(PAT_AC_OUT_CURRENT_MAX, text))
    out["tipo_fase"] = guess_phase(text)
    out["eficiencia_max_pct"] = to_float_safe(find_first(PAT_EFF_MAX, text))
    out["eficiencia_CEC_pct"] = to_float_safe(find_first(PAT_EFF_CEC, text))

    # Tensión nominal salida AC
    vout_val = None
    for p in PAT_VOUT:
        m = p.search(text)
        if not m:
            continue
        raw = m.group(1)
        num = to_float_safe(raw)
        if num is None:
            continue
        whole = m.group(0).lower()
        if "kv" in whole and num < 1000:
            num *= 1000.0
        vout_val = num
        break
    out["tension_salida_nominal_V"] = vout_val

    # Frecuencia
    out["frecuencia_Hz"] = to_float_safe(find_first(PAT_FREQ, text))

    # PF e IP
    out["pf_range"] = find_first(PAT_PF_RANGE, text)
    out["ip_rating"] = find_first(PAT_IP_INV, text)

    return out

# =====================
# Meta y CSV
# =====================

def load_meta(meta_path: Optional[Path]):
    meta = {}
    if not meta_path or not meta_path.exists():
        return meta
    with meta_path.open("r", encoding="utf-8-sig", newline="") as f:
        rdr = csv.DictReader(f)
        for row in rdr:
            filename = (row.get("filename") or "").strip().lower()
            if not filename:
                continue
            meta[filename] = {
                "fabricante": (row.get("fabricante") or "").strip(),
                "modelo": (row.get("modelo") or "").strip(),
                "tipo": (row.get("tipo") or "").strip().lower(),
                "url": (row.get("url") or "").strip(),
            }
    return meta


def write_csv(path: Path, fieldnames: List[str], rows: List[Dict]):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k) for k in fieldnames})

# =====================
# Main
# =====================

def main():
    ap = argparse.ArgumentParser(
        description="Extractor de especificaciones solares (paneles/inversores) desde PDFs (HÍBRIDO)"
    )
    ap.add_argument("input", help="Carpeta con PDFs")
    ap.add_argument("--outdir", default=".", help="Carpeta de salida (por defecto: .)")
    ap.add_argument("--paneles", default="paneles.csv", help="Nombre CSV paneles")
    ap.add_argument("--inversores", default="inversores.csv", help="Nombre CSV inversores")
    ap.add_argument("--meta", help="CSV opcional con filename,fabricante,modelo,tipo,url", default=None)
    ap.add_argument("--debug", action="store_true", help="Imprime coincidencias por campo y clasificación")
    ap.add_argument("--dump-text", action="store_true",
                    help="Guarda texto en outdir/_debug_text/ (normal y _AUG)")
    ap.add_argument("--force-type", choices=["panel", "inversor"], help="Forzar clasificación global")
    args = ap.parse_args()

    in_dir = Path(args.input)
    if not in_dir.exists() or not in_dir.is_dir():
        print(f"ERROR: carpeta inválida: {in_dir}", file=sys.stderr)
        sys.exit(1)

    outdir = Path(args.outdir)
    dump_dir = outdir / "_debug_text"
    if args.dump_text:
        dump_dir.mkdir(parents=True, exist_ok=True)

    meta = load_meta(Path(args.meta) if args.meta else None)
    panel_rows: List[Dict] = []
    inv_rows: List[Dict] = []

    for pdf_path in sorted(in_dir.glob("**/*.pdf")):
        try:
            # 1) Texto base del PDF (híbrido)
            txt = read_pdf_text(pdf_path)
            txt_norm = norm(txt)

            # 2) Sumar TEXTO DE TABLAS (si hay) para mejorar coincidencias
            txt_tables = ""
            try:
                import pdfplumber
                with pdfplumber.open(str(pdf_path)) as pdf:
                    table_chunks = []
                    for page in pdf.pages:
                        try:
                            tables = page.extract_tables() or []
                            for tb in tables:
                                rows = [" ".join([(c or "") for c in row]) for row in tb if row]
                                table_chunks.append("\n".join(rows))
                        except Exception:
                            pass
                    if table_chunks:
                        txt_tables = "\n".join(table_chunks)
            except Exception:
                pass

            txt_aug = norm((txt_norm + "\n" + txt_tables).strip())

            # 3) Dump para depurar
            if args.dump_text:
                (dump_dir / f"{pdf_path.stem}.txt").write_text(
                    txt_norm, encoding="utf-8", errors="ignore"
                )
                (dump_dir / f"{pdf_path.stem}_AUG.txt").write_text(
                    txt_aug, encoding="utf-8", errors="ignore"
                )

            # 4) Meta (fabricante, modelo, url)
            meta_row = meta.get(pdf_path.name.lower(), {})
            fabricante = meta_row.get("fabricante") or None
            modelo = meta_row.get("modelo") or None
            url = meta_row.get("url") or ""

            # 5) Clasificación
            tipo_forzado = args.force_type or (meta_row.get("tipo") if meta_row else None)
            is_panel = is_inversor = False
            row_panel = row_inv = None

            if tipo_forzado == "panel":
                is_panel = True
            elif tipo_forzado == "inversor":
                is_inversor = True
            else:
                tmp_panel = extract_panel(txt_aug)
                tmp_inv = extract_inversor(txt_aug)

                core_panel = ["potencia_nominal_W", "Voc_V", "Isc_A", "Vmp_V", "Imp_A"]
                core_inv = ["potencia_AC_nominal_W", "Vdc_max",
                            "isc_max_por_mppt_A", "salida_corriente_max_A",
                            "mppt_cantidad"]

                score_panel = sum(1 for k in core_panel if tmp_panel.get(k) not in (None, 0))
                score_inv = sum(1 for k in core_inv if tmp_inv.get(k) not in (None, 0))

                if score_panel == 0 and score_inv == 0:
                    # Fallback: palabras clave
                    t = txt_aug.lower()
                    panel_score = sum(t.count(k) for k in [
                        "pmax","pmpp","wp","module","panel","módulo","voc","open circuit voltage",
                        "voltaje de circuito abierto","isc","short circuit current",
                        "corriente de corto circuito","vmp","voltage at pmax",
                        "maximum power voltage","imp","current at pmax",
                        "maximum power current","dimensiones","dimensions"," mm ","×"," x "
                    ])
                    inv_score = sum(t.count(k) for k in [
                        "mppt","inversor","inverter","dc input voltage",
                        "max dc input voltage","vdc max","tensión dc máx",
                        "output current","corriente de salida",
                        "ac output voltage","ac voltage","frecuencia","frequency",
                        "potencia ac","rated ac power","nominal ac power","pf",
                        "power factor","monofásico","bifásico","trifásico",
                        "single-phase","three-phase"
                    ])

                    if inv_score > panel_score:
                        is_inversor = True
                    elif panel_score > inv_score:
                        is_panel = True
                    else:
                        is_inversor = ("mppt" in t or "inversor" in t or "inverter" in t)
                        is_panel = not is_inversor
                else:
                    if score_panel > score_inv:
                        is_panel = True
                        row_panel = tmp_panel
                    elif score_inv > score_panel:
                        is_inversor = True
                        row_inv = tmp_inv
                    else:
                        # empate: decidir más abajo
                        pass

            # 5.4 Fallback final si sigue sin decidir
            if not is_panel and not is_inversor:
                if args.debug:
                    print(f"[DEBUG] {pdf_path.name} → no se pudo clasificar por score; heurístico final")
                tmp_panel2 = extract_panel(txt_aug)
                if any(tmp_panel2.get(k) for k in ["Voc_V", "Isc_A", "Vmp_V", "Imp_A"]):
                    is_panel = True
                    row_panel = tmp_panel2
                else:
                    tmp_inv2 = extract_inversor(txt_aug)
                    if any(tmp_inv2.get(k) for k in ["Vdc_max", "mppt_cantidad",
                                                      "salida_corriente_max_A",
                                                      "potencia_AC_nominal_W"]):
                        is_inversor = True
                        row_inv = tmp_inv2
                    else:
                        print(f"[WARN] {pdf_path.name}: no se pudo extraer nada útil.")
                        continue

            if args.debug:
                print(f"[DEBUG] {pdf_path.name} → clasif panel={is_panel} inversor={is_inversor} force={tipo_forzado}")

            # 6) Completar fila según tipo
            if is_panel:
                if row_panel is None:
                    row_panel = extract_panel(txt_aug)
                row = row_panel
                row["fabricante"] = fabricante
                row["modelo"] = modelo
                row["ficha_tecnica_url"] = url
                panel_rows.append(row)
                if args.debug:
                    print(f"[DEBUG][PANEL] Pmax={row.get('potencia_nominal_W')} Voc={row.get('Voc_V')} "
                          f"Isc={row.get('Isc_A')} Vmp={row.get('Vmp_V')} Imp={row.get('Imp_A')}")

            elif is_inversor:
                if row_inv is None:
                    row_inv = extract_inversor(txt_aug)
                row = row_inv
                row["fabricante"] = fabricante
                row["modelo"] = modelo
                row["ficha_tecnica_url"] = url
                inv_rows.append(row)
                if args.debug:
                    print(f"[DEBUG][INV] Vdc_max={row.get('Vdc_max')} "
                          f"MPPT={row.get('mppt_cantidad')} IoutMax={row.get('salida_corriente_max_A')}")

        except Exception as e:
            print(f"[ERROR] {pdf_path.name}: {e}")

    # 7) Escribir CSVs
    write_csv(outdir / (args.paneles or "paneles.csv"), PANEL_FIELDS, panel_rows)
    write_csv(outdir / (args.inversores or "inversores.csv"), INV_FIELDS, inv_rows)
    print("Listo.")
    print(f" - Paneles:    {outdir / (args.paneles or 'paneles.csv')}")
    print(f" - Inversores: {outdir / (args.inversores or 'inversores.csv')}")

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
