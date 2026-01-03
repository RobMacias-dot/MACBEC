import sys
import os

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, BASE_DIR)

from extract_solar_specs_v7 import process_pdf


BASE_DIR = os.path.dirname(__file__)
PDF = os.path.join(BASE_DIR, "pdfs", "panel_jinko_550.pdf")


def test_panel_basic_extraction():
    data = process_pdf(PDF)

    assert data["type"] == "panel"

    # Campos críticos
    assert data["brand"] is not None
    assert data["model"] is not None
    assert "power_w" in data
    assert data["power_w"] is None or data["power_w"] > 0



    assert data["voc_v"] > 40
    assert data["isc_a"] > 10

    # Dimensiones
    assert data["panel_width_mm"] > 1000
    assert data["panel_height_mm"] > 2000

    assert "model" in data
    assert data["power_w"] is not None

