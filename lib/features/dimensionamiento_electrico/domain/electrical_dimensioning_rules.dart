import 'dart:math';

import '../../catalogo_tecnico/domain/entities/solar_inverter.dart';
import '../../catalogo_tecnico/domain/entities/solar_panel.dart';

class ElectricalDimensioningInput {
  const ElectricalDimensioningInput({
    required this.requiredPanels,
    required this.panelPowerWatts,
    required this.inverters,
    this.selectedPanel,
  });

  final int requiredPanels;
  final double panelPowerWatts;
  final SolarPanel? selectedPanel;
  final List<SolarInverter> inverters;

  double get effectivePanelPowerWatts {
    return selectedPanel?.powerWatts ?? panelPowerWatts;
  }

  double get totalPanelPowerWatts => requiredPanels * effectivePanelPowerWatts;
}

enum AcConductorMaterial {
  copper,
  aluminum,
}

extension AcConductorMaterialInfo on AcConductorMaterial {
  String get label {
    switch (this) {
      case AcConductorMaterial.copper:
        return 'Cobre';
      case AcConductorMaterial.aluminum:
        return 'Aluminio';
    }
  }

  double get resistivity {
    switch (this) {
      case AcConductorMaterial.copper:
        return 0.017;
      case AcConductorMaterial.aluminum:
        return 0.028;
    }
  }
}

enum AcPhaseType {
  bifasic,
  threePhase,
}

extension AcPhaseTypeInfo on AcPhaseType {
  String get label {
    switch (this) {
      case AcPhaseType.bifasic:
        return 'Bifásico';
      case AcPhaseType.threePhase:
        return 'Trifásico';
    }
  }

  double get defaultVoltage {
    switch (this) {
      case AcPhaseType.bifasic:
        return 220;
      case AcPhaseType.threePhase:
        return 440;
    }
  }

  double get voltageDropFactor {
    switch (this) {
      case AcPhaseType.bifasic:
        return 2;
      case AcPhaseType.threePhase:
        return sqrt(3) * 2;
    }
  }
}

class ElectricalAcInput {
  const ElectricalAcInput({
    required this.distanceMeters,
    required this.material,
    required this.phaseType,
    required this.voltage,
  });

  final double distanceMeters;
  final AcConductorMaterial material;
  final AcPhaseType phaseType;
  final double voltage;
}

class AcCableRecommendation {
  const AcCableRecommendation({
    required this.distanceMeters,
    required this.currentAmps,
    required this.voltage,
    required this.material,
    required this.phaseType,
    required this.suggestedAwg,
    required this.conductorAreaMm2,
    required this.ampacityAmps,
    required this.voltageDropPercent,
    required this.isVoltageDropOk,
  });

  final double distanceMeters;
  final double currentAmps;
  final double voltage;
  final AcConductorMaterial material;
  final AcPhaseType phaseType;
  final String suggestedAwg;
  final double conductorAreaMm2;
  final int ampacityAmps;
  final double voltageDropPercent;
  final bool isVoltageDropOk;

  String get summaryLabel {
    return '$suggestedAwg AWG · ${voltageDropPercent.toStringAsFixed(2)}% caída · ${material.label}';
  }
}

class DcFuseRecommendation {
  const DcFuseRecommendation({
    required this.panelIsc,
    required this.calculatedFuseAmps,
    required this.suggestedCommercialFuseAmps,
  });

  final double panelIsc;
  final double calculatedFuseAmps;
  final int suggestedCommercialFuseAmps;

  String get formulaLabel {
    return '${panelIsc.toStringAsFixed(2)} A × 1.25 = ${calculatedFuseAmps.toStringAsFixed(2)} A';
  }
}

class DcCableRecommendation {
  const DcCableRecommendation({
    required this.designCurrentAmps,
    required this.suggestedAwg,
    required this.ampacityAmps,
    required this.requiredStrings,
    required this.conductorsPerString,
    required this.totalConductors,
  });

  final double designCurrentAmps;
  final String suggestedAwg;
  final int ampacityAmps;
  final int requiredStrings;
  final int conductorsPerString;
  final int totalConductors;

  String get summaryLabel {
    return '$suggestedAwg AWG · $ampacityAmps A · $totalConductors conductores DC';
  }
}

class DcConduitRecommendation {
  const DcConduitRecommendation({
    required this.totalConductors,
    required this.suggestedConduitTradeSize,
    required this.note,
  });

  final int totalConductors;
  final String suggestedConduitTradeSize;
  final String note;
}

class ElectricalDimensioningOption {
  const ElectricalDimensioningOption({
    required this.inverter,
    required this.requiredInverters,
    required this.totalPvCapacityWatts,
    required this.totalPanelPowerWatts,
    required this.powerMarginWatts,
    required this.powerMarginPercent,
    required this.inverterUsagePercent,
    required this.reserveCapacityPercent,
    required this.isPowerCompatible,
    required this.hasPanelTechnicalData,
    required this.hasInverterTechnicalData,
    required this.isStringConfigurationCompatible,
    required this.warnings,
    this.maxPanelsPerString,
    this.maxParallelStringsPerMppt,
    this.totalStringCapacity,
    this.requiredStrings,
    this.suggestedPanelsPerString,
    this.dcFuseRecommendation,
    this.dcCableRecommendation,
    this.dcConduitRecommendation,
  });

  final SolarInverter inverter;
  final int requiredInverters;
  final double totalPvCapacityWatts;
  final double totalPanelPowerWatts;
  final double powerMarginWatts;

  /// Se conserva para uso interno, pero en UI se prefiere mostrar
  /// inverterUsagePercent porque es más fácil de interpretar.
  final double powerMarginPercent;

  /// Porcentaje de uso del inversor respecto a su capacidad FV.
  final double inverterUsagePercent;

  /// Reserva disponible en porcentaje sencillo respecto al 100% de capacidad.
  final double reserveCapacityPercent;

  final bool isPowerCompatible;

  final bool hasPanelTechnicalData;
  final bool hasInverterTechnicalData;

  final int? maxPanelsPerString;
  final int? maxParallelStringsPerMppt;
  final int? totalStringCapacity;
  final int? requiredStrings;
  final int? suggestedPanelsPerString;

  final bool isStringConfigurationCompatible;
  final List<String> warnings;

  final DcFuseRecommendation? dcFuseRecommendation;
  final DcCableRecommendation? dcCableRecommendation;
  final DcConduitRecommendation? dcConduitRecommendation;

  bool get hasCompleteTechnicalData {
    return hasPanelTechnicalData && hasInverterTechnicalData;
  }

  bool get isCompatible {
    return isPowerCompatible &&
        hasCompleteTechnicalData &&
        isStringConfigurationCompatible;
  }

  bool get isRecommendedUsage {
    return inverterUsagePercent >= 45 && inverterUsagePercent <= 85;
  }

  bool get isLowUsage {
    return inverterUsagePercent > 0 && inverterUsagePercent < 35;
  }

  bool get isVeryLowUsage {
    return inverterUsagePercent > 0 && inverterUsagePercent < 25;
  }

  bool get isHighUsage {
    return inverterUsagePercent > 85;
  }

  String get usageLabel {
    if (!isPowerCompatible) {
      return 'No cubre la potencia FV';
    }

    if (isVeryLowUsage) {
      return 'Muy sobredimensionado';
    }

    if (isLowUsage) {
      return 'Sobredimensionado';
    }

    if (isRecommendedUsage) {
      return 'Uso recomendado';
    }

    if (isHighUsage) {
      return 'Uso alto, revisar crecimiento';
    }

    return 'Compatible';
  }

  String get statusLabel {
    if (!isPowerCompatible) {
      return 'No compatible por potencia';
    }

    if (!hasPanelTechnicalData) {
      return 'Faltan datos técnicos del panel';
    }

    if (!hasInverterTechnicalData) {
      return 'Faltan datos técnicos del inversor';
    }

    if (!isStringConfigurationCompatible) {
      return 'No compatible por Voc/Isc/MPPT';
    }

    if (isVeryLowUsage) {
      return 'Compatible, pero muy sobredimensionado';
    }

    if (isLowUsage) {
      return 'Compatible, pero sobredimensionado';
    }

    if (isRecommendedUsage) {
      return 'Recomendado preliminarmente';
    }

    if (isHighUsage) {
      return 'Compatible, revisar margen futuro';
    }

    return 'Compatible preliminarmente';
  }
}

class ElectricalDimensioningResult {
  const ElectricalDimensioningResult({
    required this.requiredPanels,
    required this.panelPowerWatts,
    required this.totalPanelPowerWatts,
    required this.options,
    this.selectedPanel,
  });

  final int requiredPanels;
  final double panelPowerWatts;
  final double totalPanelPowerWatts;
  final SolarPanel? selectedPanel;
  final List<ElectricalDimensioningOption> options;

  List<ElectricalDimensioningOption> get compatibleOptions {
    return options.where((option) => option.isCompatible).toList();
  }

  List<ElectricalDimensioningOption> get powerCompatibleOptions {
    return options.where((option) => option.isPowerCompatible).toList();
  }

  ElectricalDimensioningOption? get bestOption {
    final compatible = compatibleOptions;

    if (compatible.isNotEmpty) return compatible.first;

    final powerCompatible = powerCompatibleOptions;

    if (powerCompatible.isNotEmpty) return powerCompatible.first;

    if (options.isEmpty) return null;

    return options.first;
  }
}

class ElectricalDimensioningRules {
  const ElectricalDimensioningRules._();

  static const int _conductorsPerDcString = 3;

  static const List<int> _commercialDcFuseSizes = [
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    60,
    70,
    80,
    90,
    100,
    110,
    125,
    150,
    175,
    200,
  ];

  static const List<_AwgAmpacityReference> _dcCableReferences = [
    _AwgAmpacityReference(awg: '14', ampacityAmps: 15, areaMm2: 2.08),
    _AwgAmpacityReference(awg: '12', ampacityAmps: 20, areaMm2: 3.31),
    _AwgAmpacityReference(awg: '10', ampacityAmps: 30, areaMm2: 5.26),
    _AwgAmpacityReference(awg: '8', ampacityAmps: 40, areaMm2: 8.37),
    _AwgAmpacityReference(awg: '6', ampacityAmps: 55, areaMm2: 13.3),
    _AwgAmpacityReference(awg: '4', ampacityAmps: 70, areaMm2: 21.2),
    _AwgAmpacityReference(awg: '3', ampacityAmps: 85, areaMm2: 26.7),
    _AwgAmpacityReference(awg: '2', ampacityAmps: 95, areaMm2: 33.6),
    _AwgAmpacityReference(awg: '1', ampacityAmps: 110, areaMm2: 42.4),
    _AwgAmpacityReference(awg: '1/0', ampacityAmps: 125, areaMm2: 53.5),
    _AwgAmpacityReference(awg: '2/0', ampacityAmps: 145, areaMm2: 67.4),
    _AwgAmpacityReference(awg: '3/0', ampacityAmps: 165, areaMm2: 85.0),
    _AwgAmpacityReference(awg: '4/0', ampacityAmps: 195, areaMm2: 107.0),
  ];

  static ElectricalDimensioningResult calculate(
    ElectricalDimensioningInput input,
  ) {
    final selectedPanel = input.selectedPanel;
    final totalPanelPowerWatts = input.totalPanelPowerWatts;

    final options = <ElectricalDimensioningOption>[];

    for (final inverter in input.inverters) {
      final capacityPerInverterWatts =
          inverter.maxPvPowerWatts ?? inverter.nominalPowerWatts;

      if (capacityPerInverterWatts <= 0 || totalPanelPowerWatts <= 0) {
        continue;
      }

      final requiredInverters =
          (totalPanelPowerWatts / capacityPerInverterWatts).ceil();

      final safeRequiredInverters =
          requiredInverters < 1 ? 1 : requiredInverters;

      final totalPvCapacityWatts =
          capacityPerInverterWatts * safeRequiredInverters;

      final powerMarginWatts = totalPvCapacityWatts - totalPanelPowerWatts;

      final powerMarginPercent = totalPanelPowerWatts <= 0
          ? 0.0
          : (powerMarginWatts / totalPanelPowerWatts) * 100;

      final inverterUsagePercent = totalPvCapacityWatts <= 0
          ? 0.0
          : (totalPanelPowerWatts / totalPvCapacityWatts) * 100;

      final reserveCapacityPercent =
          (100 - inverterUsagePercent).clamp(0, 100).toDouble();

      final technicalValidation = _validateStringConfiguration(
        selectedPanel: selectedPanel,
        inverter: inverter,
        requiredPanels: input.requiredPanels,
        requiredInverters: safeRequiredInverters,
      );

      final fuseRecommendation = _calculateDcFuseRecommendation(selectedPanel);
      final cableRecommendation = _calculateDcCableRecommendation(
        fuseRecommendation: fuseRecommendation,
        requiredStrings: technicalValidation.requiredStrings,
      );
      final conduitRecommendation = _calculateDcConduitRecommendation(
        cableRecommendation: cableRecommendation,
      );

      options.add(
        ElectricalDimensioningOption(
          inverter: inverter,
          requiredInverters: safeRequiredInverters,
          totalPvCapacityWatts: totalPvCapacityWatts,
          totalPanelPowerWatts: totalPanelPowerWatts,
          powerMarginWatts: powerMarginWatts,
          powerMarginPercent: powerMarginPercent,
          inverterUsagePercent: inverterUsagePercent,
          reserveCapacityPercent: reserveCapacityPercent,
          isPowerCompatible: totalPvCapacityWatts >= totalPanelPowerWatts,
          hasPanelTechnicalData: technicalValidation.hasPanelTechnicalData,
          hasInverterTechnicalData:
              technicalValidation.hasInverterTechnicalData,
          maxPanelsPerString: technicalValidation.maxPanelsPerString,
          maxParallelStringsPerMppt:
              technicalValidation.maxParallelStringsPerMppt,
          totalStringCapacity: technicalValidation.totalStringCapacity,
          requiredStrings: technicalValidation.requiredStrings,
          suggestedPanelsPerString:
              technicalValidation.suggestedPanelsPerString,
          isStringConfigurationCompatible:
              technicalValidation.isStringConfigurationCompatible,
          warnings: technicalValidation.warnings,
          dcFuseRecommendation: fuseRecommendation,
          dcCableRecommendation: cableRecommendation,
          dcConduitRecommendation: conduitRecommendation,
        ),
      );
    }

    options.sort((a, b) {
      final compatibilityComparison = _boolScore(b.isCompatible).compareTo(
        _boolScore(a.isCompatible),
      );

      if (compatibilityComparison != 0) {
        return compatibilityComparison;
      }

      final usageQualityComparison = _usageQualityScore(b).compareTo(
        _usageQualityScore(a),
      );

      if (usageQualityComparison != 0) {
        return usageQualityComparison;
      }

      final powerCompatibilityComparison =
          _boolScore(b.isPowerCompatible).compareTo(
        _boolScore(a.isPowerCompatible),
      );

      if (powerCompatibilityComparison != 0) {
        return powerCompatibilityComparison;
      }

      final inverterCountComparison =
          a.requiredInverters.compareTo(b.requiredInverters);

      if (inverterCountComparison != 0) {
        return inverterCountComparison;
      }

      final technicalDataComparison =
          _boolScore(b.hasCompleteTechnicalData).compareTo(
        _boolScore(a.hasCompleteTechnicalData),
      );

      if (technicalDataComparison != 0) {
        return technicalDataComparison;
      }

      return _distanceFromIdealUsage(a).compareTo(_distanceFromIdealUsage(b));
    });

    return ElectricalDimensioningResult(
      requiredPanels: input.requiredPanels,
      panelPowerWatts: input.effectivePanelPowerWatts,
      totalPanelPowerWatts: totalPanelPowerWatts,
      selectedPanel: selectedPanel,
      options: options,
    );
  }

  static AcCableRecommendation? calculateAcCableRecommendation({
    required ElectricalDimensioningOption option,
    required ElectricalAcInput input,
  }) {
    final currentAmps = option.inverter.maxOutputCurrent;

    if (currentAmps == null ||
        currentAmps <= 0 ||
        input.distanceMeters <= 0 ||
        input.voltage <= 0) {
      return null;
    }

    for (final reference in _dcCableReferences) {
      if (reference.ampacityAmps < currentAmps) {
        continue;
      }

      final voltageDropPercent = _calculateVoltageDropPercent(
        distanceMeters: input.distanceMeters,
        currentAmps: currentAmps,
        resistivity: input.material.resistivity,
        areaMm2: reference.areaMm2,
        voltage: input.voltage,
        phaseType: input.phaseType,
      );

      if (voltageDropPercent <= 3) {
        return AcCableRecommendation(
          distanceMeters: input.distanceMeters,
          currentAmps: currentAmps,
          voltage: input.voltage,
          material: input.material,
          phaseType: input.phaseType,
          suggestedAwg: reference.awg,
          conductorAreaMm2: reference.areaMm2,
          ampacityAmps: reference.ampacityAmps,
          voltageDropPercent: voltageDropPercent,
          isVoltageDropOk: true,
        );
      }
    }

    final largestReference = _dcCableReferences.last;
    final largestVoltageDrop = _calculateVoltageDropPercent(
      distanceMeters: input.distanceMeters,
      currentAmps: currentAmps,
      resistivity: input.material.resistivity,
      areaMm2: largestReference.areaMm2,
      voltage: input.voltage,
      phaseType: input.phaseType,
    );

    return AcCableRecommendation(
      distanceMeters: input.distanceMeters,
      currentAmps: currentAmps,
      voltage: input.voltage,
      material: input.material,
      phaseType: input.phaseType,
      suggestedAwg: largestReference.awg,
      conductorAreaMm2: largestReference.areaMm2,
      ampacityAmps: largestReference.ampacityAmps,
      voltageDropPercent: largestVoltageDrop,
      isVoltageDropOk: largestVoltageDrop <= 3,
    );
  }

  static double _calculateVoltageDropPercent({
    required double distanceMeters,
    required double currentAmps,
    required double resistivity,
    required double areaMm2,
    required double voltage,
    required AcPhaseType phaseType,
  }) {
    return (phaseType.voltageDropFactor *
            distanceMeters *
            currentAmps *
            resistivity /
            (areaMm2 * voltage)) *
        100;
  }

  static DcFuseRecommendation? _calculateDcFuseRecommendation(
    SolarPanel? selectedPanel,
  ) {
    final panelIsc = selectedPanel?.isc;

    if (panelIsc == null || panelIsc <= 0) {
      return null;
    }

    final calculatedFuseAmps = panelIsc * 1.25;

    return DcFuseRecommendation(
      panelIsc: panelIsc,
      calculatedFuseAmps: calculatedFuseAmps,
      suggestedCommercialFuseAmps: _nextCommercialFuseSize(
        calculatedFuseAmps,
      ),
    );
  }

  static DcCableRecommendation? _calculateDcCableRecommendation({
    required DcFuseRecommendation? fuseRecommendation,
    required int? requiredStrings,
  }) {
    if (fuseRecommendation == null ||
        requiredStrings == null ||
        requiredStrings <= 0) {
      return null;
    }

    final designCurrent = fuseRecommendation.calculatedFuseAmps;
    final awgReference = _selectAwgByAmpacity(designCurrent);
    final totalConductors = requiredStrings * _conductorsPerDcString;

    return DcCableRecommendation(
      designCurrentAmps: designCurrent,
      suggestedAwg: awgReference.awg,
      ampacityAmps: awgReference.ampacityAmps,
      requiredStrings: requiredStrings,
      conductorsPerString: _conductorsPerDcString,
      totalConductors: totalConductors,
    );
  }

  static DcConduitRecommendation? _calculateDcConduitRecommendation({
    required DcCableRecommendation? cableRecommendation,
  }) {
    if (cableRecommendation == null) {
      return null;
    }

    final totalConductors = cableRecommendation.totalConductors;

    final suggestedSize = switch (totalConductors) {
      <= 3 => '1/2"',
      <= 6 => '3/4"',
      <= 10 => '1"',
      <= 16 => '1 1/4"',
      <= 24 => '1 1/2"',
      _ => '2" o mayor',
    };

    return DcConduitRecommendation(
      totalConductors: totalConductors,
      suggestedConduitTradeSize: suggestedSize,
      note:
          'Preliminar. Validar con tabla real de llenado de tubería, tipo de conductor, temperatura y norma aplicable.',
    );
  }

  static _AwgAmpacityReference _selectAwgByAmpacity(double designCurrent) {
    for (final reference in _dcCableReferences) {
      if (reference.ampacityAmps >= designCurrent) {
        return reference;
      }
    }

    return _dcCableReferences.last;
  }

  static int _nextCommercialFuseSize(double calculatedFuseAmps) {
    for (final size in _commercialDcFuseSizes) {
      if (size >= calculatedFuseAmps) {
        return size;
      }
    }

    return calculatedFuseAmps.ceil();
  }

  static _StringConfigurationValidation _validateStringConfiguration({
    required SolarPanel? selectedPanel,
    required SolarInverter inverter,
    required int requiredPanels,
    required int requiredInverters,
  }) {
    final warnings = <String>[];

    if (selectedPanel == null ||
        selectedPanel.voc == null ||
        selectedPanel.voc! <= 0 ||
        selectedPanel.isc == null ||
        selectedPanel.isc! <= 0) {
      warnings.add(
        'El panel seleccionado necesita Voc e Isc para validar series y paralelos.',
      );

      final hasInverterTechnicalData = inverter.maxDcVoltage != null &&
          inverter.maxDcVoltage! > 0 &&
          inverter.maxShortCircuitCurrentPerMppt != null &&
          inverter.maxShortCircuitCurrentPerMppt! > 0 &&
          inverter.mpptCount != null &&
          inverter.mpptCount! > 0;

      if (!hasInverterTechnicalData) {
        warnings.add(
          'El inversor necesita voltaje CD máximo, corriente de corto circuito por MPPT y número de MPPT.',
        );
      }

      return _StringConfigurationValidation(
        hasPanelTechnicalData: false,
        hasInverterTechnicalData: hasInverterTechnicalData,
        isStringConfigurationCompatible: false,
        warnings: warnings,
      );
    }

    final hasInverterTechnicalData = inverter.maxDcVoltage != null &&
        inverter.maxDcVoltage! > 0 &&
        inverter.maxShortCircuitCurrentPerMppt != null &&
        inverter.maxShortCircuitCurrentPerMppt! > 0 &&
        inverter.mpptCount != null &&
        inverter.mpptCount! > 0;

    if (!hasInverterTechnicalData) {
      warnings.add(
        'El inversor necesita voltaje CD máximo, corriente de corto circuito por MPPT y número de MPPT.',
      );

      return _StringConfigurationValidation(
        hasPanelTechnicalData: true,
        hasInverterTechnicalData: false,
        isStringConfigurationCompatible: false,
        warnings: warnings,
      );
    }

    final voc = selectedPanel.voc!;
    final isc = selectedPanel.isc!;
    final maxDcVoltage = inverter.maxDcVoltage!;
    final maxShortCircuitCurrentPerMppt =
        inverter.maxShortCircuitCurrentPerMppt!;
    final mpptCount = inverter.mpptCount!;

    final maxPanelsPerString = (maxDcVoltage / voc).floor();
    final maxParallelStringsPerMppt =
        (maxShortCircuitCurrentPerMppt / isc).floor();

    if (maxPanelsPerString <= 0) {
      warnings.add(
        'El Voc del panel supera o iguala el voltaje CD máximo permitido por el inversor.',
      );
    }

    if (maxParallelStringsPerMppt <= 0) {
      warnings.add(
        'El Isc del panel supera o iguala la corriente máxima por MPPT del inversor.',
      );
    }

    if (maxPanelsPerString <= 0 || maxParallelStringsPerMppt <= 0) {
      return _StringConfigurationValidation(
        hasPanelTechnicalData: true,
        hasInverterTechnicalData: true,
        maxPanelsPerString: maxPanelsPerString,
        maxParallelStringsPerMppt: maxParallelStringsPerMppt,
        isStringConfigurationCompatible: false,
        warnings: warnings,
      );
    }

    final totalStringCapacity = maxPanelsPerString *
        maxParallelStringsPerMppt *
        mpptCount *
        requiredInverters;

    final requiredStrings = (requiredPanels / maxPanelsPerString).ceil();
    final suggestedPanelsPerString = (requiredPanels / requiredStrings).ceil();

    final isCompatible = totalStringCapacity >= requiredPanels;

    if (!isCompatible) {
      warnings.add(
        'La capacidad aproximada por Voc/Isc/MPPT no alcanza para los paneles requeridos.',
      );
    }

    return _StringConfigurationValidation(
      hasPanelTechnicalData: true,
      hasInverterTechnicalData: true,
      maxPanelsPerString: maxPanelsPerString,
      maxParallelStringsPerMppt: maxParallelStringsPerMppt,
      totalStringCapacity: totalStringCapacity,
      requiredStrings: requiredStrings,
      suggestedPanelsPerString: suggestedPanelsPerString,
      isStringConfigurationCompatible: isCompatible,
      warnings: warnings,
    );
  }

  static int _usageQualityScore(ElectricalDimensioningOption option) {
    if (!option.isPowerCompatible) return 0;

    if (option.inverterUsagePercent >= 45 &&
        option.inverterUsagePercent <= 85) {
      return 4;
    }

    if (option.inverterUsagePercent >= 35 && option.inverterUsagePercent < 45) {
      return 3;
    }

    if (option.inverterUsagePercent > 85 && option.inverterUsagePercent <= 95) {
      return 2;
    }

    if (option.inverterUsagePercent >= 25 && option.inverterUsagePercent < 35) {
      return 1;
    }

    return 0;
  }

  static double _distanceFromIdealUsage(ElectricalDimensioningOption option) {
    const idealUsagePercent = 70.0;

    return (option.inverterUsagePercent - idealUsagePercent).abs();
  }

  static int _boolScore(bool value) => value ? 1 : 0;
}

class _StringConfigurationValidation {
  const _StringConfigurationValidation({
    required this.hasPanelTechnicalData,
    required this.hasInverterTechnicalData,
    required this.isStringConfigurationCompatible,
    required this.warnings,
    this.maxPanelsPerString,
    this.maxParallelStringsPerMppt,
    this.totalStringCapacity,
    this.requiredStrings,
    this.suggestedPanelsPerString,
  });

  final bool hasPanelTechnicalData;
  final bool hasInverterTechnicalData;
  final int? maxPanelsPerString;
  final int? maxParallelStringsPerMppt;
  final int? totalStringCapacity;
  final int? requiredStrings;
  final int? suggestedPanelsPerString;
  final bool isStringConfigurationCompatible;
  final List<String> warnings;
}

class _AwgAmpacityReference {
  const _AwgAmpacityReference({
    required this.awg,
    required this.ampacityAmps,
    required this.areaMm2,
  });

  final String awg;
  final int ampacityAmps;
  final double areaMm2;
}
