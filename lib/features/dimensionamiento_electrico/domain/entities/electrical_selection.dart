class ElectricalSelection {
  const ElectricalSelection({
    required this.id,
    required this.quotationDraftId,
    required this.inverterId,
    required this.createdAt,
    required this.updatedAt,
    this.acDistanceMeters,
    this.acVoltage,
    this.acMaterial,
    this.acPhaseType,
  });

  final String id;
  final String quotationDraftId;
  final String inverterId;

  final double? acDistanceMeters;
  final double? acVoltage;
  final String? acMaterial;
  final String? acPhaseType;

  final DateTime createdAt;
  final DateTime updatedAt;
}

class SaveElectricalSelectionInput {
  const SaveElectricalSelectionInput({
    required this.inverterId,
    this.acDistanceMeters,
    this.acVoltage,
    this.acMaterial,
    this.acPhaseType,
  });

  final String inverterId;
  final double? acDistanceMeters;
  final double? acVoltage;
  final String? acMaterial;
  final String? acPhaseType;
}
