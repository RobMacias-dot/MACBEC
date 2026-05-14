import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/database_provider.dart';
import '../data/energy_analysis_repository.dart';
import '../domain/entities/quotation_draft_consumption.dart';

final energyAnalysisRepositoryProvider = Provider<EnergyAnalysisRepository>(
  (ref) {
    return EnergyAnalysisRepository(ref.watch(appDatabaseProvider));
  },
);

final quotationDraftConsumptionsProvider =
    FutureProvider.family<List<QuotationDraftConsumption>, String>(
  (ref, quotationDraftId) async {
    return ref
        .watch(energyAnalysisRepositoryProvider)
        .getDraftConsumptions(quotationDraftId);
  },
);
