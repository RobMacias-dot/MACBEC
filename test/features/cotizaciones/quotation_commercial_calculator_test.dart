import 'package:flutter_test/flutter_test.dart';
import 'package:macbec_solar_app/features/catalogo_tecnico/domain/entities/solar_inverter.dart';
import 'package:macbec_solar_app/features/catalogo_tecnico/domain/entities/solar_panel.dart';
import 'package:macbec_solar_app/features/cotizaciones/domain/quotation_commercial_calculator.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  final panel = SolarPanel(
    id: 'panel-1',
    brand: 'Jinko',
    model: 'Tiger Neo 585',
    powerWatts: 585,
    purchasePrice: 2000,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );

  final inverter = SolarInverter(
    id: 'inverter-1',
    brand: 'Growatt',
    model: 'MIN 6000TL-X',
    nominalPowerWatts: 6000,
    purchasePrice: 8000,
    createdAt: now,
    updatedAt: now,
  );

  test('calcula subtotal, IVA y total aplicando utilidad general', () {
    final result = QuotationCommercialCalculator.calculate(
      panel: panel,
      panelQuantity: 10,
      inverter: inverter,
      inverterQuantity: 1,
      generalUtilityRatePercent: 30,
      ivaRatePercent: 16,
      discountAmount: 0,
      advancePaymentAmount: 0,
      currency: 'MXN',
    );

    expect(result.panelUnitPrice, closeTo(2600, 0.001));
    expect(result.inverterUnitPrice, closeTo(10400, 0.001));
    expect(result.subtotal, closeTo(36400, 0.001));
    expect(result.ivaAmount, closeTo(5824, 0.001));
    expect(result.total, closeTo(42224, 0.001));
  });

  test('aplica el descuento antes de calcular el IVA', () {
    final result = QuotationCommercialCalculator.calculate(
      panel: panel,
      panelQuantity: 10,
      inverter: inverter,
      inverterQuantity: 1,
      generalUtilityRatePercent: 30,
      ivaRatePercent: 16,
      discountAmount: 1400,
      advancePaymentAmount: 5000,
      currency: 'MXN',
    );

    expect(result.subtotal, closeTo(36400, 0.001));
    expect(result.ivaAmount, closeTo(5600, 0.001));
    expect(result.total, closeTo(40600, 0.001));
  });

  test('recorta el descuento si supera el subtotal', () {
    final result = QuotationCommercialCalculator.calculate(
      panel: panel,
      panelQuantity: 1,
      inverter: inverter,
      inverterQuantity: 1,
      generalUtilityRatePercent: 0,
      ivaRatePercent: 16,
      discountAmount: 999999,
      advancePaymentAmount: 0,
      currency: 'MXN',
    );

    expect(result.discountAmount, equals(result.subtotal));
    expect(result.ivaAmount, equals(0));
    expect(result.total, equals(0));
  });

  test('usa costo 0 cuando el panel o inversor no tienen precio de compra',
      () {
    final panelSinPrecio = SolarPanel(
      id: 'panel-2',
      brand: 'Sin precio',
      model: 'Modelo',
      powerWatts: 500,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    final result = QuotationCommercialCalculator.calculate(
      panel: panelSinPrecio,
      panelQuantity: 5,
      inverter: inverter,
      inverterQuantity: 1,
      generalUtilityRatePercent: 20,
      ivaRatePercent: 16,
      discountAmount: 0,
      advancePaymentAmount: 0,
      currency: 'MXN',
    );

    expect(result.panelUnitCost, equals(0));
    expect(result.panelUnitPrice, equals(0));
  });

  test('la utilidad por partida sustituye a la utilidad general solo donde se indica',
      () {
    final result = QuotationCommercialCalculator.calculate(
      panel: panel,
      panelQuantity: 10,
      inverter: inverter,
      inverterQuantity: 1,
      generalUtilityRatePercent: 30,
      panelUtilityRatePercent: 10,
      ivaRatePercent: 16,
      discountAmount: 0,
      advancePaymentAmount: 0,
      currency: 'MXN',
    );

    // Panel usa 10% (override), inversor usa 30% (general, sin override).
    expect(result.panelUnitPrice, closeTo(2200, 0.001));
    expect(result.inverterUnitPrice, closeTo(10400, 0.001));
    expect(result.panelUtilityRatePercent, equals(10));
    expect(result.inverterUtilityRatePercent, isNull);
  });
}
