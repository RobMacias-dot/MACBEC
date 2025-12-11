#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
extract_solar_specs_v6c.py

Extractor V6C – Opción C: Extracción visual basada en tablas
------------------------------------------------------------
- Lectura de PDFs con PyMuPDF (fitz) → imágenes por página
- Detección visual de tablas (OpenCV: umbral adaptativo, líneas H/V, contornos)
- Segmentación por celdas
- OCR por celda (Tesseract)
- Reconstrucción etiqueta → valor (proximidad visual + patrones conocidos)
- Corrección automática de valores (rangos típicos y unidades)
- Exportación a paneles.csv e inversores.csv

Uso (modo producción):

    python extract_solar_specs_v6c.py <carpeta_pdf>

Genera:
    build/_debug/extract_v6c.log       → logs detallados
    build/_tables/*.png                → imágenes con tablas y celdas detectadas
    paneles.csv, inversores.csv        → salidas consolidadas
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

LOG_FILE = os.path.join(DEBUG_DIR, "extract_v6c.log")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ],
)

logger = logging.getLogger("V6C")

DEBUG_MODE = False  # Si quieres más ruido en consola, pon True o agrega un flag CLI


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
# PATRONES Y RANGOS SEMÁNTICOS
# ---------------------------------------------------------------------

# Rangos típicos para corrección
VALUE_RANGES = {
    "Voc": (30, 55),
    "Vmp": (28, 50),
    "Isc": (8, 20),
    "Imp": (8, 18),
    "Pmax": (200, 700),
    "MPPT": (1, 12),
    "Vdc_max": (500, 1500),
}

# Patrones para paneles
PANEL_PATTERNS = {
    "Pmax": [
        "pmax", "max power", "maximum power", "rated power", "nominal power",
        "power at stc", "module power", "salida nominal", "potencia nominal",
        "potencia maxima", "output power"
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
        "tension maxima del sistema", "sistema maximo", "system voltage max"
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
        "length", "largo", "height", "altura", "dimension largo", "dimension length"
    ],
    "Width": [
        "width", "ancho", "dimension ancho"
    ],
    "Weight_panel": [
        "weight", "peso", "module weight"
    ],
}

# Patrones para inversores
INVERTER_PATTERNS = {
    "P_ac_nominal": [
        "rated ac output power", "nominal ac power",
        "potencia nominal ac", "rated power", "nominal output power"
    ],
    "P_ac_max": [
        "max ac output power", "maximum ac power",
        "salida ac maxima", "potencia maxima ac"
    ],
    "Vdc_max": [
        "max pv voltage", "max dc voltage", "maximum dc voltage",
        "max input voltage", "max. dc voltage", "vdc max", "dc max voltage"
    ],
    "I_mppt_max": [
        "max input current per mppt", "max input current",
        "corriente maxima por mppt", "corriente max mppt"
    ],
    "MPPT_count": [
        "mppt", "number of mppt", "mpp tracker", "mpp trackers",
        "max. number of mpp trackers", "cantidad de mppt"
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
        "max efficiency", "max. efficiency", "eficiencia maxima",
        "maximum efficiency"
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

# ---------------------------------------------------------------------
# UTILIDADES
# ---------------------------------------------------------------------

def normalize_text(s: str) -> str:
    """
    Normaliza texto para matching flexible:
    - pasa a minúsculas
    - reemplaza caracteres no alfanuméricos por espacio
    - colapsa espacios
    """
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
# LECTURA DEL PDF → IMÁGENES
# ---------------------------------------------------------------------

def render_pdf_to_images(pdf_path: str, dpi: int = 200) -> List[np.ndarray]:
    """
    Renderiza cada página del PDF a una imagen RGB (numpy array)
    usando PyMuPDF (fitz).
    """
    logger.info(f"Renderizando PDF → imágenes: {pdf_path}")
    doc = fitz.open(pdf_path)
    images = []
    zoom = dpi / 72.0
    mat = fitz.Matrix(zoom, zoom)
    for page_index in range(len(doc)):
        page = doc[page_index]
        pix = page.get_pixmap(matrix=mat)
        mode = "RGB" if pix.alpha == 0 else "RGBA"
        img = Image.frombytes(mode, [pix.width, pix.height], pix.samples)
        if mode == "RGBA":
            img = img.convert("RGB")
        images.append(cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR))
    doc.close()
    return images


# ---------------------------------------------------------------------
# DETECCIÓN DE TABLAS Y CELDAS
# ---------------------------------------------------------------------

def detect_tables_on_page(
    img_bgr: np.ndarray,
    page_index: int,
    pdf_basename: str
) -> List[Table]:
    """
    Detecta tablas en una página usando:
    - Umbralizado adaptativo.
    - Detección de líneas horizontales y verticales.
    - Contornos para celdas.
    Además, hace un fallback para tablas sin bordes (“borderless tables”).
    """
    logger.info(f"[P{page_index}] Detectando tablas en página")
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    # Invertimos para resaltar líneas oscuras sobre fondo claro
    gray_inv = cv2.bitwise_not(gray)
    thr = cv2.adaptiveThreshold(
        gray_inv, 255,
        cv2.ADAPTIVE_THRESH_MEAN_C,
        cv2.THRESH_BINARY,
        15, -2
    )

    # Estructuras para líneas horizontales y verticales
    h_kernel_len = max(10, img_bgr.shape[1] // 40)
    v_kernel_len = max(10, img_bgr.shape[0] // 40)

    horiz_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (h_kernel_len, 1))
    vert_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, v_kernel_len))

    horizontal_lines = cv2.erode(thr, horiz_kernel, iterations=1)
    horizontal_lines = cv2.dilate(horizontal_lines, horiz_kernel, iterations=1)

    vertical_lines = cv2.erode(thr, vert_kernel, iterations=1)
    vertical_lines = cv2.dilate(vertical_lines, vert_kernel, iterations=1)

    # Combinar líneas para celdas con bordes
    table_mask = cv2.add(horizontal_lines, vertical_lines)

    # Fallback: si la máscara es muy pobre, considerar contornos en toda la imagen
    if cv2.countNonZero(table_mask) < 100:
        logger.info(f"[P{page_index}] Máscara de líneas escasa, usando fallback borderless")
        table_mask = thr.copy()

    contours, _ = cv2.findContours(table_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    tables: List[Table] = []
    table_id_counter = 0

    # Filtro de contornos grandes (áreas potenciales de tabla)
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        area = w * h
        if area < 10000:  # descarta cosas pequeñas
            continue
        if w < 0.15 * img_bgr.shape[1]:
            # probablemente muy estrecho para ser tabla
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

        # Asignar filas y columnas según posición
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
        tables.append(table)

    # DEBUG: Dibujar tablas y celdas
    debug_img = img_bgr.copy()
    for t in tables:
        x, y, w, h = t.bbox
        cv2.rectangle(debug_img, (x, y), (x + w, y + h), (0, 0, 255), 2)
        for c in t.cells:
            cv2.rectangle(debug_img, (c.x, c.y), (c.x + c.w, c.y + c.h), (0, 255, 0), 1)

    debug_out = os.path.join(
        TABLES_DIR,
        f"{pdf_basename}_page{page_index}_tables.png"
    )
    cv2.imwrite(debug_out, debug_img)
    logger.info(f"[P{page_index}] Imagen debug tablas guardada en {debug_out}")

    return tables


def detect_cells_in_table(table_thr: np.ndarray, offset_x: int, offset_y: int) -> List[Tuple[int, int, int, int]]:
    """
    Detecta celdas dentro de una región de tabla:
    - Usa contornos internos y líneas.
    - Retorna bounding boxes en coordenadas de página.
    """
    # Buscar contornos internos dentro de la tabla
    contours, _ = cv2.findContours(table_thr, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)

    rects = []
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        area = w * h
        if area < 200:  # descartar cosas muy pequeñas
            continue
        # Descarta el contorno muy grande (la tabla completa) si existe
        if w > 0.9 * table_thr.shape[1] and h > 0.9 * table_thr.shape[0]:
            continue
        rects.append((x + offset_x, y + offset_y, w, h))

    # Opcional: merge de rectángulos muy solapados
    rects = merge_overlapping_rects(rects)
    return rects


def merge_overlapping_rects(rects: List[Tuple[int, int, int, int]],
                            iou_threshold: float = 0.3) -> List[Tuple[int, int, int, int]]:
    """
    Une rectángulos muy solapados para evitar duplicados.
    """
    if not rects:
        return []

    rects = sorted(rects, key=lambda r: (r[1], r[0]))  # por y, luego x
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
            # merge
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
    """
    Agrupa celdas por filas y columnas según sus coordenadas (heurística).
    Retorna: (x, y, w, h, row_index, col_index)
    """
    if not rects:
        return []

    # Ordenar por y, luego x
    rects_sorted = sorted(rects, key=lambda r: (r[1], r[0]))

    # Agrupar filas por Y (centro de celda)
    rows: List[List[Tuple[int, int, int, int]]] = []
    row_centers: List[float] = []

    for r in rects_sorted:
        x, y, w, h = r
        cy = y + h / 2.0
        assigned = False
        for idx, rc in enumerate(row_centers):
            if abs(cy - rc) <= y_tol:
                rows[idx].append(r)
                # actualizar centro promedio
                row_centers[idx] = (row_centers[idx] * (len(rows[idx]) - 1) + cy) / len(rows[idx])
                assigned = True
                break
        if not assigned:
            rows.append([r])
            row_centers.append(cy)

    # Dentro de cada fila, ordenar por x y asignar columnas
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
# OCR POR CELDA
# ---------------------------------------------------------------------

def ocr_cell(img_bgr: np.ndarray, cell: Cell) -> str:
    """
    Ejecuta OCR sobre una celda usando Tesseract.
    Devuelve texto limpio.
    """
    x, y, w, h = cell.x, cell.y, cell.w, cell.h
    h_pad = int(h * 0.1)
    w_pad = int(w * 0.05)
    x0 = max(0, x - w_pad)
    y0 = max(0, y - h_pad)
    x1 = min(img_bgr.shape[1], x + w + w_pad)
    y1 = min(img_bgr.shape[0], y + h + h_pad)

    roi = img_bgr[y0:y1, x0:x1]
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    # Normalización básica
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

    words = []
    for i, txt in enumerate(data["text"]):
        txt = txt.strip()
        if not txt:
            continue
        words.append(txt)

    text = " ".join(words).strip()
    logger.debug(f"OCR Cell [P{cell.page_index} T{cell.table_id} R{cell.row} C{cell.col}]: '{text}'")
    return text


# ---------------------------------------------------------------------
# CORRECCIÓN DE VALORES
# ---------------------------------------------------------------------

def parse_numeric_from_text(raw: str) -> Optional[float]:
    """
    Extrae el primer número flotante del texto.
    Retorna None si no encuentra.
    """
    if not raw:
        return None
    # Reemplazar coma decimal por punto
    s = raw.replace(",", ".")
    # Encontrar patrón numérico
    m = re.search(r"[-+]?\d+(\.\d+)?", s)
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
    """
    Corrige un valor según rangos típicos y el texto original.
    - Maneja caso "000" → None.
    - Maneja unidades kW → multiplica x1000.
    - Ajusta orden de magnitud (x10, x100) para entrar a rango esperado.
    """
    if value is None:
        return None

    raw_norm = raw.lower().replace(" ", "")

    # "000" → ignorar
    if raw_norm in ("000", "0.0", "0,0"):
        return None

    # kW → W (si tiene kw/kW y el valor es razonablemente pequeño)
    if "kw" in raw_norm and value < 1000:
        value *= 1000.0

    # Ajuste por rangos típicos si tenemos pista de clave
    if key_hint and key_hint in VALUE_RANGES:
        low, high = VALUE_RANGES[key_hint]
        # Si es claramente un orden de magnitud incorrecto, escalar
        if value < low:
            # Intenta multiplicar por 10 o 100
            for factor in (10, 100):
                new_val = value * factor
                if low <= new_val <= high:
                    value = new_val
                    break
        elif value > high * 10:
            # Muy grande, intenta bajar
            for factor in (0.1, 0.01):
                new_val = value * factor
                if low <= new_val <= high:
                    value = new_val
                    break

        # Si sigue fuera del rango de manera absurda (ej. negativo), lo descartamos
        if value < 0:
            return None

    return value


def clean_and_parse_value(raw: str, key_hint: Optional[str] = None) -> Tuple[Optional[float], str]:
    """
    Normaliza y parsea un valor numérico, devolviendo (float o None, texto_normalizado)
    para campos numéricos. Para campos tipo IP o factor de potencia, se usará
    directamente el texto.
    """
    if not raw:
        return None, ""

    raw_stripped = raw.strip()
    # Mantener texto normalizado para campos no estrictamente numéricos
    text_norm = raw_stripped.replace("\n", " ").strip()

    value = parse_numeric_from_text(raw_stripped)
    value = correct_value_by_range(value, raw_stripped, key_hint=key_hint)

    return value, text_norm


# ---------------------------------------------------------------------
# MATCHING ETIQUETA → VALOR
# ---------------------------------------------------------------------

def match_label_to_value_cells(table: Table) -> List[Tuple[Cell, Cell]]:
    """
    Empareja celdas de etiqueta (texto mayormente no numérico) con celdas de valor
    (texto mayormente numérico) usando proximidad visual.
    Retorna lista de pares (label_cell, value_cell).
    """
    label_candidates = [c for c in table.cells if not is_mostly_numeric(c.text)]
    value_candidates = [c for c in table.cells if is_mostly_numeric(c.text)]

    pairs = []
    for label in label_candidates:
        best_val = None
        best_score = float("inf")
        for val in value_candidates:
            # Preferimos valores en la misma fila o a la derecha
            dy = abs((label.y + label.h/2) - (val.y + val.h/2))
            dx = (val.x + val.w/2) - (label.x + label.w/2)
            if dx < -5:
                # valor está a la izquierda (menos probable)
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
    """
    A partir del texto de etiqueta y valor, decide:
    - Qué campo (key) de panel o inversor es (según patrones).
    - Si pertenece a panel o inversor.

    Retorna:
        (panel_key | None, inverter_key | None)
    Solo uno de los dos será diferente de None en la mayoría de casos.
    """
    lab_norm = normalize_text(label_text)

    # PANEL
    for key, patterns in PANEL_PATTERNS.items():
        for p in patterns:
            if p in lab_norm:
                return key, None

    # INVERSOR
    for key, patterns in INVERTER_PATTERNS.items():
        for p in patterns:
            if p in lab_norm:
                return None, key

    # Casos genéricos: si solo dice "efficiency", asumimos inversor
    if "efficiency" in lab_norm or "eficiencia" in lab_norm:
        return None, "eff_max"

    # Si etiqueta tiene "mppt"
    if "mppt" in lab_norm or "mpp tracker" in lab_norm or "mpp trackers" in lab_norm:
        return None, "MPPT_count"

    return None, None


# ---------------------------------------------------------------------
# PROCESAMIENTO DE UN PDF COMPLETO
# ---------------------------------------------------------------------

def process_pdf(pdf_path: str) -> Tuple[Dict[str, str], Dict[str, str]]:
    """
    Procesa un PDF y devuelve:
        panel_specs: dict
        inverter_specs: dict
    con las claves canonizadas (Pmax, Voc, Vmp, etc.).
    """
    pdf_basename = os.path.splitext(os.path.basename(pdf_path))[0]
    logger.info(f"Procesando PDF: {pdf_basename}")

    images = render_pdf_to_images(pdf_path)
    panel_specs: Dict[str, str] = {}
    inverter_specs: Dict[str, str] = {}

    for page_idx, img in enumerate(images):
        tables = detect_tables_on_page(img, page_idx, pdf_basename)

        # OCR por celda
        for table in tables:
            for cell in table.cells:
                text = ocr_cell(img, cell)
                cell.text = text

            # Log detallado de OCR de celdas
            for c in table.cells:
                logger.info(
                    f"OCR Cell P{c.page_index} T{c.table_id} "
                    f"R{c.row} C{c.col}: '{c.text}'"
                )

            # Matching etiqueta → valor
            pairs = match_label_to_value_cells(table)
            for label_cell, value_cell in pairs:
                label_text = label_cell.text
                value_text = value_cell.text

                p_key, i_key = classify_pair(label_text, value_text)
                logger.info(
                    f"MATCH P{label_cell.page_index} "
                    f"T{label_cell.table_id} R{label_cell.row}C{label_cell.col}: "
                    f"'{label_text}' → '{value_text}' "
                    f"(panel_key={p_key}, inverter_key={i_key})"
                )

                # PANEL
                if p_key is not None:
                    numeric_hint = None
                    # Mapear hints para rangos
                    if p_key in ("Pmax",):
                        numeric_hint = "Pmax"
                    elif p_key in ("Voc", "Vsys_max"):
                        numeric_hint = "Voc"
                    elif p_key in ("Vmp",):
                        numeric_hint = "Vmp"
                    elif p_key in ("Isc",):
                        numeric_hint = "Isc"
                    elif p_key in ("Imp",):
                        numeric_hint = "Imp"
                    elif p_key in ("TempCoeff_Voc",):
                        numeric_hint = "Voc"
                    elif p_key in ("TempCoeff_Pmax",):
                        numeric_hint = "Pmax"

                    value_num, value_text_norm = clean_and_parse_value(value_text, key_hint=numeric_hint)

                    # Particular: IP rating y textos
                    if p_key == "IP_rating_panel":
                        panel_specs["IP_rating_panel"] = value_text_norm
                    elif p_key in ("Length", "Width", "Weight_panel"):
                        # Son numéricos pero sin rangos estrictos
                        val, txt = clean_and_parse_value(value_text, key_hint=None)
                        if val is not None:
                            panel_specs[p_key] = str(val)
                        else:
                            panel_specs[p_key] = txt
                    else:
                        # Campos numéricos típicos
                        if value_num is not None:
                            panel_specs[p_key] = str(value_num)
                        else:
                            # fallback texto
                            panel_specs[p_key] = value_text_norm

                # INVERSOR
                if i_key is not None:
                    numeric_hint = None
                    if i_key == "Vdc_max":
                        numeric_hint = "Vdc_max"
                    elif i_key == "MPPT_count":
                        numeric_hint = "MPPT"
                    elif i_key in ("eff_max", "eff_cec"):
                        # Porcentaje, no usamos rango típico
                        numeric_hint = None

                    value_num, value_text_norm = clean_and_parse_value(value_text, key_hint=numeric_hint)

                    if i_key in ("pf_range",):
                        inverter_specs["pf_range"] = value_text_norm
                    elif i_key == "IP_rating_inv":
                        inverter_specs["IP_rating_inv"] = value_text_norm
                    elif i_key in ("Weight_inv",):
                        val, txt = clean_and_parse_value(value_text, key_hint=None)
                        if val is not None:
                            inverter_specs[i_key] = str(val)
                        else:
                            inverter_specs[i_key] = txt
                    else:
                        # numéricos típicos
                        if value_num is not None:
                            inverter_specs[i_key] = str(value_num)
                        else:
                            inverter_specs[i_key] = value_text_norm

    return panel_specs, inverter_specs


# ---------------------------------------------------------------------
# MAPEOS FINALES A CSV
# ---------------------------------------------------------------------

def build_panel_row_from_specs(specs: Dict[str, str]) -> Dict[str, Optional[str]]:
    """
    Mapea las claves internas del panel a las columnas de salida requeridas.
    """
    row = {
        # Extra: nombre del archivo puede añadirse en main si se desea
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
    """
    Mapea las claves internas del inversor a las columnas de salida requeridas.
    """
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
        print("    python extract_solar_specs_v6c.py <carpeta_pdf>")
        sys.exit(1)

    pdf_folder = sys.argv[1]
    if not os.path.isdir(pdf_folder):
        print(f"La ruta especificada no es una carpeta válida: {pdf_folder}")
        sys.exit(1)

    # Si quieres un flag de debug tipo --debug:
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

            # Opcional: si quieres incluir el nombre del archivo, puedes agregar aquí:
            # panel_row["archivo"] = pdf_basename
            # inverter_row["archivo"] = pdf_basename

            panel_rows.append(panel_row)
            inverter_rows.append(inverter_row)

        except Exception as e:
            logger.exception(f"Error procesando {pdf_basename}: {e}")
            # Aún así, dejamos fila vacía para mantener alineación si se desea
            panel_rows.append(build_panel_row_from_specs({}))
            inverter_rows.append(build_inverter_row_from_specs({}))

    # DataFrames finales
    panel_df = pd.DataFrame(panel_rows, columns=[
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

    # Guardar CSVs en la carpeta base del script
    panel_csv_path = os.path.join(BASE_DIR, "paneles.csv")
    inverter_csv_path = os.path.join(BASE_DIR, "inversores.csv")

    panel_df.to_csv(panel_csv_path, index=False)
    inverter_df.to_csv(inverter_csv_path, index=False)

    logger.info(f"paneles.csv guardado en {panel_csv_path}")
    logger.info(f"inversores.csv guardado en {inverter_csv_path}")
    print(f"Proceso completado.\nPaneles → {panel_csv_path}\nInversores → {inverter_csv_path}")
    print(f"Logs detallados en: {LOG_FILE}")
    print(f"Imágenes de tablas en: {TABLES_DIR}")


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