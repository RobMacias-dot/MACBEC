class SolarRadiationRecord {
  const SolarRadiationRecord({
    required this.id,
    required this.stateName,
    required this.municipality,
    required this.peakSunHours,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.source,
    this.sourceUpdatedAt,
  });

  final String id;
  final String stateName;
  final String municipality;
  final double? latitude;
  final double? longitude;
  final double peakSunHours;
  final String? source;
  final DateTime? sourceUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
