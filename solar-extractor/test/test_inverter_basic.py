import sys
import os

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, BASE_DIR)

from extract_solar_specs_v7 import process_pdf

BASE_DIR = os.path.dirname(__file__)
PDF = os.path.join(BASE_DIR, "pdfs", "inverter_growatt_6000.pdf")


def test_inverter_basic_extraction():
    data = process_pdf(PDF)

    assert data["type"] == "inverter"

    # Campos críticos
    assert data["brand"] is not None
    assert data["model"] is not None

    assert "max_dc_voltage_v" in data
    if data["max_dc_voltage_v"] is not None:
        assert data["max_dc_voltage_v"] >= 300

    assert data["mppt_count"] >= 1

    assert data["max_ac_output_current_a"] > 10
    assert data["max_pv_power_w"] >= 6000

    # Tipo de fase
    assert data["inverter_type"] in (
        "monofásico", "bifásico", "trifásico"
    )

    assert "max_dc_voltage_v" in data
    assert data["mppt_count"] is not None

