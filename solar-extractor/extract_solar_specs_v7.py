#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
extract_solar_specs_v7.py

Extractor V7 – HÍBRIDO:
-----------------------
1) Lectura de PDFs con PyMuPDF (fitz).
2) Modo TABLAS (visual, como V6C):
   - Renderizado a imagen.
   - OpenCV: umbral adaptativo, morfología, detección de celdas.
   - OCR por celda con Tesseract.
   - Matching etiqueta → valor por proximidad + patrones.

3) Modo TEXTO (tipo V1–V5 mejorado, híbrido PyMuPDF + OCR de página):
   - Extracción de texto nativo (page.get_text()).
   - Si casi no hay texto, OCR de página completa.
   - Regex en español/inglés para paneles e inversores.
   - Corrección de valores (rangos, unidades).

4) Integración:
   - Primero llena campos con tablas.
   - Luego rellena vacíos usando el texto global.
   - Exporta paneles.csv e inversores.csv.

Uso:

    python extract_solar_specs_v7.py <carpeta_pdf> [--debug]

Requisitos:
    pip install pymupdf opencv-python numpy pytesseract pandas pillow
    + Tesseract instalado en el sistema y en el PATH.
"""

import os
import sys
import logging
import math
import re
from dataclasses import dataclass, field
from typing import List, Tuple, Dict, Optional
import json
import fitz  # PyMuPDF
import cv2
import numpy as np
import pytesseract
import pandas as pd
from PIL import Image

# ---------------------------------------------------------------------
# CONFIGURACIÓN GLOBAL
# ---------------------------------------------------------------------

# Si necesitas ruta específica de Tesseract, descomenta y ajusta:
# pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
BUILD_DIR = os.path.join(BASE_DIR, "build")
DEBUG_DIR = os.path.join(BUILD_DIR, "_debug")
TABLES_DIR = os.path.join(BUILD_DIR, "_tables")

os.makedirs(DEBUG_DIR, exist_ok=True)
os.makedirs(TABLES_DIR, exist_ok=True)

LOG_FILE = os.path.join(DEBUG_DIR, "extract_v7.log")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ],
)

logger = logging.getLogger("V7")

DEBUG_MODE = False  # se activa con flag --debug

# ---------------------------------------------------------------------
# CONFIGURACIÓN FIJA DEL PROYECTO
# ---------------------------------------------------------------------

DEFAULT_PDF_FOLDER = r"C:\Users\macia\Documents\Proyectos\MacBec\solar-extractor\PDFS"



# ---------------------------------------------------------------------
# DATACLASSES
# ---------------------------------------------------------------------

@dataclass
class Cell:
    page_index: int
    table_id: int
    row: int
    col: int
    x: int
    y: int
    w: int
    h: int
    text: str = ""


@dataclass
class Table:
    page_index: int
    table_id: int
    bbox: Tuple[int, int, int, int]
    cells: List[Cell] = field(default_factory=list)


# ---------------------------------------------------------------------
# RANGOS Y PATRONES SEMÁNTICOS
# ---------------------------------------------------------------------

# Patrones por etiqueta para modo TABLA (igual idea que V6C)
PANEL_PATTERNS = {
    "Pmax": [
        "pmax", "max power", "maximum power", "rated power", "nominal power",
        "power at stc", "module power", "potencia nominal", "potencia maxima",
        "output power"
    ],
    "Voc": [
        "voc", "open circuit voltage", "voltaje de circuito abierto",
        "tension de circuito abierto"
    ],
    "Isc": [
        "isc", "short circuit current", "corriente de cortocircuito",
        "corriente de corto circuito"
    ],
    "Vmp": [
        "vmp", "voltage at mpp", "voltage at pmax",
        "tension a potencia maxima", "tension en mpp"
    ],
    "Imp": [
        "imp", "current at mpp", "corriente en mpp",
        "corriente a potencia maxima"
    ],
    "Length": [
        "length", "largo", "height", "altura", "dimension largo"
    ],
    "Width": [
        "width", "ancho", "dimension ancho"
    ],
    "Weight_panel": [
        "weight", "peso", "module weight"
    ],
}

INVERTER_PATTERNS = {
    "P_ac_nominal": [
        "rated ac output power", "nominal ac power",
        "potencia nominal de salida", "potencia nominal ac"
    ],
    "P_ac_max": [
        "max ac output power", "maximum ac power",
        "salida ac maxima", "potencia maxima ac"
    ],
    "Vdc_max": [
        "max pv voltage", "max dc voltage", "maximum dc voltage",
        "max input voltage", "vdc max", "max. dc voltage"
    ],
    "I_mppt_max": [
        "max input current per mppt", "max input current",
        "corriente maxima por mppt", "corriente max mppt"
    ],
    "MPPT_count": [
        "mppt", "number of mppt", "mpp tracker", "mpp trackers",
        "cantidad de mppt"
    ],
    "I_out_max": [
        "max output current", "corriente de salida maxima",
        "max ac output current"
    ],
    "P_pv_max": [
    "max pv power",
    "maximum pv power",
    "recommended pv power",
    "potencia maxima fotovoltaica",
    "potencia recomendada del generador"
    ],
}

# ---------------------------------------------------------------------
# UTILIDADES GENERALES
# ---------------------------------------------------------------------

def normalize_text(s: str) -> str:
    if not s:
        return ""
    s = s.lower()
    s = re.sub(r"[^0-9a-záéíóúüñ]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def is_mostly_numeric(s: str) -> bool:
    if not s:
        return False
    s_clean = s.replace(" ", "")
    digits = sum(c.isdigit() for c in s_clean)
    return digits >= max(1, int(0.5 * len(s_clean)))


def distance(c1: Cell, c2: Cell) -> float:
    cx1 = c1.x + c1.w / 2.0
    cy1 = c1.y + c1.h / 2.0
    cx2 = c2.x + c2.w / 2.0
    cy2 = c2.y + c2.h / 2.0
    return math.hypot(cx2 - cx1, cy2 - cy1)


def ensure_dirs():
    os.makedirs(DEBUG_DIR, exist_ok=True)
    os.makedirs(TABLES_DIR, exist_ok=True)

def safe_cast(val):
    """
    Intenta convertir a float.
    Si no es posible, regresa el valor original (string).
    """
    try:
        return float(val)
    except (ValueError, TypeError):
        return val
    
def in_range(val, min_v, max_v):
    return val is not None and min_v <= val <= max_v


def add_derived(diagnostics, field, value, method, confidence):
    entry = {
        "field": field,
        "value": round(value, 3),
        "method": method,
        "confidence": round(confidence, 2),
    }
    if confidence < 0.75:
        entry["warning"] = "Confianza < 75%, favor de corroborar con PDF"
    diagnostics["derived_fields"].append(entry)

def validate_and_infer_panel(panel: dict) -> dict:
    diagnostics = {
        "missing_fields": [],
        "derived_fields": [],
        "warnings": []
    }

    # Rangos físicos razonables
    RANGES = {
        "voc_v": (25, 80),
        "isc_a": (5, 25),
        "vmp_v": (20, 70),
        "imp_a": (3, 25),
        "power_w": (50, 800),
    }

    P = panel.get("power_w")
    Voc = panel.get("voc_v")
    Isc = panel.get("isc_a")
    Vmp = panel.get("vmp_v")
    Imp = panel.get("imp_a")

    # Validaciones directas
    for field, (mn, mx) in RANGES.items():
        if panel.get(field) is not None and not in_range(panel[field], mn, mx):
            diagnostics["warnings"].append(
                f"Valor fuera de rango físico esperado: {field}={panel[field]}"
            )

    # Inferir Imp
    if Imp is None and P and Vmp:
        calc = P / Vmp
        if Isc is None or calc < Isc:
            panel["imp_a"] = calc
            add_derived(diagnostics, "imp_a", calc, "power_w / vmp_v", 0.72)

    # Inferir Vmp
    if Vmp is None and P and Imp:
        calc = P / Imp
        if Voc is None or calc < Voc:
            panel["vmp_v"] = calc
            add_derived(diagnostics, "vmp_v", calc, "power_w / imp_a", 0.72)

    # Inferir Power
    if P is None and Vmp and Imp:
        calc = Vmp * Imp
        panel["power_w"] = calc
        add_derived(diagnostics, "power_w", calc, "vmp_v * imp_a", 0.75)

    # Validaciones físicas
    if panel.get("vmp_v") and panel.get("voc_v"):
        if panel["vmp_v"] >= panel["voc_v"]:
            diagnostics["warnings"].append("vmp_v >= voc_v (inconsistencia física)")

    if panel.get("imp_a") and panel.get("isc_a"):
        if panel["imp_a"] >= panel["isc_a"]:
            diagnostics["warnings"].append("imp_a >= isc_a (inconsistencia física)")

    # Campos críticos obligatorios
    REQUIRED = [
        "power_w",
        "voc_v",
        "isc_a",
        "vmp_v",
        "imp_a",
        "panel_width_mm",
        "panel_height_mm",
    ]

    for field in REQUIRED:
        if panel.get(field) is None:
            diagnostics["missing_fields"].append(field)

    panel["diagnostics"] = diagnostics
    return panel

def validate_and_infer_inverter(inv: dict) -> dict:
    diagnostics = {
        "missing_fields": [],
        "derived_fields": [],
        "warnings": []
    }

    RANGES = {
        "max_dc_voltage_v": (300, 1500),
        "max_isc_per_mppt_a": (10, 40),
        "max_ac_output_current_a": (5, 100),
        "mppt_count": (1, 12),
    }

    for field, (mn, mx) in RANGES.items():
        if inv.get(field) is not None and not in_range(inv[field], mn, mx):
            diagnostics["warnings"].append(
                f"Valor fuera de rango esperado: {field}={inv[field]}"
            )

    # Inferencia conservadora de potencia PV
    if inv.get("max_pv_power_w") is None:
        ac_current = inv.get("max_ac_output_current_a")
        if ac_current:
            estimate = ac_current * 230  # monofásico conservador
            inv["max_pv_power_w"] = estimate
            add_derived(
                diagnostics,
                "max_pv_power_w",
                estimate,
                "max_ac_output_current_a * 230V",
                0.65
            )

    REQUIRED = [
        "max_dc_voltage_v",
        "mppt_count",
        "max_isc_per_mppt_a",
        "max_ac_output_current_a",
        "inverter_type",
        "max_pv_power_w",
    ]

    for field in REQUIRED:
        if inv.get(field) is None:
            diagnostics["missing_fields"].append(field)

    inv["diagnostics"] = diagnostics
    return inv



# ---------------------------------------------------------------------
# LECTURA A IMÁGENES Y TEXTO
# ---------------------------------------------------------------------

def render_pdf_to_images_and_text(pdf_path: str, dpi: int = 200) -> Tuple[List[np.ndarray], str]:
    """
    Renderiza cada página del PDF a imagen BGR y construye texto global:

    - Primero intenta page.get_text("text").
    - Si la página casi no tiene texto, hace OCR de página completa.
    """
    logger.info(f"Renderizando PDF → imágenes + texto: {pdf_path}")
    doc = fitz.open(pdf_path)
    images = []
    text_pages = []

    zoom = dpi / 72.0
    mat = fitz.Matrix(zoom, zoom)

    for page_index in range(len(doc)):
        page = doc[page_index]
        pix = page.get_pixmap(matrix=mat)
        mode = "RGB" if pix.alpha == 0 else "RGBA"
        img = Image.frombytes(mode, [pix.width, pix.height], pix.samples)
        if mode == "RGBA":
            img = img.convert("RGB")
        img_bgr = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
        images.append(img_bgr)

        # TEXTO nativo
        page_text = page.get_text("text") or ""
        if len(page_text.strip()) < 40:
            # Fallback: OCR de página completa
            gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
            gray = cv2.medianBlur(gray, 3)
            _, thr = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            ocr_pg = pytesseract.image_to_string(
                thr,
                lang="eng",
                config="--oem 3 --psm 6",
            )
            logger.debug(f"[P{page_index}] OCR página por texto escaso.")
            page_text = (page_text or "") + "\n" + (ocr_pg or "")

        text_pages.append(page_text)

    doc.close()
    full_text = "\n".join(text_pages)
    return images, full_text


# ---------------------------------------------------------------------
# DETECCIÓN VISUAL DE TABLAS (V6C)
# ---------------------------------------------------------------------

def detect_tables_on_page(img_bgr: np.ndarray, page_index: int, pdf_basename: str) -> List[Table]:
    logger.info(f"[P{page_index}] Detectando tablas (modo visual)")
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    gray_inv = cv2.bitwise_not(gray)
    thr = cv2.adaptiveThreshold(
        gray_inv, 255,
        cv2.ADAPTIVE_THRESH_MEAN_C,
        cv2.THRESH_BINARY,
        15, -2
    )

    h_kernel_len = max(10, img_bgr.shape[1] // 40)
    v_kernel_len = max(10, img_bgr.shape[0] // 40)

    horiz_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (h_kernel_len, 1))
    vert_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, v_kernel_len))

    horizontal_lines = cv2.erode(thr, horiz_kernel, iterations=1)
    horizontal_lines = cv2.dilate(horizontal_lines, horiz_kernel, iterations=1)

    vertical_lines = cv2.erode(thr, vert_kernel, iterations=1)
    vertical_lines = cv2.dilate(vertical_lines, vert_kernel, iterations=1)

    table_mask = cv2.add(horizontal_lines, vertical_lines)

    if cv2.countNonZero(table_mask) < 100:
        logger.info(f"[P{page_index}] Máscara pobre, usando fallback borderless")
        table_mask = thr.copy()

    contours, _ = cv2.findContours(table_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    tables: List[Table] = []
    table_id_counter = 0

    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        area = w * h
        if area < 10000:
            continue
        if w < 0.15 * img_bgr.shape[1]:
            continue

        table_id = table_id_counter
        table_id_counter += 1
        table_bbox = (x, y, w, h)
        table_roi = thr[y:y + h, x:x + w]

        cells_rects = detect_cells_in_table(table_roi, x, y)

        table = Table(
            page_index=page_index,
            table_id=table_id,
            bbox=table_bbox,
            cells=[]
        )

        cells_with_rc = assign_rows_cols_to_cells(cells_rects)

        for (cx, cy, cw, ch, row, col) in cells_with_rc:
            table.cells.append(Cell(
                page_index=page_index,
                table_id=table_id,
                row=row,
                col=col,
                x=cx,
                y=cy,
                w=cw,
                h=ch
            ))
        if table.cells:
            tables.append(table)

    # DEBUG: Imagen con bounding boxes
    debug_img = img_bgr.copy()
    for t in tables:
        x, y, w, h = t.bbox
        cv2.rectangle(debug_img, (x, y), (x + w, y + h), (0, 0, 255), 2)
        for c in t.cells:
            cv2.rectangle(debug_img, (c.x, c.y), (c.x + c.w, c.y + c.h), (0, 255, 0), 1)

    debug_out = os.path.join(TABLES_DIR, f"{pdf_basename}_page{page_index}_tables.png")
    cv2.imwrite(debug_out, debug_img)
    logger.info(f"[P{page_index}] Debug tablas guardado en {debug_out}")

    return tables


def detect_cells_in_table(table_thr: np.ndarray, offset_x: int, offset_y: int) -> List[Tuple[int, int, int, int]]:
    contours, _ = cv2.findContours(table_thr, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)

    rects = []
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        area = w * h
        if area < 200:
            continue
        if w > 0.9 * table_thr.shape[1] and h > 0.9 * table_thr.shape[0]:
            continue
        rects.append((x + offset_x, y + offset_y, w, h))

    rects = merge_overlapping_rects(rects)
    return rects


def merge_overlapping_rects(rects: List[Tuple[int, int, int, int]],
                            iou_threshold: float = 0.3) -> List[Tuple[int, int, int, int]]:
    if not rects:
        return []
    rects = sorted(rects, key=lambda r: (r[1], r[0]))
    merged = []

    def iou(r1, r2):
        x1, y1, w1, h1 = r1
        x2, y2, w2, h2 = r2
        xa = max(x1, x2)
        ya = max(y1, y2)
        xb = min(x1 + w1, x2 + w2)
        yb = min(y1 + h1, y2 + h2)
        if xb <= xa or yb <= ya:
            return 0.0
        inter = (xb - xa) * (yb - ya)
        union = w1 * h1 + w2 * h2 - inter
        return inter / union if union > 0 else 0

    for r in rects:
        if not merged:
            merged.append(r)
            continue
        last = merged[-1]
        if iou(last, r) > iou_threshold:
            x = min(last[0], r[0])
            y = min(last[1], r[1])
            x2 = max(last[0] + last[2], r[0] + r[2])
            y2 = max(last[1] + last[3], r[1] + r[3])
            merged[-1] = (x, y, x2 - x, y2 - y)
        else:
            merged.append(r)
    return merged


def assign_rows_cols_to_cells(rects: List[Tuple[int, int, int, int]],
                              y_tol: int = 10,
                              x_tol: int = 10) -> List[Tuple[int, int, int, int, int, int]]:
    if not rects:
        return []
    rects_sorted = sorted(rects, key=lambda r: (r[1], r[0]))

    rows: List[List[Tuple[int, int, int, int]]] = []
    row_centers: List[float] = []

    for r in rects_sorted:
        x, y, w, h = r
        cy = y + h / 2.0
        assigned = False
        for idx, rc in enumerate(row_centers):
            if abs(cy - rc) <= y_tol:
                rows[idx].append(r)
                row_centers[idx] = (row_centers[idx] * (len(rows[idx]) - 1) + cy) / len(rows[idx])
                assigned = True
                break
        if not assigned:
            rows.append([r])
            row_centers.append(cy)

    all_cells = []
    for row_i, row_rects in enumerate(rows):
        row_rects_sorted = sorted(row_rects, key=lambda r: r[0])
        col_centers: List[float] = []
        col_indices: List[int] = []

        for r in row_rects_sorted:
            x, y, w, h = r
            cx = x + w / 2.0
            assigned = False
            for idx, cc in enumerate(col_centers):
                if abs(cx - cc) <= x_tol:
                    col_indices.append(idx)
                    col_centers[idx] = (col_centers[idx] * (col_indices.count(idx) - 1) + cx) / col_indices.count(idx)
                    assigned = True
                    break
            if not assigned:
                col_centers.append(cx)
                col_indices.append(len(col_centers) - 1)

        for r, col_idx in zip(row_rects_sorted, col_indices):
            x, y, w, h = r
            all_cells.append((x, y, w, h, row_i, col_idx))

    return all_cells


# ---------------------------------------------------------------------
# OCR POR CELDA Y CORRECCIÓN DE VALORES
# ---------------------------------------------------------------------

def parse_numeric_from_text(raw: str) -> Optional[float]:
    if not raw:
        return None
    s = raw.replace(",", ".")
    m = re.search(r"[-+]?\d+(?:\.\d+)?", s)
    if not m:
        return None
    try:
        return float(m.group(0))
    except Exception:
        return None


def correct_value_by_range(
    value: Optional[float],
    raw: str,
    key_hint: Optional[str] = None
) -> Optional[float]:
    if value is None:
        return None

    raw_norm = raw.lower().replace(" ", "")

    if raw_norm in ("000", "0.0", "0,0"):
        return None

    # kW → W
    if "kw" in raw_norm and value < 1000:
        value *= 1000.0

    if key_hint and key_hint in VALUE_RANGES:
        low, high = VALUE_RANGES[key_hint]
        if value < low:
            for factor in (10, 100):
                new_val = value * factor
                if low <= new_val <= high:
                    value = new_val
                    break
        elif value > high * 10:
            for factor in (0.1, 0.01):
                new_val = value * factor
                if low <= new_val <= high:
                    value = new_val
                    break
        if value < 0:
            return None

    return value


def clean_and_parse_value(raw: str, key_hint: Optional[str] = None) -> Tuple[Optional[float], str]:
    if not raw:
        return None, ""
    raw_stripped = raw.strip()
    text_norm = raw_stripped.replace("\n", " ").strip()
    value = parse_numeric_from_text(raw_stripped)
    value = correct_value_by_range(value, raw_stripped, key_hint=key_hint)
    return value, text_norm


# ---------------------------------------------------------------------
# MATCHING ETIQUETA → VALOR (MODO TABLA)
# ---------------------------------------------------------------------

def match_label_to_value_cells(table: Table) -> List[Tuple[Cell, Cell]]:
    label_candidates = [c for c in table.cells if not is_mostly_numeric(c.text)]
    value_candidates = [c for c in table.cells if is_mostly_numeric(c.text)]

    pairs = []
    for label in label_candidates:
        best_val = None
        best_score = float("inf")
        for val in value_candidates:
            dy = abs((label.y + label.h / 2) - (val.y + val.h / 2))
            dx = (val.x + val.w / 2) - (label.x + label.w / 2)
            if dx < -5:
                score = dy * 3 + abs(dx) * 5
            else:
                score = dy * 2 + abs(dx)
            if score < best_score:
                best_score = score
                best_val = val
        if best_val is not None:
            pairs.append((label, best_val))
    return pairs


def classify_pair(label_text: str, value_text: str) -> Tuple[Optional[str], Optional[str]]:
    lab_norm = normalize_text(label_text)

    for key, patterns in PANEL_PATTERNS.items():
        for p in patterns:
            if p in lab_norm:
                return key, None

    for key, patterns in INVERTER_PATTERNS.items():
        for p in patterns:
            if p in lab_norm:
                return None, key

    if "efficiency" in lab_norm or "eficiencia" in lab_norm:
        return None, "eff_max"

    if "mppt" in lab_norm or "mpp tracker" in lab_norm or "mpp trackers" in lab_norm:
        return None, "MPPT_count"

    return None, None


# ---------------------------------------------------------------------
# EXTRACCIÓN TEXTO → ESPECIFICACIONES
# ---------------------------------------------------------------------

def _panel_hint(key: str) -> Optional[str]:
    if key == "Pmax":
        return "Pmax"
    if key in ("Voc", "Vsys_max"):
        return "Voc"
    if key == "Vmp":
        return "Vmp"
    if key == "Isc":
        return "Isc"
    if key == "Imp":
        return "Imp"
    if key == "TempCoeff_Voc":
        return "Voc"
    if key == "TempCoeff_Pmax":
        return "Pmax"
    return None


def _inverter_hint(key: str) -> Optional[str]:
    if key == "Vdc_max":
        return "Vdc_max"
    if key == "MPPT_count":
        return "MPPT"
    return None

def detect_panel_models_from_text(text: str) -> List[str]:
    """
    Detecta múltiples modelos de panel dentro de un datasheet.
    Ejemplos:
    JAM72D40-590/LB
    JAM72D40-595
    650-670M-132
    """
    patterns = [
        r"[A-Z]{2,}\d{2,}[A-Z]*[-/]\d{3,4}[A-Z]*",
        r"\d{3,4}[-–]\d{3,4}[A-Z]*",
    ]

    found = set()
    for pat in patterns:
        for m in re.findall(pat, text):
            found.add(m.strip())

    return sorted(found)

def _preprocess_variants(gray: np.ndarray) -> List[np.ndarray]:
    outs = []

    # 1) Otsu
    g1 = cv2.medianBlur(gray, 3)
    _, th1 = cv2.threshold(g1, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    outs.append(th1)

    # 2) Adaptive
    th2 = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                cv2.THRESH_BINARY, 31, 5)
    outs.append(th2)

    # 3) Morph close (para letras rotas)
    k = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
    th3 = cv2.morphologyEx(th1, cv2.MORPH_CLOSE, k, iterations=1)
    outs.append(th3)

    return outs


def _tess_score(data: Dict) -> float:
    confs = []
    for c in data.get("conf", []):
        try:
            v = float(c)
            if v >= 0:
                confs.append(v)
        except:
            pass
    return float(np.mean(confs)) if confs else 0.0


def ocr_cell_best(img_bgr: np.ndarray, cell: Cell) -> str:
    x, y, w, h = cell.x, cell.y, cell.w, cell.h
    h_pad = int(h * 0.12)
    w_pad = int(w * 0.06)
    x0 = max(0, x - w_pad); y0 = max(0, y - h_pad)
    x1 = min(img_bgr.shape[1], x + w + w_pad)
    y1 = min(img_bgr.shape[0], y + h + h_pad)

    roi = img_bgr[y0:y1, x0:x1]
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)

    # upscale para celdas pequeñas
    if min(gray.shape[:2]) < 40:
        gray = cv2.resize(gray, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)

    variants = _preprocess_variants(gray)

    best_text = ""
    best_score = -1.0

    # PSM candidates: 7 (una línea) y 6/11 fallback
    psm_list = [7, 6, 11]

    # whitelist numérica moderada (sirve para valores)
    wl = "0123456789.,-+/%VAWkKmMgGxX×() "

    for thr in variants:
        for psm in psm_list:
            cfg = f"--oem 3 --psm {psm} -c tessedit_char_whitelist={wl}"
            data = pytesseract.image_to_data(
                thr, lang="eng+spa", config=cfg,
                output_type=pytesseract.Output.DICT
            )
            words = [t.strip() for t in data["text"] if t.strip()]
            text = " ".join(words).strip()
            score = _tess_score(data)

            # bonus si parece valor útil (tiene dígitos)
            digit_bonus = sum(ch.isdigit() for ch in text)
            score += min(10, digit_bonus)

            if score > best_score and len(text) >= 1:
                best_score = score
                best_text = text

    return best_text


def detect_doc_type(full_text: str,
                    panel_tables: Dict[str, str],
                    inv_tables: Dict[str, str]) -> str:
    t = normalize_text(full_text)

    panel_hits = 0
    inv_hits = 0

    # pistas por texto
    panel_keywords = ["open circuit voltage", "short circuit current", "module efficiency",
                      "pv module", "mpp voltage", "imp", "isc", "voc"]
    inv_keywords = ["mppt", "inverter", "grid", "ac output", "max dc voltage",
                    "string", "rated output power", "utility grid"]

    for kw in panel_keywords:
        if kw in t: panel_hits += 2
    for kw in inv_keywords:
        if kw in t: inv_hits += 2

    # pistas por tablas (si ya detectaste llaves típicas)
    if any(k in panel_tables for k in ("Pmax", "Voc", "Isc", "Vmp", "Imp")):
        panel_hits += 5
    if any(k in inv_tables for k in ("Vdc_max", "MPPT_count", "I_out_max", "P_ac_nominal")):
        inv_hits += 5

    return "panel" if panel_hits >= inv_hits else "inverter"

def to_float(s: str) -> Optional[float]:
    if s is None: return None
    s = str(s).strip().replace(",", ".")
    m = re.search(r"[-+]?\d+(?:\.\d+)?", s)
    return float(m.group(0)) if m else None

def kw_to_w(value: Optional[float], raw: str) -> Optional[float]:
    if value is None: return None
    r = (raw or "").lower()
    if "kw" in r and value < 1000:
        return value * 1000.0
    return value

def parse_dimensions_mm(text: str) -> Tuple[Optional[int], Optional[int]]:
    # busca 2 números grandes (mm) tipo 2278 x 1134
    t = text.replace("×", "x").lower()
    m = re.search(r"(\d{3,5})\s*x\s*(\d{3,5})", t)
    if not m: return None, None
    a = int(m.group(1)); b = int(m.group(2))
    h = max(a, b); w = min(a, b)
    return w, h

def parse_weight_kg(raw: str) -> Optional[float]:
    v = to_float(raw)
    if v is None: return None
    r = (raw or "").lower()
    if "g" in r and "kg" not in r:
        return v / 1000.0
    return v

KNOWN_BRANDS = [
    "jinko", "trina", "ja solar", "longi", "canadian solar", "risen",
    "growatt", "huawei", "solis", "fronius", "sma", "goodwe"
]

def detect_brand(text: str) -> Optional[str]:
    t = normalize_text(text)
    for b in KNOWN_BRANDS:
        if b in t:
            return b.title() if b != "ja solar" else "JA Solar"
    return None

def detect_model(text: str, doc_type: str) -> Optional[str]:
    # panel: JAM72..., JKM-..., etc.
    if doc_type == "panel":
        cands = detect_panel_models_from_text(text)
        return cands[0] if cands else None
    # inversor: MIN 6000TL-X, SUN2000-..., etc.
    m = re.search(r"\b([A-Z]{2,}[A-Z0-9\- ]{3,})\b", text)
    return m.group(1).strip() if m else None

def build_panel_output(pdf_name: str, full_text: str,
                       tab: Dict[str, str], txt: Dict[str, str]) -> Dict:
    def pick(k):
        a = tab.get(k)
        b = txt.get(k)
    
        if a and b:
            return a if a["confidence"] >= b["confidence"] else b
        return a or b


    brand = detect_brand(full_text)
    model = detect_model(full_text, "panel") or pdf_name

    pmax_raw = pick("Pmax")
    voc_raw  = pick("Voc")
    isc_raw  = pick("Isc")
    vmp_raw  = pick("Vmp")
    imp_raw  = pick("Imp")
    w_raw    = pick("Width")  # si viene como número solo, mejor usa dimensiones abajo
    l_raw    = pick("Length")
    voc      = pick("Voc")
    voc_v    = to_float(voc["value"]) if voc else None


    # dimensiones: intenta desde texto completo primero
    width_mm, height_mm = parse_dimensions_mm(full_text)
    if not width_mm or not height_mm:
        # fallback si ya tenías Length/Width como textos
        width_mm, height_mm = parse_dimensions_mm(f"{l_raw} x {w_raw}")

    out = {
        "schema_version": "1.0",
        "type": "panel",
        "brand": brand,
        "model": model,
        "power_w": kw_to_w(to_float(pmax_raw), str(pmax_raw)) if pmax_raw else None,
        "voc_v": to_float(voc_raw) if voc_raw else None,
        "isc_a": to_float(isc_raw) if isc_raw else None,
        "vmp_v": to_float(vmp_raw) if vmp_raw else None,
        "imp_a": to_float(imp_raw) if imp_raw else None,
        "panel_width_mm": width_mm,
        "panel_height_mm": height_mm,
        "panel_weight_kg": parse_weight_kg(pick("Weight_panel") or "") if (pick("Weight_panel")) else None
    }

    if voc:
        logger.info(
            f"[DECISION] Voc={voc['value']} "
            f"(source={voc['source']}, conf={voc['confidence']})"
        )


    # limpia Nones (opcional)
    return out


def build_inverter_output(pdf_name: str, full_text: str,
                          tab: Dict[str, str], txt: Dict[str, str]) -> Dict:
    def pick(k):
        return tab.get(k) or txt.get(k)

    brand = detect_brand(full_text)
    model = detect_model(full_text, "inverter") or pdf_name

    # claves internas existentes
    vdc_raw = pick("Vdc_max")
    mppt_raw = pick("MPPT_count")
    i_mppt_raw = pick("I_mppt_max")
    i_out_raw = pick("I_out_max")

    # NUEVO: max_pv_power_w (añadir regex/patrón)
    max_pv_raw = pick("P_pv_max")  # lo agregas en regex/patterns

    inv_type = detect_inverter_phase(full_text, tab)

    if not vdc_raw:
    # fallback común en inversores
        m = re.search(r"(?:max.*dc.*voltage|dc.*max).*?(\d{3,4})", full_text.lower())
    if m:
        vdc_raw = m.group(1)
    


    out = {
        "schema_version": "1.0",
        "type": "inverter",
        "brand": brand,
        "model": model,
        "max_dc_voltage_v": to_float(vdc_raw),
        "mppt_count": int(to_float(mppt_raw)) if mppt_raw and to_float(mppt_raw) else None,
        "max_isc_per_mppt_a": to_float(i_mppt_raw) if i_mppt_raw else None,
        "inverter_type": inv_type,
        "max_pv_power_w": kw_to_w(to_float(max_pv_raw), str(max_pv_raw)) if max_pv_raw else None,
    }

    return out


def detect_inverter_phase(
    full_text: str,
    inverter_tables: Optional[Dict[str, str]] = None
) -> Optional[str]:
    """
    Detecta el tipo de fase del inversor usando:
    1) Tablas (alta confianza)
    2) Texto normalizado
    3) Símbolos eléctricos (1~, 3~, L1 L2 L3)
    """

    # -------------------------------------------------
    # 1) TABLAS (alta confianza)
    # -------------------------------------------------
    if inverter_tables:
        for k, v in inverter_tables.items():
            key = normalize_text(k)
            val = normalize_text(v)

            if any(x in key for x in ("phase", "phases", "fase", "output phase", "grid")):
                if any(x in val for x in ("3", "three", "trifas", "3~", "l1 l2 l3")):
                    return "trifásico"
                if any(x in val for x in ("2", "two", "bifas")):
                    return "bifásico"
                if any(x in val for x in ("1", "single", "mono", "1~", "l-n")):
                    return "monofásico"

    # -------------------------------------------------
    # 2) TEXTO NORMALIZADO
    # -------------------------------------------------
    t = normalize_text(full_text)

    if any(x in t for x in (
        "three phase", "3 phase", "three-phase",
        "trifasico", "trifásico"
    )):
        return "trifásico"

    if any(x in t for x in (
        "split phase", "two phase", "2 phase",
        "bifasico", "bifásico"
    )):
        return "bifásico"

    if any(x in t for x in (
        "single phase", "1 phase",
        "monofasico", "monofásico"
    )):
        return "monofásico"

    # -------------------------------------------------
    # 3) SÍMBOLOS ELÉCTRICOS (MUY COMÚN EN DATASHEETS)
    # -------------------------------------------------
    if re.search(r"\b3\s*[~∿]\b", full_text):
        return "trifásico"

    if re.search(r"\b1\s*[~∿]\b", full_text):
        return "monofásico"

    if re.search(r"\bL1\s+L2\s+L3\b", full_text, re.IGNORECASE):
        return "trifásico"

    if re.search(r"\bL\s*-\s*N\b", full_text, re.IGNORECASE):
        return "monofásico"

    return None

# ---------------------------------------------------------------------
# PROCESAMIENTO DE UN PDF (TABLA + TEXTO)
# ---------------------------------------------------------------------

def process_pdf(pdf_path: str) -> Dict:
    pdf_basename = os.path.splitext(os.path.basename(pdf_path))[0]
    logger.info(f"Procesando PDF: {pdf_basename}")

    # --- 1) Render PDF ---
    images, full_text = render_pdf_to_images_and_text(pdf_path)

    panel_specs_tables: Dict[str, dict] = {}
    inverter_specs_tables: Dict[str, dict] = {}

    # --- SCHEMAS BASE ---
    PANEL_SCHEMA = {
        "type": "panel",
        "brand": None,
        "model": None,
        "power_w": None,
        "voc_v": None,
        "isc_a": None,
        "vmp_v": None,
        "imp_a": None,
        "efficiency_percent": None,
        "panel_width_mm": None,
        "panel_height_mm": None,
        "panel_weight_kg": None,
    }

    INVERTER_SCHEMA = {
        "type": "inverter",
        "brand": None,
        "model": None,
        "max_dc_voltage_v": None,
        "mppt_count": None,
        "max_isc_per_mppt_a": None,
        "max_ac_output_current_a": None,
        "inverter_type": None,
        "max_pv_power_w": None,
    }

    # --- 2) TABLAS ---
    for page_idx, img in enumerate(images):
        tables = detect_tables_on_page(img, page_idx, pdf_basename)
        if not tables:
            continue

        for table in tables:
            for cell in table.cells:
                cell.text = ocr_cell_best(img, cell)

            pairs = match_label_to_value_cells(table)
            for label_cell, value_cell in pairs:
                p_key, i_key = classify_pair(label_cell.text, value_cell.text)

                if p_key:
                    num_hint = _panel_hint(p_key)
                    value_num, value_text_norm = clean_and_parse_value(
                        value_cell.text, key_hint=num_hint
                    )
                    panel_specs_tables[p_key] = {
                        "value": value_num if value_num is not None else value_text_norm,
                        "source": "table",
                        "confidence": 0.95,
                    }

                if i_key:
                    num_hint = _inverter_hint(i_key)
                    value_num, value_text_norm = clean_and_parse_value(
                        value_cell.text, key_hint=num_hint
                    )
                    inverter_specs_tables[i_key] = {
                        "value": value_num if value_num is not None else value_text_norm,
                        "source": "table",
                        "confidence": 0.95,
                    }

    # --- 3) TEXTO (placeholder por ahora) ---
    panel_specs_text = {}
    inverter_specs_text = {}

    # --- 4) CLASIFICACIÓN ---
    doc_type = detect_doc_type(full_text, panel_specs_tables, inverter_specs_tables)

    # --- 5) CONSTRUCCIÓN + SCHEMA + VALIDACIÓN ---
    if doc_type == "panel":
        raw_panel = build_panel_output(
            pdf_basename, full_text, panel_specs_tables, panel_specs_text
        )

        output = PANEL_SCHEMA.copy()
        output.update(raw_panel)

        # 🔥 VALIDACIÓN + INFERENCIA
        output = validate_and_infer_panel(output)

        return output

    elif doc_type == "inverter":
        raw_inverter = build_inverter_output(
            pdf_basename, full_text, inverter_specs_tables, inverter_specs_text
        )

        output = INVERTER_SCHEMA.copy()
        output.update(raw_inverter)

        # 🔥 VALIDACIÓN + INFERENCIA
        output = validate_and_infer_inverter(output)

        return output

    else:
        raise ValueError("No se pudo determinar el tipo de documento (panel/inverter)")


# ---------------------------------------------------------------------
# MAIN FINAL (JSON ONLY: PANELES + INVERSORES)
# ---------------------------------------------------------------------

def main():
    global DEBUG_MODE

    if len(sys.argv) < 2:
        logger.info("No se especificó carpeta PDF, usando ruta por defecto.")
        pdf_folder = DEFAULT_PDF_FOLDER
    else:
        pdf_folder = sys.argv[1]

    if not os.path.isdir(pdf_folder):
        print(f"La ruta especificada no es una carpeta válida: {pdf_folder}")
        sys.exit(1)

    if len(sys.argv) >= 3 and sys.argv[2].lower() == "--debug":
        DEBUG_MODE = True
        logger.setLevel(logging.DEBUG)
        logger.info("DEBUG_MODE activado")

    ensure_dirs()

    pdf_files = [
        os.path.join(pdf_folder, f)
        for f in os.listdir(pdf_folder)
        if f.lower().endswith(".pdf")
    ]


    if not pdf_files:
        print("No se encontraron PDFs en la carpeta especificada.")
        sys.exit(0)

    logger.info(f"Encontrados {len(pdf_files)} PDFs en {pdf_folder}")

    # Directorios de salida
    panel_dir = os.path.join(BUILD_DIR, "json_paneles")
    inverter_dir = os.path.join(BUILD_DIR, "json_inversores")

    os.makedirs(panel_dir, exist_ok=True)
    os.makedirs(inverter_dir, exist_ok=True)

    # -------------------------------------------------
    # PROCESAMIENTO DE PDFs
    # -------------------------------------------------

    for pdf_path in pdf_files:
        pdf_basename = os.path.splitext(os.path.basename(pdf_path))[0]

        try:
            logger.info(f"--- Procesando {pdf_basename} ---")

            result = process_pdf(pdf_path)

            tipo = result.get("type")

            out_dir = panel_dir if tipo == "panel" else inverter_dir
            out_path = os.path.join(out_dir, f"{pdf_basename}.json")

            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(result, f, indent=2, ensure_ascii=False)
  
        except Exception as e:
            logger.exception(f"Error procesando {pdf_basename}: {e}")

    print("\nProceso completado correctamente.")
    print(f"Paneles JSON   → {panel_dir}")
    print(f"Inversores JSON→ {inverter_dir}")
    print(f"Logs           → {LOG_FILE}")
    print(f"Debug tablas   → {TABLES_DIR}")


# ---------------------------------------------------------------------
# ENTRY POINT
# ---------------------------------------------------------------------

if __name__ == "__main__":
    main()