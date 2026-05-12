import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/database_provider.dart';
import '../data/quotation_draft_repository.dart';
import '../domain/entities/quotation_draft.dart';
import '../domain/entities/quotation_draft_prospect.dart';

final quotationDraftRepositoryProvider =
    Provider<QuotationDraftRepository>((ref) {
  return QuotationDraftRepository(ref.watch(appDatabaseProvider));
});

final quotationDraftsControllerProvider =
    FutureProvider<List<QuotationDraft>>((ref) async {
  return ref.watch(quotationDraftRepositoryProvider).getAllActive();
});

final activeQuotationDraftIdProvider = StateProvider<String?>((ref) {
  return null;
});

final quotationDraftProspectProvider =
    StateProvider<QuotationDraftProspect?>((ref) {
  return null;
});
