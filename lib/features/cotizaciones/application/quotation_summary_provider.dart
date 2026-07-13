import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analisis_energetico/application/energy_analysis_controller.dart';
import '../../analisis_energetico/domain/entities/quotation_draft_pv_calculation.dart';
import '../../catalogo_tecnico/application/inverter_catalog_controller.dart';
import '../../catalogo_tecnico/application/panel_catalog_controller.dart';
import '../../catalogo_tecnico/domain/entities/solar_inverter.dart';
import '../../catalogo_tecnico/domain/entities/solar_panel.dart';
import '../../configuracion/data/commercial_settings_repository.dart';
import '../../configuracion/data/company_settings_repository.dart';
import '../../configuracion/domain/entities/commercial_settings.dart';
import '../../configuracion/domain/entities/company_profile.dart';
import '../../dimensionamiento_electrico/data/electrical_selection_repository.dart';
import '../../dimensionamiento_electrico/domain/electrical_dimensioning_rules.dart';
import '../data/quotation_commercial_repository.dart';
import '../domain/entities/quotation_commercial_quote.dart';
import '../domain/entities/quotation_draft.dart';
import 'quotation_draft_controller.dart';

/// Reúne todo lo necesario para mostrar la cotización interna o la vista de
/// cliente, sin duplicar la lógica de carga en cada pantalla.
class QuotationSummary {
  const QuotationSummary({
    required this.draft,
    required this.pvCalculation,
    required this.panel,
    required this.inverter,
    required this.requiredInverters,
    required this.companyProfile,
    required this.commercialSettings,
    this.commercialQuote,
  });

  final QuotationDraft draft;
  final QuotationDraftPvCalculation pvCalculation;
  final SolarPanel panel;
  final SolarInverter inverter;
  final int requiredInverters;
  final CompanyProfile companyProfile;
  final CommercialSettings commercialSettings;
  final QuotationCommercialQuote? commercialQuote;
}

enum QuotationSummaryIssue {
  missingPvCalculation,
  missingPanel,
  missingElectricalSelection,
  missingInverter,
}

class QuotationSummaryException implements Exception {
  const QuotationSummaryException(this.issue);

  final QuotationSummaryIssue issue;
}

final quotationSummaryProvider =
    FutureProvider.family<QuotationSummary, String>((ref, draftId) async {
  final drafts = await ref.watch(quotationDraftsControllerProvider.future);
  final draft = drafts.firstWhere(
    (item) => item.id == draftId,
    orElse: () => throw StateError('Cotización no encontrada.'),
  );

  final pvCalculation = await ref.watch(
    quotationDraftPvCalculationProvider(draftId).future,
  );

  if (pvCalculation == null) {
    throw const QuotationSummaryException(
      QuotationSummaryIssue.missingPvCalculation,
    );
  }

  final panels = await ref.watch(panelsCatalogProvider.future);
  final panel = _findById(panels, pvCalculation.panelId, (item) => item.id);

  if (panel == null) {
    throw const QuotationSummaryException(QuotationSummaryIssue.missingPanel);
  }

  final electricalSelection = await ref.watch(
    electricalSelectionProvider(draftId).future,
  );

  if (electricalSelection == null) {
    throw const QuotationSummaryException(
      QuotationSummaryIssue.missingElectricalSelection,
    );
  }

  final inverters = await ref.watch(invertersCatalogProvider.future);
  final inverter = _findById(
    inverters,
    electricalSelection.inverterId,
    (item) => item.id,
  );

  if (inverter == null) {
    throw const QuotationSummaryException(
      QuotationSummaryIssue.missingInverter,
    );
  }

  final dimensioningResult = ElectricalDimensioningRules.calculate(
    ElectricalDimensioningInput(
      requiredPanels: pvCalculation.requiredPanels,
      panelPowerWatts: pvCalculation.panelPowerWatts,
      selectedPanel: panel,
      inverters: [inverter],
    ),
  );

  final requiredInverters = dimensioningResult.options.isEmpty
      ? 1
      : dimensioningResult.options.first.requiredInverters;

  final companyProfile =
      await ref.watch(companySettingsRepositoryProvider).getCompanyProfile() ??
          const CompanyProfile.empty();

  final commercialSettings = await ref
      .watch(commercialSettingsRepositoryProvider)
      .getCommercialSettings();

  final commercialQuote = await ref.watch(
    quotationCommercialQuoteProvider(draftId).future,
  );

  return QuotationSummary(
    draft: draft,
    pvCalculation: pvCalculation,
    panel: panel,
    inverter: inverter,
    requiredInverters: requiredInverters,
    companyProfile: companyProfile,
    commercialSettings: commercialSettings,
    commercialQuote: commercialQuote,
  );
});

T? _findById<T>(
  List<T> items,
  String? id,
  String Function(T item) idOf,
) {
  if (id == null) return null;

  for (final item in items) {
    if (idOf(item) == id) return item;
  }

  return null;
}
