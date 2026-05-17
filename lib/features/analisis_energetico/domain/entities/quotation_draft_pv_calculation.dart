class QuotationDraftPvCalculation {
  const QuotationDraftPvCalculation({
    required this.id,
    required this.quotationDraftId,
    required this.annualConsumptionKwh,
    required this.dailyConsumptionKwh,
    required this.peakSunHours,
    required this.panelPowerWatts,
    required this.lossFactor,
    required this.generationPerPanelKwhDay,
    required this.requiredPanels,
    required this.createdAt,
    required this.updatedAt,
    this.panelId,
    this.calculationSnapshotJson,
  });

  final String id;
  final String quotationDraftId;
  final String? panelId;

  final double annualConsumptionKwh;
  final double dailyConsumptionKwh;
  final double peakSunHours;
  final double panelPowerWatts;
  final double lossFactor;
  final double generationPerPanelKwhDay;
  final int requiredPanels;

  final String? calculationSnapshotJson;

  final DateTime createdAt;
  final DateTime updatedAt;
}

class SaveQuotationDraftPvCalculationInput {
  const SaveQuotationDraftPvCalculationInput({
    required this.annualConsumptionKwh,
    required this.dailyConsumptionKwh,
    required this.peakSunHours,
    required this.panelPowerWatts,
    required this.lossFactor,
    required this.generationPerPanelKwhDay,
    required this.requiredPanels,
    this.panelId,
    this.calculationSnapshotJson,
  });

  final String? panelId;

  final double annualConsumptionKwh;
  final double dailyConsumptionKwh;
  final double peakSunHours;
  final double panelPowerWatts;
  final double lossFactor;
  final double generationPerPanelKwhDay;
  final int requiredPanels;

  final String? calculationSnapshotJson;
}
