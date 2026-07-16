import 'dart:math' as math;

import 'mec_models.dart';

class MecCalculationException implements Exception {
  const MecCalculationException(this.message);

  final String message;

  @override
  String toString() => 'MecCalculationException: $message';
}

class MecPanelRules {
  const MecPanelRules._();

  static double stringVocAtMinimumTemperature({
    required MecPanelSpecification panel,
    required int modulesInSeries,
    required double minimumAmbientTemperatureC,
  }) {
    if (modulesInSeries <= 0) {
      throw const MecCalculationException(
        'La cantidad de módulos en serie debe ser mayor que cero.',
      );
    }

    _requireCritical(panel.vocV, 'Voc');
    _requireCritical(
      panel.temperatureCoefficientVocPctC,
      'coeficiente de temperatura Voc',
    );

    final voc = panel.vocV.value!;
    final betaPctC = panel.temperatureCoefficientVocPctC.value!;
    final correction = 1 + (betaPctC / 100) * (minimumAmbientTemperatureC - 25);

    return modulesInSeries * voc * correction;
  }

  static double stringVmpStc({
    required MecPanelSpecification panel,
    required int modulesInSeries,
  }) {
    if (modulesInSeries <= 0) {
      throw const MecCalculationException(
        'La cantidad de módulos en serie debe ser mayor que cero.',
      );
    }
    _requireCritical(panel.vmpV, 'Vmp');
    return modulesInSeries * panel.vmpV.value!;
  }

  static double parallelIsc({
    required MecPanelSpecification panel,
    required int parallelStrings,
  }) {
    if (parallelStrings <= 0) {
      throw const MecCalculationException(
        'La cantidad de strings en paralelo debe ser mayor que cero.',
      );
    }
    _requireCritical(panel.iscA, 'Isc');
    return parallelStrings * panel.iscA.value!;
  }

  static double dcArrayPowerW({
    required MecPanelSpecification panel,
    required int moduleCount,
  }) {
    if (moduleCount <= 0) {
      throw const MecCalculationException(
        'La cantidad de módulos debe ser mayor que cero.',
      );
    }
    _requireCritical(panel.pmaxW, 'Pmax');
    return moduleCount * panel.pmaxW.value!;
  }

  static int maximumModulesByDcVoltage({
    required MecPanelSpecification panel,
    required double inverterMaximumDcVoltageV,
    required double minimumAmbientTemperatureC,
    double designMargin = 0.98,
  }) {
    if (inverterMaximumDcVoltageV <= 0) {
      throw const MecCalculationException(
        'La tensión DC máxima del inversor debe ser mayor que cero.',
      );
    }
    if (designMargin <= 0 || designMargin > 1) {
      throw const MecCalculationException(
        'El margen de diseño debe estar entre 0 y 1.',
      );
    }

    _requireCritical(panel.vocV, 'Voc');
    _requireCritical(
      panel.temperatureCoefficientVocPctC,
      'coeficiente de temperatura Voc',
    );

    final singleModuleColdVoc = stringVocAtMinimumTemperature(
      panel: panel,
      modulesInSeries: 1,
      minimumAmbientTemperatureC: minimumAmbientTemperatureC,
    );

    return math.max(
      0,
      (inverterMaximumDcVoltageV * designMargin / singleModuleColdVoc).floor(),
    );
  }

  static double moduleAreaM2(MecPanelSpecification panel) {
    _requireCritical(panel.lengthMm, 'largo');
    _requireCritical(panel.widthMm, 'ancho');
    return (panel.lengthMm.value! / 1000) * (panel.widthMm.value! / 1000);
  }

  static double arrayWeightKg({
    required MecPanelSpecification panel,
    required int moduleCount,
  }) {
    if (moduleCount <= 0) {
      throw const MecCalculationException(
        'La cantidad de módulos debe ser mayor que cero.',
      );
    }
    _requireCritical(panel.weightKg, 'peso');
    return panel.weightKg.value! * moduleCount;
  }

  static void _requireCritical<T>(MecValue<T> field, String name) {
    if (!field.canDriveCriticalCalculation) {
      throw MecCalculationException(
        'El campo $name no está confirmado por datasheet con confianza alta.',
      );
    }
  }
}
