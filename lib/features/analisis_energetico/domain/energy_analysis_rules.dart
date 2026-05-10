class EnergyAnalysisRules {
  const EnergyAnalysisRules._();

  static double annualConsumptionKwh(List<double> bimonthlyConsumptions) {
    return bimonthlyConsumptions.fold<double>(0, (sum, value) => sum + value);
  }

  static double dailyConsumptionKwh(double annualConsumptionKwh) {
    return annualConsumptionKwh / 365;
  }

  static double generationPerPanelKwhDay({
    required double panelPowerWatts,
    required double peakSunHours,
    required double lossFactor,
  }) {
    return panelPowerWatts * peakSunHours * lossFactor / 1000;
  }

  static int requiredPanels({
    required double dailyConsumptionKwh,
    required double generationPerPanelKwhDay,
  }) {
    if (generationPerPanelKwhDay <= 0) return 0;
    return (dailyConsumptionKwh / generationPerPanelKwhDay).ceil();
  }
}
