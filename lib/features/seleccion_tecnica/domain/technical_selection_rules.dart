import 'dart:math';

import '../../analisis_energetico/domain/entities/quotation_draft_pv_calculation.dart';
import '../../catalogo_tecnico/domain/entities/solar_panel.dart';
import '../../dimensionamiento_electrico/domain/electrical_dimensioning_rules.dart';
import '../../catalogo_tecnico/domain/entities/solar_inverter.dart';

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

class TechnicalSelectionResult {
  const TechnicalSelectionResult({
    required this.panelResult,
    required this.dimensioningResult,
  });

  final TechnicalPanelSelectionResult panelResult;
  final ElectricalDimensioningResult dimensioningResult;

  ElectricalDimensioningOption? get bestInverterOption {
    return dimensioningResult.bestOption;
  }
}

class TechnicalSelectionRules {
  const TechnicalSelectionRules._();

  static TechnicalSelectionResult calculate({
    required QuotationDraftPvCalculation pvCalculation,
    required SolarPanel selectedPanel,
    required List<SolarInverter> inverters,
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

    final panelResult = TechnicalPanelSelectionResult(
      panel: selectedPanel,
      annualConsumptionKwh: pvCalculation.annualConsumptionKwh,
      dailyConsumptionKwh: pvCalculation.dailyConsumptionKwh,
      peakSunHours: pvCalculation.peakSunHours,
      lossFactor: pvCalculation.lossFactor,
      generationPerPanelKwhDay: generationPerPanelKwhDay,
      requiredPanels: requiredPanels,
      totalPanelPowerWatts: requiredPanels * selectedPanel.powerWatts,
    );

    final dimensioningResult = ElectricalDimensioningRules.calculate(
      ElectricalDimensioningInput(
        requiredPanels: requiredPanels,
        panelPowerWatts: selectedPanel.powerWatts,
        inverters: inverters,
      ),
    );

    return TechnicalSelectionResult(
      panelResult: panelResult,
      dimensioningResult: dimensioningResult,
    );
  }
}
