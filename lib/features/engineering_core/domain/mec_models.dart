/// Estado epistemológico de una especificación o resultado MEC.
enum MecValueStatus { confirmed, derived, missing }

enum MecValidationSeverity { warning, blocking }

class MecPanelSpecification {
  const MecPanelSpecification({
    required this.panelId,
    required this.manufacturer,
    required this.model,
    required this.pmaxWatts,
    required this.vocVolts,
    required this.iscAmps,
    required this.vmpVolts,
    required this.impAmps,
    required this.maxSystemVoltage,
    required this.maxSeriesFuseAmps,
    this.vocTemperatureCoefficientPerC,
  });

  /// Llave estable del catálogo técnico, nunca el nombre visible del panel.
  final String panelId;
  final String manufacturer;
  final String model;
  final double pmaxWatts;
  final double vocVolts;
  final double iscAmps;
  final double vmpVolts;
  final double impAmps;
  final double maxSystemVoltage;
  final double maxSeriesFuseAmps;

  /// Fracción por °C; por ejemplo -0.25 %/°C se guarda como -0.0025.
  final double? vocTemperatureCoefficientPerC;
}

class MecCalculatedValue {
  const MecCalculatedValue({
    required this.value,
    required this.status,
    required this.description,
  });

  final double? value;
  final MecValueStatus status;
  final String description;
}

class MecValidationIssue {
  const MecValidationIssue({required this.severity, required this.message});

  final MecValidationSeverity severity;
  final String message;

  bool get blocksCalculation => severity == MecValidationSeverity.blocking;
}

class MecStringAssessment {
  const MecStringAssessment({
    required this.installedDcPower,
    required this.coldVoc,
    required this.stringVmp,
    required this.parallelIsc,
    required this.issues,
  });

  final MecCalculatedValue installedDcPower;
  final MecCalculatedValue coldVoc;
  final MecCalculatedValue stringVmp;
  final MecCalculatedValue parallelIsc;
  final List<MecValidationIssue> issues;

  bool get canCalculate => !issues.any((issue) => issue.blocksCalculation);
}
