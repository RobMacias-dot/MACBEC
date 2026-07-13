import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../application/clients_controller.dart';
import '../../domain/entities/client.dart';

class ClientesScreen extends ConsumerWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsControllerProvider);

    return AppScaffold(
      title: 'Clientes',
      actions: [
        IconButton(
          tooltip: 'Actualizar clientes',
          onPressed: () => ref.invalidate(clientsControllerProvider),
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

          return _ClientesListView(clients: clients);
        },
      ),
    );
  }
}

class _ClientesListView extends StatelessWidget {
  const _ClientesListView({required this.clients});

  final List<Client> clients;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: clients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final client = clients[index];
        return _ClientCard(client: client);
      },
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      if (_hasValue(client.phone)) client.phone!.trim(),
      if (_hasValue(client.email)) client.email!.trim(),
      if (_hasValue(client.address)) client.address!.trim(),
    ];

    return Card(
      child: ListTile(
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
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.clienteDetalle, extra: client.id),
      ),
    );
  }

  bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
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
