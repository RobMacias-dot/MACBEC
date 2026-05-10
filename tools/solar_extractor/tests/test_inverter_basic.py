import sys
import os

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, BASE_DIR)

from extract_solar_specs_v8 import process_pdf

BASE_DIR = os.path.dirname(__file__)
PDF = os.path.join(BASE_DIR, "pdfs", "inverter_growatt_6000.pdf")

def test_inverter_basic_extraction():
    data = process_pdf(PDF)

    assert data["type"] == "inverter"

    assert data["brand"] is not None
    assert data["model"] is not None

    assert data.get("max_dc_voltage_v") is None or data["max_dc_voltage_v"] >= 300
    assert data.get("mppt_count") is None or data["mppt_count"] >= 1

    if data.get("max_ac_output_current_a") is not None:
        assert data["max_ac_output_current_a"] > 5

    assert data.get("max_pv_power_w") is not None
    assert data["max_pv_power_w"] > 0

    assert data["inverter_type"] in (
        "monofásico", "bifásico", "trifásico"
    )