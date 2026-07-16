import 'package:flutter_test/flutter_test.dart';
import 'package:macbec_solar_app/features/engineering_core/domain/mec_models.dart';
import 'package:macbec_solar_app/features/engineering_core/domain/mec_panel_rules.dart';

void main() {
  const jinko = MecPanelSpecification(
    panelId: 'mec-jinko-66hl4m-bdv',
    manufacturer: 'Jinko Solar',
    model: '66HL4M-BDV',
    pmaxWatts: 620,
    vocVolts: 49.08,
    iscAmps: 16.08,
    vmpVolts: 40.74,
    impAmps: 15.22,
    maxSystemVoltage: 1500,
    maxSeriesFuseAmps: 35,
    vocTemperatureCoefficientPerC: -0.0025,
  );

  MecStringAssessment assess({
    MecPanelSpecification panel = jinko,
    int modulesPerString = 20,
    int parallelStrings = 2,
    int moduleCount = 40,
    double minimumTemperatureCelsius = -10,
  }) =>
      MecPanelRules.assessString(
        panel: panel,
        modulesPerString: modulesPerString,
        parallelStrings: parallelStrings,
        moduleCount: moduleCount,
        minimumTemperatureCelsius: minimumTemperatureCelsius,
      );

  test('calcula potencia DC instalada como dato derivado', () {
    final result = assess();
    expect(result.installedDcPower.value, 24800);
    expect(result.installedDcPower.status, MecValueStatus.derived);
  });

  test('corrige Voc del string a temperatura mínima con beta como fracción',
      () {
    final result = assess();
    // 20 × 49.08 × [1 + 0.0025 × (25 - -10)] = 1067.49 V
    expect(result.coldVoc.value, closeTo(1067.49, 0.01));
    expect(result.coldVoc.status, MecValueStatus.derived);
  });

  test('calcula Vmp del string e Isc total de strings en paralelo', () {
    final result = assess();
    expect(result.stringVmp.value, closeTo(814.8, 0.001));
    expect(result.parallelIsc.value, closeTo(32.16, 0.001));
  });

  test('bloquea el cálculo si Voc frío supera el voltaje máximo del sistema',
      () {
    final result = assess(modulesPerString: 30);
    expect(result.canCalculate, isFalse);
    expect(
      result.issues.any((issue) => issue.message.contains('voltaje máximo')),
      isTrue,
    );
  });

  test('bloquea el cálculo si Isc en paralelo supera el fusible máximo', () {
    final result = assess(parallelStrings: 3);
    expect(result.canCalculate, isFalse);
    expect(
      result.issues.any((issue) => issue.message.contains('fusible máximo')),
      isTrue,
    );
  });

  test('rechaza cálculo de Voc frío cuando falta el coeficiente', () {
    const withoutCoefficient = MecPanelSpecification(
      panelId: 'missing-coefficient',
      manufacturer: 'Test',
      model: 'Missing',
      pmaxWatts: 620,
      vocVolts: 49.08,
      iscAmps: 16.08,
      vmpVolts: 40.74,
      impAmps: 15.22,
      maxSystemVoltage: 1500,
      maxSeriesFuseAmps: 35,
    );
    final result = assess(panel: withoutCoefficient);
    expect(result.coldVoc.value, isNull);
    expect(result.coldVoc.status, MecValueStatus.missing);
    expect(result.canCalculate, isFalse);
  });

  test('distingue datos de placa confirmados de resultados calculados', () {
    final result = assess();
    expect(jinko.vocVolts, 49.08); // valor confirmado de placa
    expect(result.coldVoc.status, MecValueStatus.derived);
    expect(result.parallelIsc.status, MecValueStatus.derived);
  });
}
