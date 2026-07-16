import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cotizaciones/application/quotation_draft_controller.dart';
import '../../cotizaciones/application/quotation_draft_navigation.dart';
import '../../cotizaciones/domain/entities/quotation_draft.dart';
import '../../proyectos/application/projects_controller.dart';

enum ClientQuotationBucket { none, pending, complete }

class ClientQuotationStatus {
  const ClientQuotationStatus({
    required this.bucket,
    this.latestDraft,
  });

  final ClientQuotationBucket bucket;
  final QuotationDraft? latestDraft;

  static const none = ClientQuotationStatus(bucket: ClientQuotationBucket.none);
}

/// Cruza clientes con sus borradores de cotización (vía `Proyecto.clientId`
/// → `QuotationDraft.projectId`, ya que el draft no referencia al cliente
/// directamente) para saber, por cliente, si tiene una cotización pendiente
/// o completa. Se resuelve en bloque (todos los proyectos + todos los
/// drafts) en vez de una consulta por cliente para no hacer N+1.
final allClientsQuotationStatusProvider =
    FutureProvider<Map<String, ClientQuotationStatus>>((ref) async {
  final projects = await ref.watch(projectsControllerProvider.future);
  final drafts = await ref.watch(quotationDraftsControllerProvider.future);

  final clientIdByProjectId = <String, String>{
    for (final project in projects) project.id: project.clientId,
  };

  final draftsByClientId = <String, List<QuotationDraft>>{};

  for (final draft in drafts) {
    final projectId = draft.projectId;
    if (projectId == null) continue;

    final clientId = clientIdByProjectId[projectId];
    if (clientId == null) continue;

    draftsByClientId.putIfAbsent(clientId, () => []).add(draft);
  }

  final result = <String, ClientQuotationStatus>{};

  for (final entry in draftsByClientId.entries) {
    final clientDrafts = entry.value
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final latestDraft = clientDrafts.first;

    result[entry.key] = ClientQuotationStatus(
      bucket: isQuotationDraftComplete(latestDraft)
          ? ClientQuotationBucket.complete
          : ClientQuotationBucket.pending,
      latestDraft: latestDraft,
    );
  }

  return result;
});
