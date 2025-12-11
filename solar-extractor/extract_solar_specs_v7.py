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

VALUE_RANGES = {
    "Voc": (30, 55),
    "Vmp": (28, 50),
    "Isc": (8, 20),
    "Imp": (8, 18),
    "Pmax": (200, 700),
    "MPPT": (1, 12),
    "Vdc_max": (500, 1500),
}

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
    "Vsys_max": [
        "max system voltage", "maximum system voltage",
        "tension maxima del sistema", "system voltage max"
    ],
    "TempCoeff_Voc": [
        "temp coefficient of voc", "temperature coefficient of voc",
        "coeficiente de temperatura voc"
    ],
    "TempCoeff_Pmax": [
        "temp coefficient of pmax", "temperature coefficient of pmax",
        "coeficiente de temperatura pmax"
    ],
    "IP_rating_panel": [
        "ip65", "ip67", "ip68", "ip rating", "grado de proteccion", "ip"
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
    "freq": [
        "grid frequency", "nominal frequency", "frecuencia nominal",
        "frecuencia de red"
    ],
    "eff_max": [
        "max efficiency", "eficiencia maxima", "maximum efficiency"
    ],
    "eff_cec": [
        "cec efficiency", "weighted efficiency", "eficiencia cec",
        "eficiencia ponderada"
    ],
    "pf_range": [
        "power factor", "factor de potencia", "power factor range",
        "rango de factor de potencia"
    ],
    "IP_rating_inv": [
        "ip65", "ip66", "ip67", "ip68", "ip rating", "grado de proteccion", "ip"
    ],
    "Weight_inv": [
        "weight", "peso", "net weight"
    ],
}


# ------------------ PATRONES REGEX PARA MODO TEXTO -------------------

def _r_num(unit_hint: str = "") -> str:
    """
    Devuelve un grupo regex genérico para número con unidad opcional.
    """
    unit_part = r"\s*(" + unit_hint + r")?" if unit_hint else r"\s*([a-zA-Z%°/]+)?"
    return r"([-+]?\d+(?:[.,]\d+)?)" + unit_part


PANEL_TEXT_REGEX: Dict[str, List[re.Pattern]] = {
    "Pmax": [
        re.compile(
            r"(maximum\s+power|rated\s+power|peak\s+power|potencia\s+(?:máxima|nominal)|power\s+output)"
            r".{0,30}" + _r_num(r"[kK]?[wW][pP]?"),
            re.IGNORECASE | re.DOTALL,
        ),
        re.compile(
            r"Pmax[^0-9\-+]{0,20}" + _r_num(r"[kK]?[wW][pP]?"),
            re.IGNORECASE,
        ),
    ],
    "Voc": [
        re.compile(
            r"(open\s+circuit\s+voltage|voltaje\s+de\s+circuito\s+abierto|tensi[oó]n\s+de\s+circuito\s+abierto)"
            r".{0,30}" + _r_num(r"[vV]"),
            re.IGNORECASE | re.DOTALL,
        ),
        re.compile(r"Voc[^0-9\-+]{0,20}" + _r_num(r"[vV]"), re.IGNORECASE),
    ],
    "Vmp": [
        re.compile(
            r"(maximum\s+power\s+voltage|voltage\s+at\s+pmpp?|tensi[oó]n\s+a\s+potencia\s+m[aá]xima)"
            r".{0,30}" + _r_num(r"[vV]"),
            re.IGNORECASE | re.DOTALL,
        ),
        re.compile(r"Vmp[^0-9\-+]{0,20}" + _r_num(r"[vV]"), re.IGNORECASE),
    ],
    "Isc": [
        re.compile(
            r"(short\s+circuit\s+current|corriente\s+de\s+corto\s+circuito)"
            r".{0,30}" + _r_num(r"[aA]"),
            re.IGNORECASE | re.DOTALL,
        ),
        re.compile(r"Isc[^0-9\-+]{0,20}" + _r_num(r"[aA]"), re.IGNORECASE),
    ],
    "Imp": [
        re.compile(
            r"(maximum\s+power\s+current|current\s+at\s+pmpp?|corriente\s+a\s+potencia\s+m[aá]xima)"
            r".{0,30}" + _r_num(r"[aA]"),
            re.IGNORECASE | re.DOTALL,
        ),
        re.compile(r"Imp[^0-9\-+]{0,20}" + _r_num(r"[aA]"), re.IGNORECASE),
    ],
    "Vsys_max": [
        re.compile(
            r"(maximum\s+system\s+voltage|max\s+system\s+voltage|tensi[oó]n\s+m[aá]xima\s+del\s+sistema)"
            r".{0,30}" + _r_num(r"[vV]"),
            re.IGNORECASE | re.DOTALL,
        )
    ],
    "TempCoeff_Voc": [
        re.compile(
            r"(temperature\s+coefficient\s+of\s+Voc|coeficiente\s+de\s+temperatura\s+Voc)"
            r".{0,30}" + _r_num(r"%\s*/\s*°?C"),
            re.IGNORECASE | re.DOTALL,
        )
    ],
    "TempCoeff_Pmax": [
        re.compile(
            r"(temperature\s+coefficient\s+of\s+Pmax|coeficiente\s+de\s+temperatura\s+Pmax)"
            r".{0,30}" + _r_num(r"%\s*/\s*°?C"),
            re.IGNORECASE | re.DOTALL,
        )
    ],
    "Length": [
        re.compile(
            r"(dimension[s]?|dimensiones|length|largo|height|altura)"
            r".{0,50}?(\d{3,5})\s*[x×]\s*\d{3,5}\s*[x×]\s*\d{2,3}",
            re.IGNORECASE | re.DOTALL,
        ),
    ],
    "Width": [
        re.compile(
            r"(dimension[s]?|dimensiones|length|largo|height|altura)"
            r".{0,50}?\d{3,5}\s*[x×]\s*(\d{3,5})\s*[x×]\s*\d{2,3}",
            re.IGNORECASE | re.DOTALL,
        ),
    ],
    "Weight_panel": [
        re.compile(
            r"(weight|peso).{0,20}" + _r_num(r"[kK]?[gG]"),
            re.IGNORECASE | re.DOTALL,
        )
    ],
}

INVERTER_TEXT_REGEX: Dict[str, List[re.Pattern]] = {
    "P_ac_nominal": [
        re.compile(
            r"(rated\s+ac\s+output\s+power|nominal\s+ac\s+power|potencia\s+nominal\s+de\s+salida)"
            r".{0,40}" + _r_num(r"[kK]?[wW]"),
            re.IGNORECASE | re.DOTALL,
        ),
        re.compile(
            r"potencia\s+nominal\s+de\s+salida\s+(\d+(?:[.,]\d+)?)\s*(k?w)",
            re.IGNORECASE,
        ),
    ],
    "P_ac_max": [
        re.compile(
            r"(max(?:imum)?\s+ac\s+output\s+power|potencia\s+m[aá]xima\s+de\s+salida)"
            r".{0,40}" + _r_num(r"[kK]?[wW]"),
            re.IGNORECASE | re.DOTALL,
        )
    ],
    "Vdc_max": [
        re.compile(
            r"(max(?:imum)?\s+(?:pv|dc)\s+voltage|maximo\s+voltaje\s+(?:fv|cd)|voltaje\s+m[aá]ximo\s+de\s+entrada)"
            r".{0,40}" + _r_num(r"[vV]"),
            re.IGNORECASE | re.DOTALL,
        ),
    ],
    "I_mppt_max": [
        re.compile(
            r"(max(?:imum)?\s+input\s+current|corriente\s+m[aá]xima\s+de\s+entrada)"
            r".{0,40}" + _r_num(r"[aA]"),
            re.IGNORECASE | re.DOTALL,
        )
    ],
    "MPPT_count": [
        re.compile(
            r"(number\s+of\s+mppt|mpp\s+trackers|n[uú]mero\s+de\s+mppt)"
            r".{0,30}(\d+)",
            re.IGNORECASE | re.DOTALL,
        )
    ],
    "I_out_max": [
        re.compile(
            r"(max(?:imum)?\s+output\s+current|corriente\s+m[aá]xima\s+de\s+salida)"
            r".{0,40}" + _r_num(r"[aA]"),
            re.IGNORECASE | re.DOTALL,
        )
    ],
    "freq": [
        re.compile(
            r"(grid\s+frequency|frecuencia\s+nominal\s+de\s+la\s+red|frecuencia\s+de\s+red)"
            r".{0,40}" + _r_num(r"[hH][zZ]"),
            re.IGNORECASE | re.DOTALL,
        )
    ],
    "eff_max": [
        re.compile(
            r"(max(?:imum)?\s+efficiency|eficiencia\s+m[aá]xima)"
            r".{0,40}" + _r_num(r"%"),
            re.IGNORECASE | re.DOTALL,
        )
    ],
    "eff_cec": [
        re.compile(
            r"(cec\s+efficiency|weighted\s+efficiency|eficiencia\s+cec|eficiencia\s+ponderada)"
            r".{0,40}" + _r_num(r"%"),
            re.IGNORECASE | re.DOTALL,
        )
    ],
    "pf_range": [
        re.compile(
            r"(power\s+factor|factor\s+de\s+potencia).{0,60}",
            re.IGNORECASE | re.DOTALL,
        )
    ],
    "Weight_inv": [
        re.compile(
            r"(weight|peso).{0,20}" + _r_num(r"[kK]?[gG]"),
            re.IGNORECASE | re.DOTALL,
        )
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

def ocr_cell(img_bgr: np.ndarray, cell: Cell) -> str:
    x, y, w, h = cell.x, cell.y, cell.w, cell.h
    h_pad = int(h * 0.1)
    w_pad = int(w * 0.05)
    x0 = max(0, x - w_pad)
    y0 = max(0, y - h_pad)
    x1 = min(img_bgr.shape[1], x + w + w_pad)
    y1 = min(img_bgr.shape[0], y + h + h_pad)

    roi = img_bgr[y0:y1, x0:x1]
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    gray = cv2.medianBlur(gray, 3)
    _, thr = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    config = (
        "--oem 3 "
        "--psm 6 "
        "-c tessedit_char_whitelist=0123456789.,-+xXkKwWVAabcdefghijklmnopqrstuvwxyz"
        "%/°IPip() "
    )

    data = pytesseract.image_to_data(
        thr,
        config=config,
        output_type=pytesseract.Output.DICT,
        lang="eng"
    )

    words = [txt.strip() for txt in data["text"] if txt.strip()]
    text = " ".join(words).strip()
    logger.debug(f"OCR Cell [P{cell.page_index} T{cell.table_id} R{cell.row} C{cell.col}]: '{text}'")
    return text


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

def extract_specs_from_text(text: str) -> Tuple[Dict[str, str], Dict[str, str]]:
    """
    Usa regex sobre el texto global para identificar especificaciones
    de panel e inversor.
    """
    panel_specs: Dict[str, str] = {}
    inverter_specs: Dict[str, str] = {}

    # PANEL
    for key, patterns in PANEL_TEXT_REGEX.items():
        for pat in patterns:
            m = pat.search(text)
            if not m:
                continue
            # los últimos dos grupos suelen ser valor + unidad
            groups = [g for g in m.groups() if g is not None]
            if not groups:
                continue
            raw_val = groups[-2] if len(groups) >= 2 else groups[-1]
            val, norm = clean_and_parse_value(raw_val, key_hint=_panel_hint(key))
            if key in ("Length", "Width", "Weight_panel"):
                if val is not None:
                    panel_specs[key] = str(val)
                else:
                    panel_specs[key] = norm
            else:
                if val is not None:
                    panel_specs[key] = str(val)
                else:
                    panel_specs[key] = norm
            logger.info(f"[TEXT] PANEL {key}: '{panel_specs[key]}' (raw='{raw_val}')")
            break  # primer match por clave

    # INVERSOR
    for key, patterns in INVERTER_TEXT_REGEX.items():
        for pat in patterns:
            m = pat.search(text)
            if not m:
                continue
            groups = [g for g in m.groups() if g is not None]
            if not groups:
                continue
            raw_val = groups[-2] if len(groups) >= 2 else groups[-1]

            val, norm = clean_and_parse_value(raw_val, key_hint=_inverter_hint(key))
            if key in ("pf_range",):
                inverter_specs["pf_range"] = norm
            elif key in ("Weight_inv",):
                if val is not None:
                    inverter_specs[key] = str(val)
                else:
                    inverter_specs[key] = norm
            else:
                if val is not None:
                    inverter_specs[key] = str(val)
                else:
                    inverter_specs[key] = norm
            logger.info(f"[TEXT] INV {key}: '{inverter_specs[key]}' (raw='{raw_val}')")
            break

    return panel_specs, inverter_specs


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


# ---------------------------------------------------------------------
# PROCESAMIENTO DE UN PDF (TABLA + TEXTO)
# ---------------------------------------------------------------------

def process_pdf(pdf_path: str) -> Tuple[Dict[str, str], Dict[str, str]]:
    """
    Procesa un PDF:
      1) Modo TABLA visual.
      2) Modo TEXTO (PyMuPDF + OCR página).
      3) Fusiona resultados.
    """
    pdf_basename = os.path.splitext(os.path.basename(pdf_path))[0]
    logger.info(f"Procesando PDF: {pdf_basename}")

    images, full_text = render_pdf_to_images_and_text(pdf_path)

    panel_specs_tables: Dict[str, str] = {}
    inverter_specs_tables: Dict[str, str] = {}

    # ----------- 1) MODO TABLA (si hay algo que parezca tabla) ----------
    for page_idx, img in enumerate(images):
        tables = detect_tables_on_page(img, page_idx, pdf_basename)
        if not tables:
            continue

        for table in tables:
            for cell in table.cells:
                cell.text = ocr_cell(img, cell)

            # logging OCR celdas
            for c in table.cells:
                logger.info(
                    f"[TABLA OCR] P{c.page_index} T{c.table_id} R{c.row} C{c.col}: '{c.text}'"
                )

            pairs = match_label_to_value_cells(table)
            for label_cell, value_cell in pairs:
                label_text = label_cell.text
                value_text = value_cell.text

                p_key, i_key = classify_pair(label_text, value_text)
                logger.info(
                    f"[TABLA MATCH] P{label_cell.page_index} T{label_cell.table_id} "
                    f"'{label_text}' → '{value_text}' (panel_key={p_key}, inverter_key={i_key})"
                )

                if p_key is not None:
                    numeric_hint = _panel_hint(p_key)
                    value_num, value_text_norm = clean_and_parse_value(value_text, key_hint=numeric_hint)

                    if p_key == "IP_rating_panel":
                        panel_specs_tables["IP_rating_panel"] = value_text_norm
                    elif p_key in ("Length", "Width", "Weight_panel"):
                        val, txt = clean_and_parse_value(value_text, key_hint=None)
                        if val is not None:
                            panel_specs_tables[p_key] = str(val)
                        else:
                            panel_specs_tables[p_key] = txt
                    else:
                        if value_num is not None:
                            panel_specs_tables[p_key] = str(value_num)
                        else:
                            panel_specs_tables[p_key] = value_text_norm

                if i_key is not None:
                    numeric_hint = _inverter_hint(i_key)
                    value_num, value_text_norm = clean_and_parse_value(value_text, key_hint=numeric_hint)

                    if i_key == "pf_range":
                        inverter_specs_tables["pf_range"] = value_text_norm
                    elif i_key == "IP_rating_inv":
                        inverter_specs_tables["IP_rating_inv"] = value_text_norm
                    elif i_key == "Weight_inv":
                        val, txt = clean_and_parse_value(value_text, key_hint=None)
                        if val is not None:
                            inverter_specs_tables[i_key] = str(val)
                        else:
                            inverter_specs_tables[i_key] = txt
                    else:
                        if value_num is not None:
                            inverter_specs_tables[i_key] = str(value_num)
                        else:
                            inverter_specs_tables[i_key] = value_text_norm

    # ----------- 2) MODO TEXTO  ----------------------------------------
    panel_specs_text, inverter_specs_text = extract_specs_from_text(full_text)

    # ----------- 3) FUSIÓN: tabla tiene prioridad, texto rellena  -------
    panel_specs_final: Dict[str, str] = {}
    inverter_specs_final: Dict[str, str] = {}

    for key in set(list(PANEL_TEXT_REGEX.keys()) + list(PANEL_PATTERNS.keys())):
        if key in panel_specs_tables:
            panel_specs_final[key] = panel_specs_tables[key]
        elif key in panel_specs_text:
            panel_specs_final[key] = panel_specs_text[key]

    for key in set(list(INVERTER_TEXT_REGEX.keys()) + list(INVERTER_PATTERNS.keys())):
        if key in inverter_specs_tables:
            inverter_specs_final[key] = inverter_specs_tables[key]
        elif key in inverter_specs_text:
            inverter_specs_final[key] = inverter_specs_text[key]

    return panel_specs_final, inverter_specs_final


# ---------------------------------------------------------------------
# MAPEOS A CSV
# ---------------------------------------------------------------------

def build_panel_row_from_specs(specs: Dict[str, str]) -> Dict[str, Optional[str]]:
    row = {
        "potencia_panel": specs.get("Pmax"),
        "Voc_panel": specs.get("Voc"),
        "Isc_panel": specs.get("Isc"),
        "Vmp_panel": specs.get("Vmp"),
        "Imp_panel": specs.get("Imp"),
        "largo_panel": specs.get("Length"),
        "ancho_panel": specs.get("Width"),
        "peso_panel": specs.get("Weight_panel"),
        "tension_sistema_max_V": specs.get("Vsys_max"),
        "coef_temp_Voc_pct_C": specs.get("TempCoeff_Voc"),
        "coef_temp_Pmax_pct_C": specs.get("TempCoeff_Pmax"),
        "ip_rating": specs.get("IP_rating_panel"),
    }
    return row


def build_inverter_row_from_specs(specs: Dict[str, str]) -> Dict[str, Optional[str]]:
    row = {
        "potencia_AC_nominal_W": specs.get("P_ac_nominal"),
        "potencia_AC_max_W": specs.get("P_ac_max"),
        "max_volt_dc": specs.get("Vdc_max"),
        "corriente_max_mppt": specs.get("I_mppt_max"),
        "cantidad_mppts": specs.get("MPPT_count"),
        "corriente_salida_max": specs.get("I_out_max"),
        "frecuencia_Hz": specs.get("freq"),
        "eficiencia_max_pct": specs.get("eff_max"),
        "eficiencia_CEC_pct": specs.get("eff_cec"),
        "pf_rango": specs.get("pf_range"),
        "ip_rating": specs.get("IP_rating_inv"),
        "peso_kg": specs.get("Weight_inv"),
    }
    return row


# ---------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------

def main():
    global DEBUG_MODE

    if len(sys.argv) < 2:
        print("Uso:")
        print("    python extract_solar_specs_v7.py <carpeta_pdf> [--debug]")
        sys.exit(1)

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

    panel_rows = []
    inverter_rows = []

    for pdf_path in pdf_files:
        pdf_basename = os.path.splitext(os.path.basename(pdf_path))[0]
        try:
            panel_specs, inverter_specs = process_pdf(pdf_path)

            panel_row = build_panel_row_from_specs(panel_specs)
            inverter_row = build_inverter_row_from_specs(inverter_specs)

            # Si quieres, puedes guardar el nombre de archivo:
            panel_row["archivo"] = pdf_basename
            inverter_row["archivo"] = pdf_basename

            panel_rows.append(panel_row)
            inverter_rows.append(inverter_row)
        except Exception as e:
            logger.exception(f"Error procesando {pdf_basename}: {e}")
            row_p = build_panel_row_from_specs({})
            row_i = build_inverter_row_from_specs({})
            row_p["archivo"] = pdf_basename
            row_i["archivo"] = pdf_basename
            panel_rows.append(row_p)
            inverter_rows.append(row_i)

    panel_df = pd.DataFrame(panel_rows, columns=[
        "archivo",
        "potencia_panel",
        "Voc_panel",
        "Isc_panel",
        "Vmp_panel",
        "Imp_panel",
        "largo_panel",
        "ancho_panel",
        "peso_panel",
        "tension_sistema_max_V",
        "coef_temp_Voc_pct_C",
        "coef_temp_Pmax_pct_C",
        "ip_rating",
    ])

    inverter_df = pd.DataFrame(inverter_rows, columns=[
        "archivo",
        "potencia_AC_nominal_W",
        "potencia_AC_max_W",
        "max_volt_dc",
        "corriente_max_mppt",
        "cantidad_mppts",
        "corriente_salida_max",
        "frecuencia_Hz",
        "eficiencia_max_pct",
        "eficiencia_CEC_pct",
        "pf_rango",
        "ip_rating",
        "peso_kg",
    ])

    panel_csv_path = os.path.join(BASE_DIR, "paneles.csv")
    inverter_csv_path = os.path.join(BASE_DIR, "inversores.csv")

    panel_df.to_csv(panel_csv_path, index=False)
    inverter_df.to_csv(inverter_csv_path, index=False)

    logger.info(f"paneles.csv guardado en {panel_csv_path}")
    logger.info(f"inversores.csv guardado en {inverter_csv_path}")
    print(f"Proceso completado.")
    print(f"Paneles   → {panel_csv_path}")
    print(f"Inversores→ {inverter_csv_path}")
    print(f"Logs      → {LOG_FILE}")
    print(f"Tablas dbg→ {TABLES_DIR}")


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