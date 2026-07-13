class StructureDesignSelection {
  const StructureDesignSelection({
    required this.id,
    required this.quotationDraftId,
    required this.mountType,
    required this.fixingType,
    required this.structuresCount,
    required this.panelsHorizontal,
    required this.panelRows,
    required this.inclinationDegrees,
    required this.frontLegCm,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String quotationDraftId;
  final String mountType;
  final String fixingType;
  final int structuresCount;
  final int panelsHorizontal;
  final int panelRows;
  final double inclinationDegrees;
  final double frontLegCm;

  final DateTime createdAt;
  final DateTime updatedAt;
}

class SaveStructureDesignSelectionInput {
  const SaveStructureDesignSelectionInput({
    required this.mountType,
    required this.fixingType,
    required this.structuresCount,
    required this.panelsHorizontal,
    required this.panelRows,
    required this.inclinationDegrees,
    required this.frontLegCm,
  });

  final String mountType;
  final String fixingType;
  final int structuresCount;
  final int panelsHorizontal;
  final int panelRows;
  final double inclinationDegrees;
  final double frontLegCm;
}
