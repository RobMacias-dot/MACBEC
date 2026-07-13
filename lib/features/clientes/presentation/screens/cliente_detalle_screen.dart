import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../proyectos/application/projects_controller.dart';
import '../../../proyectos/domain/entities/project.dart';
import '../../../proyectos/presentation/screens/proyecto_form_screen.dart';
import '../../application/clients_controller.dart';

class ClienteDetalleScreen extends ConsumerWidget {
  const ClienteDetalleScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientByIdProvider(clientId));

    return AppScaffold(
      title: 'Detalle de cliente',
      actions: [
        IconButton(
          tooltip: 'Editar cliente',
          onPressed: () =>
              context.push(AppRoutes.clienteForm, extra: clientId),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
      child: clientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          title: 'No se pudo cargar el cliente',
          message: error.toString(),
          icon: Icons.error_outline,
        ),
        data: (client) {
          if (client == null) {
            return const EmptyState(
              title: 'Cliente no encontrado',
              message: 'Puede que haya sido eliminado.',
              icon: Icons.person_off_outlined,
            );
          }

          final details = <String>[
            if (_hasValue(client.phone)) client.phone!.trim(),
            if (_hasValue(client.email)) client.email!.trim(),
            if (_hasValue(client.address)) client.address!.trim(),
          ];

          final projectsAsync = ref.watch(projectsByClientProvider(clientId));

          return ListView(
            children: [
              SectionCard(
                title: client.fullName,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (details.isNotEmpty)
                      Text(details.join(' • '))
                    else
                      const Text('Sin datos de contacto'),
                    if (_hasValue(client.notes)) ...[
                      const SizedBox(height: 8),
                      Text(client.notes!.trim()),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Proyectos',
                trailing: TextButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.proyectoForm,
                    extra: ProyectoFormArgs(clientId: clientId),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo'),
                ),
                child: projectsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stackTrace) => Text('Error: $error'),
                  data: (projects) {
                    if (projects.isEmpty) {
                      return const Text(
                        'Este cliente todavía no tiene proyectos.',
                      );
                    }

                    return Column(
                      children: projects
                          .map(
                            (project) => _ProjectTile(project: project),
                          )
                          .toList(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
      child: ListTile(
        title: Text(project.name),
        subtitle: Text(ProjectStatus.label(project.status)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(
          AppRoutes.proyectoDetalle,
          extra: project.id,
        ),
      ),
    );
  }
}
