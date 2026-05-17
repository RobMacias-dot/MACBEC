class SolarPanel {
  const SolarPanel({
    required this.id,
    required this.brand,
    required this.model,
    required this.powerWatts,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.voc,
    this.isc,
    this.lengthMm,
    this.widthMm,
    this.thicknessMm,
    this.purchasePrice,
  });

  final String id;
  final String brand;
  final String model;
  final double powerWatts;

  final double? voc;
  final double? isc;

  final double? lengthMm;
  final double? widthMm;
  final double? thicknessMm;

  final double? purchasePrice;

  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => '$brand $model';

  bool get hasRequiredTechnicalData {
    return powerWatts > 0 &&
        voc != null &&
        voc! > 0 &&
        isc != null &&
        isc! > 0 &&
        lengthMm != null &&
        lengthMm! > 0 &&
        widthMm != null &&
        widthMm! > 0;
  }
}

class SaveSolarPanelInput {
  const SaveSolarPanelInput({
    required this.brand,
    required this.model,
    required this.powerWatts,
    required this.isActive,
    this.voc,
    this.isc,
    this.lengthMm,
    this.widthMm,
    this.thicknessMm,
    this.purchasePrice,
  });

  final String brand;
  final String model;
  final double powerWatts;

  final double? voc;
  final double? isc;

  final double? lengthMm;
  final double? widthMm;
  final double? thicknessMm;

  final double? purchasePrice;

  final bool isActive;
}
