#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
extract_solar_specs_final.py
----------------------------
Extractor de especificaciones para paneles e inversores desde PDFs.
- Lee texto con backends múltiples (PyMuPDF, pdfplumber, PyPDF2).
- Suma texto de TABLAS (pdfplumber) para mejorar coincidencias.
- Clasificación por puntaje + opción de forzar tipo (--force-type o meta.csv).
- Flags de depuración (--debug, --dump-text).
- Salida en dos CSV: paneles e inversores con headers alineados a la propuesta.

Uso típico:
  python extract_solar_specs_final.py .\\PDFS --outdir .\\build --meta .\\meta.csv --debug --dump-text
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
    "coef_temp_Voc_pct_C","coef_temp_Pmax_pct_C","peso_kg","tipo_conector","celdas","ip_rating","ficha_tecnica_url"
]

INV_FIELDS = [
    "fabricante","modelo","potencia_AC_nominal_W","potencia_AC_max_W","mppt_cantidad",
    "Vdc_max","isc_max_por_mppt_A","salida_corriente_max_A","tipo_fase",
    "eficiencia_max_pct","eficiencia_CEC_pct","tension_salida_nominal_V","frecuencia_Hz","pf_range","ip_rating","ficha_tecnica_url"
]

# =====================
# Utilidades
# =====================

def read_pdf_text(path: Path) -> str:
    """
    Lee el PDF usando SOLO OCR (Tesseract + OpenCV).
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

        # Escala de grises
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        # Binarización adaptativa (Más robusta)
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

    # Limpieza mínima
    full_text = full_text.replace("\x0c", "")  # quitar saltos de página
    return full_text


def norm(s: str) -> str:
    """
    Normaliza espacios en el texto:
    - Convierte tabs en espacios.
    - Colapsa múltiples espacios en uno solo.
    - Opcionalmente podrías bajar a minúsculas aquí, pero por ahora no.
    """
    if not s:
        return ""
    # Reemplazar tabs por espacio
    s = s.replace("\t", " ")
    # Colapsar espacios múltiples en uno
    s = re.sub(r"[ ]+", " ", s)
    return s

def to_float_safe(x: Optional[str]) -> Optional[float]:
    """
    Convierte un string numérico en float de forma segura.
    Acepta coma o punto como separador decimal.
    Si no puede convertir, devuelve None.
    """
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
    """
    Recorre una lista de patrones regex y devuelve:
    - el último grupo de captura que contenga dígitos, si existe
    - si no hay grupos, devuelve el match completo
    - si no hay match en ningún patrón, devuelve None
    """
    for p in patterns:
        m = p.search(text)
        if m:
            gs = m.groups()
            if gs:
                # Recorremos los grupos de atrás hacia adelante
                for g in reversed(gs):
                    if g and re.search(r"[0-9]", g):
                        return g
            return m.group(0)
    return None

# =====================
# Patrones (paneles) – versión afinada para OCR ES/EN
# =====================

# Potencia Pmax / Pmpp / Wp / "Potencia máxima"
PAT_POT_PANEL = [
    # Ej: "Potencia máxima (Pmax) [w] 320"
    re.compile(r"potencia\s*m[aá]xima.*?(\d{2,4}(?:[.,]\d+)?)\s*(?:k?w|wp)?\b", re.I),
    # Variantes con Pmax / Pmpp
    re.compile(r"\bp\s*m?a?x\b[^0-9]{0,10}(\d{2,4}(?:[.,]\d+)?)\s*(?:k?w|wp)?\b", re.I),
    re.compile(r"\bpmpp\b[^0-9]{0,10}(\d{2,4}(?:[.,]\d+)?)\s*(?:k?w|wp)?\b", re.I),
    # Inglés: "Maximum Power", "Nominal Power"
    re.compile(r"(?:maximum|nominal)\s*power[^\d]{0,12}(\d{2,4}(?:[.,]\d+)?)\s*(?:k?w|wp)?\b", re.I),
]

# Voc / Isc / Vmp / Imp con variantes ES/EN y OCR
PAT_VOC = [
    # "Voltaje en circuito abierto (Voc) [V] 37.1"
    re.compile(r"voltaje\s*en\s*circuito\s*abierto.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"\bVoc\b[^0-9]{0,10}(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"open[-\s]*circuit\s*voltage.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
]

PAT_ISC = [
    # "Intensidad de cortocircuito (Isc) [A] 8.63"
    re.compile(r"intensidad\s*de\s*cortocircuito.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"\bIsc\b[^0-9]{0,10}(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"(?:short|corto)[-\s]*circuit.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
]

PAT_VMP = [
    # "Voltaje a potencia máxima (Vmp) [V] 45.7"
    re.compile(r"voltaje\s*a\s*potencia\s*m[aá]xima.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"\bVmp\b[^0-9]{0,10}(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"voltage\s+at\s+pmax.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
]

PAT_IMP = [
    # "Intensidad a potencia máxima (Imp) [A] 9.00"
    re.compile(r"intensidad\s*a\s*potencia\s*m[aá]xima.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"\bImp\b[^0-9]{0,10}(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"current\s+at\s+pmax.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
]

# Dimensiones
# Ej: "Dimension 1956 x 992 x 50 mm"
PAT_DIMENSIONS = [
    re.compile(r"dimensi[oó]n(?:es)?[^0-9]{0,30}(\d{3,4})\s*[x×]\s*(\d{3,4})\s*[x×]\s*(\d{1,3})\s*mm\b", re.I),
    re.compile(r"dimensions?[^0-9]{0,30}(\d{3,4})\s*[x×]\s*(\d{3,4})\s*[x×]\s*(\d{1,3})\s*mm\b", re.I),
]

# Sistema y coeficientes
PAT_SYSTEM_VOLT = [
    re.compile(r"(?:max\.?\s*)?system\s*voltage[^0-9]{0,12}(\d{2,4}(?:[.,]\d+)?)\s*v\b", re.I),
    re.compile(r"tensi[oó]n\s*de\s*sistema\s*m[aá]x[^0-9]{0,12}(\d{2,4}(?:[.,]\d+)?)\s*v\b", re.I),
]

PAT_TEMP_COEF_VOC = [
    # "Coeficiente de temperatura Voc -0.33% /°C"
    re.compile(r"coeficiente\s*de\s*temperatura\s*voc.*?([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c", re.I),
    re.compile(r"temp(?:erature)?\s*coef(?:ficient)?\s*(?:of\s*)?voc.*?([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c", re.I),
]

PAT_TEMP_COEF_PMAX = [
    # "Coeficiente de temperatura Pmax -0.43% /°C"
    re.compile(r"coeficiente\s*de\s*temperatura\s*pmax.*?([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c", re.I),
    re.compile(r"temp(?:erature)?\s*coef(?:ficient)?\s*(?:of\s*)?pmax.*?([-+]?\d{1,2}(?:[.,]\d+)?)\s*%/?°?c", re.I),
]

PAT_WEIGHT = [
    # "Peso 27 kg" / "Peso: 27 kg"
    re.compile(r"peso[^0-9]{0,10}([0-9.,]+)\s*kg", re.I),
    re.compile(r"weight[^0-9]{0,10}([0-9.,]+)\s*kg", re.I),
]

PAT_IP = [
    re.compile(r"\bIP\d{2}\b", re.I)
]

# =====================
# Patrones (inversores) – versión afinada para OCR ES/EN
# =====================

# Potencia AC nominal
# Ej: "Potencia nominal de salida 124 kw 125 kW"
PAT_P_AC_NOM = [
    re.compile(r"potencia\s*nominal(?:\s*de\s*salida)?[^0-9]{0,12}(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b", re.I),
    re.compile(r"(?:rated|nominal)\s*ac\s*power[^0-9]{0,12}(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b", re.I),
]

# Potencia AC máxima
PAT_P_AC_MAX = [
    re.compile(r"potencia\s*ac\s*m[aá]x[^0-9]{0,12}(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b", re.I),
    re.compile(r"(?:max(?:imum)?\s*)?ac\s*power[^0-9]{0,12}(\d{2,6}(?:[.,]\d+)?)\s*(?:k?w|kva)?\b", re.I),
]

# Cantidad de MPPT
# Ej: "10/20", "10 MPPT"
PAT_MPPT_CNT = [
    re.compile(r"(?:no\.?|number\s*of|cantidad\s*de)\s*mppt(?:s)?[^0-9]{0,12}(\d{1,2})\b", re.I),
    re.compile(r"\bmppt[^0-9]{0,5}(\d{1,2})\b", re.I),
    re.compile(r"\b(\d{1,2})\s*/\s*\d{1,2}\b", re.I),
]

# Máx voltaje DC entrada
# Ej: "Voltaje máximo de entrada 1000 V"
PAT_VDC_MAX = [
    re.compile(r"voltaje\s*m[aá]ximo\s*de\s*entrada[^0-9]{0,12}(\d{3,4}(?:[.,]\d+)?)", re.I),
    re.compile(r"(?:max(?:imum)?\s*)?dc\s*(?:input\s*)?voltage[^0-9]{0,12}(\d{3,4}(?:[.,]\d+)?)", re.I),
    # "Tensión máxima de CC admisible UCC, max 880 V"
    re.compile(r"tensi[oó]n\s*m[aá]xima\s*de\s*cc[^0-9]{0,40}(\d{3,4}(?:[.,]\d+)?)\s*v", re.I),
    # "Voltaje máximo de entrada ..."
    re.compile(r"voltaje\s*m[aá]ximo\s*de\s*entrada[^0-9]{0,40}(\d{3,4}(?:[.,]\d+)?)\s*v", re.I),
    # "UCC, max 880 V"
    re.compile(r"ucc[, ]*max[^0-9]{0,20}(\d{3,4}(?:[.,]\d+)?)\s*v", re.I),
    # Inglés genérico
    re.compile(r"(?:max(?:imum)?\s*)?dc\s*(?:input\s*)?voltage[^0-9]{0,40}(\d{3,4}(?:[.,]\d+)?)\s*v", re.I),
]


# Corriente máx de cortocircuito por MPPT
PAT_ISC_PER_MPPT = [
    re.compile(r"corriente\s*m[aá]xima\s*de\s*corto\s*circuito.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"(?:short|corto)[-\s]*circuit\s*current.*?(\d{1,3}(?:[.,]\d+)?)", re.I),
]

# Corriente de salida AC máxima
# Ej: "Corriente maxima de salida 149.24 150.4A"
PAT_AC_OUT_CURRENT_MAX = [
    re.compile(r"corriente\s*m[aá]xima\s*de\s*salida[^0-9]{0,12}(\d{1,3}(?:[.,]\d+)?)", re.I),
    re.compile(r"(?:max(?:imum)?\s*)?output\s*current[^0-9]{0,12}(\d{1,3}(?:[.,]\d+)?)", re.I),
    # "Corriente máxima de salida ..."
    re.compile(r"corriente\s*m[aá]xima\s*de\s*salida[^0-9]{0,40}(\d{1,3}(?:[.,]\d+)?)", re.I),
    # "Corriente nominal de CA 28,8 A"
    re.compile(r"corriente\s*nominal\s*de\s*ca[^0-9]{0,40}(\d{1,3}(?:[.,]\d+)?)", re.I),
    # Inglés genérico
    re.compile(r"(?:max(?:imum)?\s*)?output\s*current[^0-9]{0,40}(\d{1,3}(?:[.,]\d+)?)", re.I),
]

# Eficiencia máxima / CEC
PAT_EFF_MAX = [
    re.compile(r"eficiencia\s*m[aá]xima[^0-9]{0,12}(\d{1,2}(?:[.,]\d+)?)\s*%\b", re.I),
    re.compile(r"(?:max(?:imum)?\s*)?efficiency[^0-9]{0,12}(\d{1,2}(?:[.,]\d+)?)\s*%\b", re.I),
]

PAT_EFF_CEC = [
    re.compile(r"cec\s*efficiency[^0-9]{0,12}(\d{1,2}(?:[.,]\d+)?)\s*%\b", re.I),
]

# Tensión de salida AC nominal
PAT_VOUT = [
    re.compile(r"tensi[oó]n\s*nominal\s*de\s*la\s*red[^0-9]{0,12}(\d{2,4}(?:[.,]\d+)?)\s*v\b", re.I),
    re.compile(r"(?:nominal\s*)?ac\s*output\s*voltage[^0-9]{0,12}(\d{2,4}(?:[.,]\d+)?)\s*v\b", re.I),
    re.compile(r"voltaje\s*nominal[^0-9]{0,12}(\d{2,4}(?:[.,]\d+)?)\s*v\b", re.I),
    # "Tensión nominal de la red ..."
    re.compile(r"tensi[oó]n\s*nominal\s*de\s*la\s*red[^0-9]{0,40}(\d{2,4}(?:[.,]\d+)?)\s*k?v\b", re.I),
    # "Tensión de trabajo, red +/- 10 % UCA 20 kV"
    re.compile(r"tensi[oó]n\s*de\s*trabajo[^0-9]{0,40}(\d{2,4}(?:[.,]\d+)?)\s*k?v\b", re.I),
    # Inglés
    re.compile(r"(?:nominal\s*)?ac\s*output\s*voltage[^0-9]{0,40}(\d{2,4}(?:[.,]\d+)?)\s*k?v\b", re.I),
    re.compile(r"voltaje\s*nominal[^0-9]{0,40}(\d{2,4}(?:[.,]\d+)?)\s*k?v\b", re.I),
]

# Frecuencia
PAT_FREQ = [
    re.compile(r"frecuencia\s*nominal[^0-9]{0,12}(\d{2,3}(?:[.,]\d+)?)\s*hz\b", re.I),
    re.compile(r"(?:nominal\s*)?frequen(?:cy|cia)[^0-9]{0,12}(\d{2,3}(?:[.,]\d+)?)\s*hz\b", re.I),
    re.compile(r"frequen(?:cy|cia)[^0-9]{0,40}(\d{2,3}(?:[.,]\d+)?)\s*hz\b", re.I),
]

# Rango de factor de potencia (lo guardamos como string)
PAT_PF_RANGE = [
    re.compile(r"factor\s*de\s*potencia[^:]*:\s*([0-9>.<=()\s\-a]+)", re.I),
    re.compile(r"power\s*factor\s*range[^:]*:\s*([0-9>.<=()\s\-a]+)", re.I),
    # Formato con ":" (por si acaso)
    re.compile(r"factor\s*de\s*potencia[^:]*:\s*([0-9>.<=()\s\-a,]+)", re.I),
    re.compile(r"power\s*factor\s*range[^:]*:\s*([0-9>.<=()\s\-a,]+)", re.I),
    # Formato del SC1000: "Factor de potencia cos φ ≥ 0,99 a potencia nominal"
    re.compile(r"factor\s*de\s*potencia[^0-9]{0,40}([0-9.,]+)", re.I),
]

PAT_IP = [
    re.compile(r"\bIP\d{2}\b", re.I)
]

# =====================
# Extractores
# =====================

def extract_panel(text: str) -> Dict[str, Optional[str]]:
    out = {k: None for k in PANEL_FIELDS}

    # ---------- Potencia nominal (W o kW) ----------
    pmax_val = None
    for p in PAT_POT_PANEL:
        m = p.search(text)
        if m:
            raw = m.group(1)
            num = to_float_safe(raw)
            if num is None:
                continue
            whole = m.group(0).lower()
            # Si el texto trae "kw" y el número es razonable (< 1000), lo convertimos a W
            if "kw" in whole and num < 1000:
                num *= 1000.0
            pmax_val = num
            break
    out["potencia_nominal_W"] = pmax_val

    # ---------- Parámetros eléctricos básicos ----------
    out["Voc_V"] = to_float_safe(find_first(PAT_VOC, text))
    out["Isc_A"] = to_float_safe(find_first(PAT_ISC, text))
    out["Vmp_V"] = to_float_safe(find_first(PAT_VMP, text))
    out["Imp_A"] = to_float_safe(find_first(PAT_IMP, text))

    # ---------- Dimensiones ----------
    # Ej: "Dimension 1956 x 992 x 50 mm"
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
                # vertical = lado más largo, horizontal = más corto
                if a >= b:
                    out["dim_vertical_mm"], out["dim_horizontal_mm"] = a, b
                else:
                    out["dim_vertical_mm"], out["dim_horizontal_mm"] = b, a
            break

    # ---------- Peso ----------
    w = find_first(PAT_WEIGHT, text)
    out["peso_kg"] = to_float_safe(w) if w else None

    # ---------- Tensión de sistema y coeficientes ----------
    out["tension_sistema_max_V"] = to_float_safe(find_first(PAT_SYSTEM_VOLT, text))
    out["coef_temp_Voc_pct_C"] = to_float_safe(find_first(PAT_TEMP_COEF_VOC, text))
    out["coef_temp_Pmax_pct_C"] = to_float_safe(find_first(PAT_TEMP_COEF_PMAX, text))

    # ---------- IP rating ----------
    out["ip_rating"] = find_first(PAT_IP, text)

    # ---------- Extras: tipo de conector y celdas (heurísticos) ----------
    # Conector: línea tipo "Conectores MC4 Compatible"
    m_conn = re.search(r"conectores?\s*([^\n\r]+)", text, re.I)
    if m_conn:
        out["tipo_conector"] = m_conn.group(1).strip()
    else:
        # fallback rápido: si aparece "MC4" en el texto
        if "mc4" in text.lower():
            out["tipo_conector"] = "MC4 compatible"

    # Celdas: "Celulas 72=6x12 policristalinas"
    m_cells = re.search(r"c[eé]lulas?\s*([0-9]{2,3}(?:\s*=\s*[0-9xX]+)?)", text, re.I)
    if m_cells:
        out["celdas"] = m_cells.group(1).strip()

    return out


def guess_phase(s: str) -> Optional[str]:
    s_low = s.lower()
    if re.search(r"\btrif[aá]sico|\bthree[-\s]?phase", s_low):
        return "trifasico"
    if re.search(r"\bbif[aá]sico|\bbi[-\s]?phase", s_low):
        return "bifasico"
    if re.search(r"\bmonof[aá]sico|\bsingle[-\s]?phase", s_low):
        return "monofasico"
    return None


def extract_inversor(text: str) -> Dict[str, Optional[str]]:
    out = {k: None for k in INV_FIELDS}

    # ---------- Potencia AC nominal (W o kW) ----------
    pot_nom = None
    for p in PAT_P_AC_NOM:
        m = p.search(text)
        if m:
            raw = m.group(1)
            num = to_float_safe(raw)
            if num is None:
                continue
            whole = m.group(0).lower()
            # Si el texto trae "kw" o "kva" y el número es razonable -> convertir a W
            if ("kw" in whole or "kva" in whole) and num < 1000:
                num *= 1000.0
            pot_nom = num
            break
    out["potencia_AC_nominal_W"] = pot_nom

    # ---------- Potencia AC máxima (W o kW) ----------
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

    # ---------- MPPT ----------
    mppt = find_first(PAT_MPPT_CNT, text)
    try:
        out["mppt_cantidad"] = int(float(mppt)) if mppt else None
    except ValueError:
        out["mppt_cantidad"] = None

    # ---------- DC side ----------
    out["Vdc_max"] = to_float_safe(find_first(PAT_VDC_MAX, text))
    out["isc_max_por_mppt_A"] = to_float_safe(find_first(PAT_ISC_PER_MPPT, text))

    # ---------- AC side ----------
    out["salida_corriente_max_A"] = to_float_safe(find_first(PAT_AC_OUT_CURRENT_MAX, text))
    out["tipo_fase"] = guess_phase(text)
    out["eficiencia_max_pct"] = to_float_safe(find_first(PAT_EFF_MAX, text))
    out["eficiencia_CEC_pct"] = to_float_safe(find_first(PAT_EFF_CEC, text))

    # ---------- Tensión nominal de salida AC (V o kV) ----------
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
        # Si trae "kv" y el número es razonable, convertimos a V
        if "kv" in whole and num < 1000:
            num *= 1000.0
        vout_val = num
        break
    out["tension_salida_nominal_V"] = vout_val

    out["frecuencia_Hz"] = to_float_safe(find_first(PAT_FREQ, text))

    # ---------- Factor de potencia / IP ----------
    out["pf_range"] = find_first(PAT_PF_RANGE, text)
    out["ip_rating"] = find_first(PAT_IP, text)

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


# 👇 Esto era para pruebas locales con rutas fijas. Puedes comentarlo si usarás CLI real.
sys.argv = [
    "extract",
    r"C:\Users\macia\Documents\Proyectos\MacBec\solar-extractor\PDFS",
    "--outdir", r"C:\Users\macia\Documents\Proyectos\MacBec\solar-extractor\build",
    "--debug",
    "--dump-text"
]

# =====================
# Main
# =====================

def main():
    ap = argparse.ArgumentParser(description="Extractor de especificaciones solares (paneles/inversores) desde PDFs (FINAL)")
    ap.add_argument("input", help="Carpeta con PDFs")
    ap.add_argument("--outdir", default=".", help="Carpeta de salida (por defecto: .)")
    ap.add_argument("--paneles", default="paneles.csv", help="Nombre CSV paneles")
    ap.add_argument("--inversores", default="inversores.csv", help="Nombre CSV inversores")
    ap.add_argument("--meta", help="CSV opcional con filename,fabricante,modelo,tipo,url", default=None)
    # Depuración
    ap.add_argument("--debug", action="store_true", help="Imprime coincidencias por campo y clasificación")
    ap.add_argument("--dump-text", action="store_true", help="Guarda texto en outdir/_debug_text/ (normal y _AUG)")
    ap.add_argument("--force-type", choices=["panel","inversor"], help="Forzar clasificación global")
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
    panel_rows, inv_rows = [], []

    for pdf_path in sorted(in_dir.glob("**/*.pdf")):
        try:
            # 1) Texto base del PDF
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

            # Texto aumentado = texto base + tablas
            txt_aug = norm((txt_norm + "\n" + txt_tables).strip())

            # 3) Dump para depurar
            if args.dump_text:
                (dump_dir / f"{pdf_path.stem}.txt").write_text(txt_norm, encoding="utf-8", errors="ignore")
                (dump_dir / f"{pdf_path.stem}_AUG.txt").write_text(txt_aug, encoding="utf-8", errors="ignore")

            # 4) Meta (fabricante, modelo, url)
            meta_row = meta.get(pdf_path.name.lower(), {})
            fabricante = meta_row.get("fabricante") or None
            modelo = meta_row.get("modelo") or None
            url = meta_row.get("url") or ""

            # 5) Clasificación combinando extractores + heurística
            tipo_forzado = args.force_type or (meta_row.get("tipo") if meta_row else None)
            is_panel = is_inversor = False
            row_panel = row_inv = None

            if tipo_forzado == "panel":
                is_panel = True
            elif tipo_forzado == "inversor":
                is_inversor = True
            else:
                # 5.1 Intentar extracción de ambos tipos
                tmp_panel = extract_panel(txt_aug)
                tmp_inv = extract_inversor(txt_aug)

                core_panel = ["potencia_nominal_W", "Voc_V", "Isc_A", "Vmp_V", "Imp_A"]
                core_inv = ["potencia_AC_nominal_W", "Vdc_max", "isc_max_por_mppt_A",
                            "salida_corriente_max_A", "mppt_cantidad"]

                score_panel = sum(1 for k in core_panel if tmp_panel.get(k) not in (None, 0))
                score_inv = sum(1 for k in core_inv if tmp_inv.get(k) not in (None, 0))

                if score_panel == 0 and score_inv == 0:
                    # 5.2 Fallback a heurística de palabras clave
                    t = txt_aug.lower()
                    panel_score = sum(t.count(k) for k in [
                        "pmax","pmpp","wp","module","panel","módulo","voc","open-circuit voltage","voltaje de circuito abierto",
                        "isc","short-circuit current","corriente de corto circuito","vmp","voltage at pmax","v@pmax","voltaje en pmax",
                        "imp","current at pmax","i@pmax","corriente en pmax","dimensiones","dimensions"," mm ","×"," x "
                    ])
                    inv_score = sum(t.count(k) for k in [
                        "mppt","inversor","inverter","dc input voltage","max dc input voltage","vdc max","tensión dc máx",
                        "output current","corriente de salida","ac output voltage","ac voltage","frecuencia","frequency",
                        "potencia ac","rated ac power","nominal ac power","pf","power factor",
                        "monofásico","bifásico","trifásico","single-phase","three-phase"
                    ])

                    if inv_score > panel_score:
                        is_inversor = True
                    elif panel_score > inv_score:
                        is_panel = True
                    else:
                        # Empate: si aparece "inversor" o "inverter", nos vamos a inversor
                        is_inversor = ("mppt" in t or "inversor" in t or "inverter" in t)
                        is_panel = not is_inversor
                else:
                    # 5.3 Elegir por número de campos bien extraídos
                    if score_panel > score_inv:
                        is_panel = True
                        row_panel = tmp_panel
                    elif score_inv > score_panel:
                        is_inversor = True
                        row_inv = tmp_inv
                    else:
                        # empate con datos: delegamos al fallback 5.4
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
                    if any(tmp_inv2.get(k) for k in ["Vdc_max", "mppt_cantidad", "salida_corriente_max_A",
                                                      "potencia_AC_nominal_W"]):
                        is_inversor = True
                        row_inv = tmp_inv2
                    else:
                        print(f"[WARN] {pdf_path.name}: no se pudo extraer nada útil.")
                        continue  # saltamos este PDF

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
                    print(f"[DEBUG][PANEL] Pmax={row.get('potencia_nominal_W')} Voc={row.get('Voc_V')} Isc={row.get('Isc_A')} Vmp={row.get('Vmp_V')} Imp={row.get('Imp_A')}")

            elif is_inversor:
                if row_inv is None:
                    row_inv = extract_inversor(txt_aug)
                row = row_inv
                row["fabricante"] = fabricante
                row["modelo"] = modelo
                row["ficha_tecnica_url"] = url
                inv_rows.append(row)
                if args.debug:
                    print(f"[DEBUG][INV] Vdc_max={row.get('Vdc_max')} MPPT={row.get('mppt_cantidad')} IoutMax={row.get('salida_corriente_max_A')}")

        except Exception as e:
            print(f"[ERROR] {pdf_path.name}: {e}")

    # 7) Escribir CSVs
    write_csv(outdir / (args.paneles or "paneles.csv"), PANEL_FIELDS, panel_rows)
    write_csv(outdir / (args.inversores or "inversores.csv"), INV_FIELDS, inv_rows)
    print(f"Listo.\n - Paneles: {outdir / (args.paneles or 'paneles.csv')}\n - Inversores: {outdir / (args.inversores or 'inversores.csv')}")

if __name__ == "__main__":
    main()