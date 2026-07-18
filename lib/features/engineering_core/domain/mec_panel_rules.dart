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

  static double stringVocAtMinimumTemperature(
      {required MecPanelSpecification panel,
      required int modulesInSeries,
      required double minimumAmbientTemperatureC}) {
    if (modulesInSeries <= 0)
      throw const MecCalculationException(
          'La cantidad de módulos en serie debe ser mayor que cero.');
    _requireCritical(panel.vocV, 'Voc');
    _requireCritical(
        panel.temperatureCoefficientVocPctC, 'coeficiente de temperatura Voc');
    return modulesInSeries *
        panel.vocV.value! *
        (1 +
            (panel.temperatureCoefficientVocPctC.value! / 100) *
                (minimumAmbientTemperatureC - 25));
  }

  static double stringVmpStc(
      {required MecPanelSpecification panel, required int modulesInSeries}) {
    if (modulesInSeries <= 0)
      throw const MecCalculationException(
          'La cantidad de módulos en serie debe ser mayor que cero.');
    _requireCritical(panel.vmpV, 'Vmp');
    return modulesInSeries * panel.vmpV.value!;
  }

  static double parallelIsc(
      {required MecPanelSpecification panel, required int parallelStrings}) {
    if (parallelStrings <= 0)
      throw const MecCalculationException(
          'La cantidad de strings en paralelo debe ser mayor que cero.');
    _requireCritical(panel.iscA, 'Isc');
    return parallelStrings * panel.iscA.value!;
  }

  static double dcArrayPowerW(
      {required MecPanelSpecification panel, required int moduleCount}) {
    if (moduleCount <= 0)
      throw const MecCalculationException(
          'La cantidad de módulos debe ser mayor que cero.');
    _requireCritical(panel.pmaxW, 'Pmax');
    return moduleCount * panel.pmaxW.value!;
  }

  static int maximumModulesByDcVoltage(
      {required MecPanelSpecification panel,
      required double inverterMaximumDcVoltageV,
      required double minimumAmbientTemperatureC,
      double designMargin = 0.98}) {
    if (inverterMaximumDcVoltageV <= 0)
      throw const MecCalculationException(
          'La tensión DC máxima del inversor debe ser mayor que cero.');
    if (designMargin <= 0 || designMargin > 1)
      throw const MecCalculationException(
          'El margen de diseño debe estar entre 0 y 1.');
    final singleModuleColdVoc = stringVocAtMinimumTemperature(
        panel: panel,
        modulesInSeries: 1,
        minimumAmbientTemperatureC: minimumAmbientTemperatureC);
    return math.max(
        0,
        (inverterMaximumDcVoltageV * designMargin / singleModuleColdVoc)
            .floor());
  }

  static double moduleAreaM2(MecPanelSpecification panel) {
    _requireCritical(panel.lengthMm, 'largo');
    _requireCritical(panel.widthMm, 'ancho');
    return (panel.lengthMm.value! / 1000) * (panel.widthMm.value! / 1000);
  }

  static double arrayWeightKg(
      {required MecPanelSpecification panel, required int moduleCount}) {
    if (moduleCount <= 0)
      throw const MecCalculationException(
          'La cantidad de módulos debe ser mayor que cero.');
    _requireCritical(panel.weightKg, 'peso');
    return panel.weightKg.value! * moduleCount;
  }

  /// Evaluación compatible para resultados auditables usados por el flujo MEC.
  static MecStringAssessment assessString(
      {required MecPanelSpecification panel,
      required int modulesPerString,
      required int parallelStrings,
      required int moduleCount,
      required double minimumTemperatureCelsius}) {
    final issues = <MecValidationIssue>[];
    final hasTemperatureCoefficient =
        panel.temperatureCoefficientVocPctC.canDriveCriticalCalculation;
    final coldVoc = hasTemperatureCoefficient
        ? stringVocAtMinimumTemperature(
            panel: panel,
            modulesInSeries: modulesPerString,
            minimumAmbientTemperatureC: minimumTemperatureCelsius)
        : null;
    if (!hasTemperatureCoefficient)
      issues.add(const MecValidationIssue(
          severity: MecValidationSeverity.blocking,
          message: 'Falta el coeficiente de temperatura de Voc del panel.'));
    final installedPower =
        dcArrayPowerW(panel: panel, moduleCount: moduleCount);
    final stringVmp =
        stringVmpStc(panel: panel, modulesInSeries: modulesPerString);
    final current = parallelIsc(panel: panel, parallelStrings: parallelStrings);
    if (coldVoc != null && coldVoc > panel.maxSystemVoltageV.value!)
      issues.add(const MecValidationIssue(
          severity: MecValidationSeverity.blocking,
          message:
              'El Voc corregido de string excede el voltaje máximo del sistema del panel.'));
    if (current > panel.maxSeriesFuseA.value!)
      issues.add(const MecValidationIssue(
          severity: MecValidationSeverity.blocking,
          message:
              'La corriente Isc de strings en paralelo excede el fusible máximo en serie del panel.'));
    return MecStringAssessment(
        installedDcPower: MecCalculatedValue(
            value: installedPower,
            status: MecValueStatus.derived,
            description:
                'Potencia DC instalada derivada de Pmax STC y número de módulos.'),
        coldVoc: MecCalculatedValue(
            value: coldVoc,
            status: coldVoc == null
                ? MecValueStatus.missing
                : MecValueStatus.derived,
            description: 'Voc frío derivado de Voc_STC y temperatura mínima.'),
        stringVmp: MecCalculatedValue(
            value: stringVmp,
            status: MecValueStatus.derived,
            description: 'Vmp de string derivado de módulos en serie.'),
        parallelIsc: MecCalculatedValue(
            value: current,
            status: MecValueStatus.derived,
            description: 'Isc de strings en paralelo derivada de Isc STC.'),
        issues: issues);
  }

  static void _requireCritical<T>(MecValue<T> field, String name) {
    if (!field.canDriveCriticalCalculation)
      throw MecCalculationException(
          'El campo $name no está confirmado por datasheet con confianza alta.');
  }
}
