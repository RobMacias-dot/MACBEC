import 'package:flutter_test/flutter_test.dart';
import 'package:macbec_solar_app/features/analisis_energetico/domain/energy_analysis_rules.dart';

void main() {
  test('suma los 6 bimestres para el consumo anual', () {
    final annual = EnergyAnalysisRules.annualConsumptionKwh(
      [300, 320, 410, 390, 280, 250],
    );

    expect(annual, equals(1950));
  });

  test('el consumo anual es 0 cuando no hay bimestres capturados', () {
    expect(EnergyAnalysisRules.annualConsumptionKwh([]), equals(0));
  });

  test('el consumo diario divide el anual entre 365', () {
    expect(
      EnergyAnalysisRules.dailyConsumptionKwh(3650),
      closeTo(10, 0.0001),
    );
  });

  test('la generacion por panel usa (potencia)(HSP)(factor de perdida)/1000', () {
    final generation = EnergyAnalysisRules.generationPerPanelKwhDay(
      panelPowerWatts: 550,
      peakSunHours: 5.5,
      lossFactor: 0.80,
    );

    expect(generation, closeTo(2.42, 0.001));
  });

  test('el numero de paneles siempre se redondea hacia arriba', () {
    // 10 kWh/dia / 2.42 kWh/dia por panel = 4.13 -> 5 paneles
    final panels = EnergyAnalysisRules.requiredPanels(
      dailyConsumptionKwh: 10,
      generationPerPanelKwhDay: 2.42,
    );

    expect(panels, equals(5));
  });

  test('un numero exacto de paneles no se redondea de mas', () {
    final panels = EnergyAnalysisRules.requiredPanels(
      dailyConsumptionKwh: 10,
      generationPerPanelKwhDay: 2.0,
    );

    expect(panels, equals(5));
  });

  test('devuelve 0 paneles si la generacion por panel no es positiva', () {
    expect(
      EnergyAnalysisRules.requiredPanels(
        dailyConsumptionKwh: 10,
        generationPerPanelKwhDay: 0,
      ),
      equals(0),
    );
  });
}
