import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../proyectos/application/projects_controller.dart';
import '../../../proyectos/domain/entities/project.dart';

class ExpedienteScreen extends ConsumerWidget {
  const ExpedienteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsControllerProvider);

    return AppScaffold(
      title: 'Expediente',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => ref.invalidate(projectsControllerProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          title: 'No se pudieron cargar los proyectos',
          message: error.toString(),
          icon: Icons.error_outline,
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return const EmptyState(
              title: 'Sin proyectos todavía',
              message:
                  'Cuando crees un proyecto, su expediente aparecerá aquí.',
              icon: Icons.folder_outlined,
            );
          }

          return ListView.separated(
            itemCount: projects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final project = projects[index];

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(project.name),
                  subtitle: Text(ProjectStatus.label(project.status)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    AppRoutes.expedienteProyecto,
                    extra: project.id,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
