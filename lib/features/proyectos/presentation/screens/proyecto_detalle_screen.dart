import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../clientes/application/clients_controller.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../../cotizaciones/data/quotation_draft_repository.dart';
import '../../../cotizaciones/domain/entities/quotation_draft.dart';
import '../../application/projects_controller.dart';
import '../../domain/entities/project.dart';
import 'proyecto_form_screen.dart';

class ProyectoDetalleScreen extends ConsumerWidget {
  const ProyectoDetalleScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectByIdProvider(projectId));

    return AppScaffold(
      title: 'Detalle de proyecto',
      actions: [
        IconButton(
          tooltip: 'Editar proyecto',
          onPressed: () => context.push(
            AppRoutes.proyectoForm,
            extra: ProyectoFormArgs(projectId: projectId),
          ),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
      child: projectAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          title: 'No se pudo cargar el proyecto',
          message: error.toString(),
          icon: Icons.error_outline,
        ),
        data: (project) {
          if (project == null) {
            return const EmptyState(
              title: 'Proyecto no encontrado',
              message: 'Puede que haya sido eliminado.',
              icon: Icons.home_work_outlined,
            );
          }

          return _ProjectDetail(project: project);
        },
      ),
    );
  }
}

class _ProjectDetail extends ConsumerWidget {
  const _ProjectDetail({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientByIdProvider(project.clientId));
    final historyAsync = ref.watch(projectStatusHistoryProvider(project.id));
    final draftsAsync = ref.watch(quotationDraftsByProjectProvider(project.id));

    return ListView(
      children: [
        SectionCard(
          title: project.name,
          trailing: Chip(
            visualDensity: VisualDensity.compact,
            label: Text(ProjectStatus.label(project.status)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              clientAsync.when(
                loading: () => const Text('Cargando cliente...'),
                error: (error, stackTrace) => Text('Cliente: $error'),
                data: (client) => Text(
                  'Cliente: ${client?.fullName ?? 'No encontrado'}',
                ),
              ),
              if (project.installationType != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Tipo: ${InstallationType.label(project.installationType!)}',
                ),
              ],
              if (_hasValue(project.serviceAddress)) ...[
                const SizedBox(height: 4),
                Text('Dirección: ${project.serviceAddress!.trim()}'),
              ],
              if (_hasValue(project.state) || _hasValue(project.municipality)) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (_hasValue(project.municipality))
                      project.municipality!.trim(),
                    if (_hasValue(project.state)) project.state!.trim(),
                  ].join(', '),
                ),
              ],
              if (_hasValue(project.notes)) ...[
                const SizedBox(height: 8),
                Text(project.notes!.trim()),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showChangeStatusDialog(context, ref),
                icon: const Icon(Icons.swap_horiz_outlined),
                label: const Text('Cambiar estado'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Historial de estados',
          child: historyAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) => Text('Error: $error'),
            data: (history) {
              if (history.isEmpty) {
                return const Text('Sin cambios de estado registrados.');
              }

              return Column(
                children: history
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.circle, size: 8),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${entry.previousStatus != null ? '${ProjectStatus.label(entry.previousStatus!)} → ' : ''}'
                                    '${ProjectStatus.label(entry.newStatus)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _formatDate(entry.createdAt),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (entry.notes != null)
                                    Text(
                                      entry.notes!,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Cotizaciones',
          trailing: TextButton.icon(
            onPressed: () => _createDraftForProject(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Nueva'),
          ),
          child: draftsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) => Text('Error: $error'),
            data: (drafts) {
              if (drafts.isEmpty) {
                return const Text(
                  'Este proyecto todavía no tiene cotizaciones.',
                );
              }

              return Column(
                children: drafts
                    .map(
                      (draft) => _DraftTile(
                        draft: draft,
                        onTap: () => _openDraft(context, ref, draft),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _showChangeStatusDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var selectedStatus = project.status;
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cambiar estado del proyecto'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    items: [
                      for (final status in ProjectStatus.values)
                        DropdownMenuItem(
                          value: status,
                          child: Text(ProjectStatus.label(status)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ref.read(projectRepositoryProvider).changeStatus(
            projectId: project.id,
            newStatus: selectedStatus,
            notes: notesController.text,
          );

      ref.invalidate(projectByIdProvider(project.id));
      ref.invalidate(projectStatusHistoryProvider(project.id));
      ref.invalidate(projectsControllerProvider);
      ref.invalidate(projectsByClientProvider(project.clientId));
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el estado: $error')),
      );
    }
  }

  Future<void> _createDraftForProject(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final client = await ref.read(clientByIdProvider(project.clientId).future);

      final draftId =
          await ref.read(quotationDraftRepositoryProvider).create(
                CreateQuotationDraftInput(
                  prospectName: client?.fullName ?? project.name,
                  phone: client?.phone,
                  email: client?.email,
                  address: client?.address ?? project.serviceAddress,
                  projectId: project.id,
                ),
              );

      ref.invalidate(quotationDraftsByProjectProvider(project.id));
      ref.invalidate(quotationDraftsControllerProvider);
      ref.read(activeQuotationDraftIdProvider.notifier).state = draftId;

      if (!context.mounted) return;

      context.push(AppRoutes.reciboCfe);
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la cotización: $error')),
      );
    }
  }

  void _openDraft(BuildContext context, WidgetRef ref, QuotationDraft draft) {
    ref.read(activeQuotationDraftIdProvider.notifier).state = draft.id;
    context.push(_nextRouteForDraft(draft));
  }

  String _nextRouteForDraft(QuotationDraft draft) {
    if (!draft.hasCfeReceipt ||
        draft.status == QuotationDraftStatus.receiptPending) {
      return AppRoutes.reciboCfe;
    }

    if (!draft.hasCompleteCfeReview) {
      return AppRoutes.reciboCfeRevision;
    }

    switch (draft.status) {
      case QuotationDraftStatus.quotationInProgress:
        return AppRoutes.cotizacionInterna;
      case QuotationDraftStatus.quotationSent:
      case QuotationDraftStatus.accepted:
        return AppRoutes.cotizacionClientePreview;
      case QuotationDraftStatus.cancelled:
        return AppRoutes.cotizacion;
      case QuotationDraftStatus.inAnalysis:
      case QuotationDraftStatus.receiptReceived:
      default:
        return AppRoutes.analisisConsumo;
    }
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({required this.draft, required this.onTap});

  final QuotationDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
      child: ListTile(
        title: Text(draft.prospectName),
        subtitle: Text(_statusLabel(draft.status)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case QuotationDraftStatus.receiptPending:
        return 'Recibo pendiente';
      case QuotationDraftStatus.receiptReceived:
        return 'Recibo recibido';
      case QuotationDraftStatus.inAnalysis:
        return 'En análisis';
      case QuotationDraftStatus.quotationInProgress:
        return 'Cotización en proceso';
      case QuotationDraftStatus.quotationSent:
        return 'Cotización enviada';
      case QuotationDraftStatus.accepted:
        return 'Aceptada';
      case QuotationDraftStatus.cancelled:
        return 'Cancelada';
      default:
        return 'Pendiente';
    }
  }
}
