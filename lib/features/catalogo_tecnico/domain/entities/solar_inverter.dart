class SolarInverter {
  const SolarInverter({
    required this.id,
    required this.brand,
    required this.model,
    required this.nominalPowerWatts,
    required this.createdAt,
    required this.updatedAt,
    this.maxPvPowerWatts,
    this.maxDcVoltage,
    this.maxShortCircuitCurrentPerMppt,
    this.maxOutputCurrent,
    this.mpptCount,
    this.purchasePrice,
    this.priceSource,
  });

  final String id;
  final String brand;
  final String model;
  final double nominalPowerWatts;

  final double? maxPvPowerWatts;
  final double? maxDcVoltage;
  final double? maxShortCircuitCurrentPerMppt;
  final double? maxOutputCurrent;
  final int? mpptCount;

  final double? purchasePrice;
  final String? priceSource;

  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => '$brand $model';

  bool get hasRequiredTechnicalData {
    return nominalPowerWatts > 0 &&
        maxPvPowerWatts != null &&
        maxPvPowerWatts! > 0 &&
        maxDcVoltage != null &&
        maxDcVoltage! > 0 &&
        maxShortCircuitCurrentPerMppt != null &&
        maxShortCircuitCurrentPerMppt! > 0 &&
        maxOutputCurrent != null &&
        maxOutputCurrent! > 0 &&
        mpptCount != null &&
        mpptCount! > 0;
  }
}

class SaveSolarInverterInput {
  const SaveSolarInverterInput({
    required this.brand,
    required this.model,
    required this.nominalPowerWatts,
    this.maxPvPowerWatts,
    this.maxDcVoltage,
    this.maxShortCircuitCurrentPerMppt,
    this.maxOutputCurrent,
    this.mpptCount,
    this.purchasePrice,
    this.priceSource,
    this.requiresPriceReview = false,
  });

  final String brand;
  final String model;
  final double nominalPowerWatts;

  final double? maxPvPowerWatts;
  final double? maxDcVoltage;
  final double? maxShortCircuitCurrentPerMppt;
  final double? maxOutputCurrent;
  final int? mpptCount;

  final double? purchasePrice;
  final String? priceSource;
  final bool requiresPriceReview;
}
