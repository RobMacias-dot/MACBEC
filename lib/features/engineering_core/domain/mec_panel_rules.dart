import '../../dimensionamiento_electrico/domain/electrical_dimensioning_rules.dart';
import 'mec_models.dart';

/// Reglas auditables de placa para el MEC. Los resultados se etiquetan como
/// derivados y nunca sustituyen las especificaciones oficiales del panel.
class MecPanelRules {
  const MecPanelRules._();

  static MecStringAssessment assessString({
    required MecPanelSpecification panel,
    required int modulesPerString,
    required int parallelStrings,
    required int moduleCount,
    required double minimumTemperatureCelsius,
  }) {
    final issues = <MecValidationIssue>[];
    final installedPower = ElectricalDimensioningRules.installedDcPower(
      moduleCount: moduleCount,
      modulePmaxWatts: panel.pmaxWatts,
    );

    final coefficient = panel.vocTemperatureCoefficientPerC;
    final coldVoc = coefficient == null
        ? null
        : modulesPerString *
            panel.vocVolts *
            (1 + coefficient.abs() * (25 - minimumTemperatureCelsius));
    if (coefficient == null) {
      issues.add(
        const MecValidationIssue(
          severity: MecValidationSeverity.blocking,
          message: 'Falta el coeficiente de temperatura de Voc del panel.',
        ),
      );
    }

    final stringVmp = modulesPerString * panel.vmpVolts;
    final parallelIsc = parallelStrings * panel.iscAmps;

    if (coldVoc != null && coldVoc > panel.maxSystemVoltage) {
      issues.add(
        const MecValidationIssue(
          severity: MecValidationSeverity.blocking,
          message:
              'El Voc corregido de string excede el voltaje máximo del sistema del panel.',
        ),
      );
    }
    if (parallelIsc > panel.maxSeriesFuseAmps) {
      issues.add(
        const MecValidationIssue(
          severity: MecValidationSeverity.blocking,
          message:
              'La corriente Isc de strings en paralelo excede el fusible máximo en serie del panel.',
        ),
      );
    }

    return MecStringAssessment(
      installedDcPower: MecCalculatedValue(
        value: installedPower,
        status: MecValueStatus.derived,
        description:
            'Potencia DC instalada derivada de Pmax STC y número de módulos.',
      ),
      coldVoc: MecCalculatedValue(
        value: coldVoc,
        status:
            coldVoc == null ? MecValueStatus.missing : MecValueStatus.derived,
        description: 'Voc frío = N × Voc_STC × [1 + |βVoc| × (25 - Tmin)].',
      ),
      stringVmp: MecCalculatedValue(
        value: stringVmp,
        status: MecValueStatus.derived,
        description: 'Vmp de string derivado de módulos en serie.',
      ),
      parallelIsc: MecCalculatedValue(
        value: parallelIsc,
        status: MecValueStatus.derived,
        description: 'Isc de strings en paralelo derivada de Isc STC.',
      ),
      issues: issues,
    );
  }
}
