import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../../cotizaciones/application/quotation_draft_navigation.dart';
import '../../../cotizaciones/domain/entities/quotation_draft.dart';
import '../../../cotizaciones/domain/entities/quotation_draft_prospect.dart';
import '../../application/client_quotation_status_provider.dart';
import '../../application/clients_controller.dart';
import '../../domain/entities/client.dart';

/// Pantalla de clientes, separada en 3 pestañas según si tienen o no una
/// cotización asociada. La lista de "prospectos pendientes" que antes vivía
/// en el hub de cotización (`CotizacionScreen`) ahora vive aquí, como la
/// pestaña "Pendiente".
class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsControllerProvider);
    final statusAsync = ref.watch(allClientsQuotationStatusProvider);

    return AppScaffold(
      title: 'Clientes',
      actions: [
        IconButton(
          tooltip: 'Actualizar clientes',
          onPressed: () {
            ref.invalidate(clientsControllerProvider);
            ref.invalidate(allClientsQuotationStatusProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.clienteForm),
        icon: const Icon(Icons.add),
        label: const Text('Cliente'),
      ),
      child: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ClientesErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(clientsControllerProvider),
        ),
        data: (clients) {
          if (clients.isEmpty) {
            return const EmptyState(
              title: 'Sin clientes registrados',
              message: 'Cuando agregues clientes, aparecerán aquí.',
              icon: Icons.people_outline,
            );
          }

          final statusMap = statusAsync.valueOrNull ?? const {};

          final noneClients = <Client>[];
          final pendingClients = <Client>[];
          final completeClients = <Client>[];

          for (final client in clients) {
            final status = statusMap[client.id] ?? ClientQuotationStatus.none;
            switch (status.bucket) {
              case ClientQuotationBucket.none:
                noneClients.add(client);
                break;
              case ClientQuotationBucket.pending:
                pendingClients.add(client);
                break;
              case ClientQuotationBucket.complete:
                completeClients.add(client);
                break;
            }
          }

          return Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Sin cotización (${noneClients.length})'),
                  Tab(text: 'Pendiente (${pendingClients.length})'),
                  Tab(text: 'Completa (${completeClients.length})'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ClientesListView(
                      clients: noneClients,
                      statusMap: statusMap,
                      emptyMessage:
                          'No hay clientes sin cotización. Usa "Nueva cotización" en el dashboard para dar de alta uno.',
                    ),
                    _ClientesListView(
                      clients: pendingClients,
                      statusMap: statusMap,
                      emptyMessage:
                          'No hay cotizaciones pendientes de terminar.',
                    ),
                    _ClientesListView(
                      clients: completeClients,
                      statusMap: statusMap,
                      emptyMessage: 'Todavía no hay cotizaciones completas.',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ClientesListView extends StatelessWidget {
  const _ClientesListView({
    required this.clients,
    required this.statusMap,
    required this.emptyMessage,
  });

  final List<Client> clients;
  final Map<String, ClientQuotationStatus> statusMap;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (clients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: clients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final client = clients[index];
        final status = statusMap[client.id] ?? ClientQuotationStatus.none;
        return _ClientCard(client: client, status: status);
      },
    );
  }
}

class _ClientCard extends ConsumerWidget {
  const _ClientCard({required this.client, required this.status});

  final Client client;
  final ClientQuotationStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      if (_hasValue(client.phone)) client.phone!.trim(),
      if (_hasValue(client.email)) client.email!.trim(),
      if (_hasValue(client.address)) client.address!.trim(),
    ];

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: const Icon(Icons.person_outline),
            ),
            title: Text(
              client.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            subtitle: subtitleParts.isEmpty
                ? const Text('Sin datos de contacto')
                : Text(
                    subtitleParts.join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Eliminar cliente',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.push(AppRoutes.clienteDetalle, extra: client.id),
          ),
          if (status.bucket == ClientQuotationBucket.pending &&
              status.latestDraft != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _continueQuotation(context, ref, status.latestDraft!),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Continuar cotización'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  void _continueQuotation(
    BuildContext context,
    WidgetRef ref,
    QuotationDraft draft,
  ) {
    ref.read(activeQuotationDraftIdProvider.notifier).state = draft.id;
    ref.read(quotationDraftProspectProvider.notifier).state =
        QuotationDraftProspect(
      fullName: draft.prospectName,
      phone: draft.phone,
      whatsapp: draft.whatsapp,
      email: draft.email,
      address: draft.address,
      notes: draft.notes,
    );

    context.push(nextRouteForDraft(draft));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text(
          '¿Seguro que deseas eliminar a "${client.fullName}"? '
          'Esta acción se puede revertir solo desde la base de datos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(clientRepositoryProvider).delete(client.id);
    ref.invalidate(clientsControllerProvider);
    ref.invalidate(allClientsQuotationStatusProvider);
  }
}

class _ClientesErrorView extends StatelessWidget {
  const _ClientesErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudieron cargar los clientes',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
