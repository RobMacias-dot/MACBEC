import 'dart:math';

import '../../analisis_energetico/domain/entities/quotation_draft_pv_calculation.dart';
import '../../catalogo_tecnico/domain/entities/solar_panel.dart';

class TechnicalPanelSelectionResult {
  const TechnicalPanelSelectionResult({
    required this.panel,
    required this.annualConsumptionKwh,
    required this.dailyConsumptionKwh,
    required this.peakSunHours,
    required this.lossFactor,
    required this.generationPerPanelKwhDay,
    required this.requiredPanels,
    required this.totalPanelPowerWatts,
  });

  final SolarPanel panel;
  final double annualConsumptionKwh;
  final double dailyConsumptionKwh;
  final double peakSunHours;
  final double lossFactor;
  final double generationPerPanelKwhDay;
  final int requiredPanels;
  final double totalPanelPowerWatts;
}

class TechnicalSelectionRules {
  const TechnicalSelectionRules._();

  static TechnicalPanelSelectionResult calculatePanel({
    required QuotationDraftPvCalculation pvCalculation,
    required SolarPanel selectedPanel,
  }) {
    final generationPerPanelKwhDay = (selectedPanel.powerWatts *
            pvCalculation.peakSunHours *
            pvCalculation.lossFactor) /
        1000;

    final requiredPanels = generationPerPanelKwhDay <= 0
        ? pvCalculation.requiredPanels
        : max(
            1,
            (pvCalculation.dailyConsumptionKwh / generationPerPanelKwhDay)
                .ceil(),
          );

    return TechnicalPanelSelectionResult(
      panel: selectedPanel,
      annualConsumptionKwh: pvCalculation.annualConsumptionKwh,
      dailyConsumptionKwh: pvCalculation.dailyConsumptionKwh,
      peakSunHours: pvCalculation.peakSunHours,
      lossFactor: pvCalculation.lossFactor,
      generationPerPanelKwhDay: generationPerPanelKwhDay,
      requiredPanels: requiredPanels,
      totalPanelPowerWatts: requiredPanels * selectedPanel.powerWatts,
    );
  }
}
