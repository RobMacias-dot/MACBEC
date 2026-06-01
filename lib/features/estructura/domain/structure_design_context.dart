class StructureDesignContext {
  const StructureDesignContext({
    required this.panelName,
    required this.panelPowerWatts,
    required this.requiredPanels,
    required this.totalPvPowerWatts,
    required this.inverterName,
    required this.inverterQuantity,
    this.panelLengthMm,
    this.panelWidthMm,
  });

  final String panelName;
  final double panelPowerWatts;
  final int requiredPanels;
  final double totalPvPowerWatts;
  final double? panelLengthMm;
  final double? panelWidthMm;
  final String inverterName;
  final int inverterQuantity;

  bool get hasPanelDimensions {
    return panelLengthMm != null &&
        panelLengthMm! > 0 &&
        panelWidthMm != null &&
        panelWidthMm! > 0;
  }
}
