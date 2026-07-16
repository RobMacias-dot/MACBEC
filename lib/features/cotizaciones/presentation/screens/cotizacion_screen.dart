import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../application/quotation_draft_controller.dart';
import '../../application/quotation_draft_navigation.dart';
import '../../domain/entities/quotation_draft.dart';
import '../../domain/entities/quotation_draft_prospect.dart';

/// Resumen del borrador activo: pasos y su progreso. Ya no lista otros
/// borradores pendientes (esa vista vive ahora en Clientes, ver pestañas
/// "Pendiente"/"Completa") ni depende de un candado binario por
/// `hasProspect` — cada tarjeta siempre se puede tocar y su estado
/// (Completado/Actual/Próximo) refleja `lastCompletedStep`.
class CotizacionScreen extends ConsumerWidget {
  const CotizacionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prospect = ref.watch(quotationDraftProspectProvider);
    final activeDraftId = ref.watch(activeQuotationDraftIdProvider);

    if (prospect == null || activeDraftId == null) {
      return AppScaffold(
        title: 'Cotización',
        child: _EmptyStateWithButton(
          title: 'No hay cotización activa',
          message:
              'Ve a Clientes y continúa una cotización pendiente, o crea un cliente nuevo desde el dashboard.',
          icon: Icons.request_quote_outlined,
          buttonLabel: 'Ir a Clientes',
          onPressed: () => context.go(AppRoutes.clientes),
        ),
      );
    }

    final draftsAsync = ref.watch(quotationDraftsControllerProvider);

    return AppScaffold(
      title: 'Cotización',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => ref.invalidate(quotationDraftsControllerProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: draftsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          title: 'No se pudo cargar la cotización',
          message: error.toString(),
          icon: Icons.error_outline,
        ),
        data: (drafts) {
          final draft = _findDraft(drafts, activeDraftId);
          final currentRank = quotationDraftStepRank(draft?.lastCompletedStep);

          return ListView(
            children: [
              SectionCard(
                title: 'Cotización en curso',
                trailing: _StatusChip(
                  label: draft != null && isQuotationDraftComplete(draft)
                      ? 'Completa'
                      : 'En proceso',
                ),
                child: Column(
                  children: [
                    _ProspectSummaryCard(prospect: prospect),
                    const SizedBox(height: 12),
                    _FlowStepCard(
                      stepNumber: 1,
                      title: 'Datos mínimos del prospecto',
                      description:
                          'Nombre, teléfono, WhatsApp, correo, dirección y notas.',
                      icon: Icons.person_add_alt_1_outlined,
                      status: _stepStatus(
                        currentRank,
                        QuotationDraftStep.prospect,
                      ),
                      onTap: () =>
                          context.push(AppRoutes.cotizacionProspectoForm),
                    ),
                    const SizedBox(height: 12),
                    _FlowStepCard(
                      stepNumber: 2,
                      title: 'Recibo CFE',
                      description:
                          'Tomar foto, elegir desde galería o adjuntar PDF del recibo.',
                      icon: Icons.receipt_long_outlined,
                      status: _stepStatus(
                        currentRank,
                        QuotationDraftStep.cfeReceipt,
                      ),
                      onTap: () => context.push(AppRoutes.reciboCfe),
                    ),
                    const SizedBox(height: 12),
                    _FlowStepCard(
                      stepNumber: 3,
                      title: 'Revisión del recibo',
                      description:
                          'Validar manualmente la información detectada antes de usarla para cálculos.',
                      icon: Icons.fact_check_outlined,
                      status: _stepStatus(
                        currentRank,
                        QuotationDraftStep.cfeReview,
                      ),
                      onTap: () => context.push(AppRoutes.reciboCfeRevision),
                    ),
                    const SizedBox(height: 12),
                    _FlowStepCard(
                      stepNumber: 4,
                      title: 'Análisis energético',
                      description:
                          'Calcular consumo, generación estimada y base para dimensionar el sistema.',
                      icon: Icons.analytics_outlined,
                      status: _stepStatus(
                        currentRank,
                        QuotationDraftStep.energyAnalysis,
                      ),
                      onTap: () => context.push(AppRoutes.analisisConsumo),
                    ),
                    const SizedBox(height: 12),
                    _FlowStepCard(
                      stepNumber: 5,
                      title: 'Cotización interna',
                      description:
                          'Ajustar paneles, inversor, precios, utilidad, IVA, descuentos y forma de pago.',
                      icon: Icons.calculate_outlined,
                      status: _stepStatus(
                        currentRank,
                        QuotationDraftStep.commercialQuote,
                      ),
                      onTap: () => context.push(AppRoutes.cotizacionInterna),
                    ),
                    const SizedBox(height: 12),
                    _FlowStepCard(
                      stepNumber: 6,
                      title: 'PDF para cliente',
                      description:
                          'Generar la vista de cotización que se compartirá con el cliente.',
                      icon: Icons.picture_as_pdf_outlined,
                      status: _stepStatus(
                        currentRank,
                        QuotationDraftStep.clientPreview,
                      ),
                      onTap: () =>
                          context.push(AppRoutes.cotizacionClientePreview),
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

  QuotationDraft? _findDraft(List<QuotationDraft> drafts, String draftId) {
    for (final draft in drafts) {
      if (draft.id == draftId) return draft;
    }
    return null;
  }

  /// Estado amigable de un paso del hub en relación al progreso real del
  /// borrador (`currentRank`, ver [quotationDraftStepRank]). Ya no bloquea
  /// el tap: el usuario puede entrar a cualquier paso, la validación de
  /// datos ocurre dentro de cada pantalla.
  String _stepStatus(int currentRank, String targetStep) {
    final targetRank = quotationDraftStepOrder.indexOf(targetStep);
    if (currentRank >= targetRank) return 'Completado';
    if (currentRank == targetRank - 1) return 'Actual';
    return 'Próximo';
  }
}

class _ProspectSummaryCard extends StatelessWidget {
  const _ProspectSummaryCard({required this.prospect});

  final QuotationDraftProspect prospect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final details = <String>[
      if (prospect.hasPhone) prospect.phone!.trim(),
      if (prospect.hasWhatsapp) 'WhatsApp: ${prospect.whatsapp!.trim()}',
      if (prospect.hasEmail) prospect.email!.trim(),
      if (prospect.hasAddress) prospect.address!.trim(),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.person_pin_circle_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prospect.fullName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    details.join(' • '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (prospect.hasNotes) ...[
                  const SizedBox(height: 6),
                  Text(
                    prospect.notes!.trim(),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStepCard extends StatelessWidget {
  const _FlowStepCard({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    required this.onTap,
  });

  final int stepNumber;
  final String title;
  final String description;
  final IconData icon;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = status == 'Completado';

    return Card(
      elevation: 0,
      color: isDone
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
          : theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: isDone
                    ? const Icon(Icons.check)
                    : Text('$stepNumber'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 22, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(status),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        Icons.pending_actions_outlined,
        size: 18,
        color: theme.colorScheme.primary,
      ),
      label: Text(label),
    );
  }
}

class _EmptyStateWithButton extends StatelessWidget {
  const _EmptyStateWithButton({
    required this.title,
    required this.message,
    required this.icon,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final IconData icon;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        EmptyState(title: title, message: message, icon: icon),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_forward),
            label: Text(buttonLabel),
          ),
        ),
      ],
    );
  }
}
