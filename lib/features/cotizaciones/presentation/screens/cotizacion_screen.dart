import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/components/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../application/quotation_draft_controller.dart';
import '../../domain/entities/quotation_draft_prospect.dart';

class CotizacionScreen extends ConsumerWidget {
  const CotizacionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prospect = ref.watch(quotationDraftProspectProvider);
    final hasProspect = prospect != null;

    return AppScaffold(
      title: 'Cotización',
      child: ListView(
        children: [
          SectionCard(
            title: 'Cotización provisional',
            subtitle:
                'Primero se identifica el prospecto, después se captura el recibo CFE, '
                'se analiza el consumo y se genera una propuesta. El expediente formal '
                'se crea cuando el cliente acepta.',
            trailing: _StatusChip(
              label: hasProspect ? 'En proceso' : 'Pendiente',
            ),
            child: Column(
              children: [
                if (prospect != null) ...[
                  _ProspectSummaryCard(prospect: prospect),
                  const SizedBox(height: 12),
                ],
                _FlowStepCard(
                  stepNumber: 1,
                  title: 'Datos mínimos del prospecto',
                  description: hasProspect
                      ? 'Prospecto capturado. Puedes editarlo antes de continuar.'
                      : 'Captura nombre, teléfono, WhatsApp, correo, dirección y notas.',
                  icon: Icons.person_add_alt_1_outlined,
                  status: hasProspect ? 'Capturado' : 'Disponible',
                  onTap: () => context.push(AppRoutes.cotizacionProspectoForm),
                ),
                const SizedBox(height: 12),
                _FlowStepCard(
                  stepNumber: 2,
                  title: 'Recibo CFE',
                  description:
                      'Tomar foto o adjuntar PDF del recibo para obtener datos base como RPU, servicio y consumo.',
                  icon: Icons.receipt_long_outlined,
                  status: hasProspect ? 'Disponible' : 'Primero prospecto',
                  onTap: hasProspect
                      ? () => context.push(AppRoutes.reciboCfe)
                      : null,
                ),
                const SizedBox(height: 12),
                _FlowStepCard(
                  stepNumber: 3,
                  title: 'Revisión del recibo',
                  description:
                      'Validar manualmente la información detectada antes de usarla para cálculos.',
                  icon: Icons.fact_check_outlined,
                  status: hasProspect ? 'Disponible' : 'Bloqueado',
                  onTap: hasProspect
                      ? () => context.push(AppRoutes.reciboCfeRevision)
                      : null,
                ),
                const SizedBox(height: 12),
                _FlowStepCard(
                  stepNumber: 4,
                  title: 'Análisis energético',
                  description:
                      'Calcular consumo, generación estimada y base para dimensionar el sistema.',
                  icon: Icons.analytics_outlined,
                  status: hasProspect ? 'Disponible' : 'Bloqueado',
                  onTap: hasProspect
                      ? () => context.push(AppRoutes.analisisConsumo)
                      : null,
                ),
                const SizedBox(height: 12),
                _FlowStepCard(
                  stepNumber: 5,
                  title: 'Cotización interna',
                  description:
                      'Ajustar paneles, inversor, precios, utilidad, IVA, descuentos y forma de pago.',
                  icon: Icons.calculate_outlined,
                  status: hasProspect ? 'Disponible' : 'Bloqueado',
                  onTap: hasProspect
                      ? () => context.push(AppRoutes.cotizacionInterna)
                      : null,
                ),
                const SizedBox(height: 12),
                _FlowStepCard(
                  stepNumber: 6,
                  title: 'PDF para cliente',
                  description:
                      'Generar la vista de cotización que se compartirá con el cliente.',
                  icon: Icons.picture_as_pdf_outlined,
                  status: hasProspect ? 'Disponible' : 'Bloqueado',
                  onTap: hasProspect
                      ? () => context.push(AppRoutes.cotizacionClientePreview)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Estado comercial',
            subtitle:
                'Cuando el cliente acepte la cotización, se convertirá en cliente formal, proyecto y expediente.',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.hourglass_top_outlined,
                  text: 'Estado inicial: pendiente de aprobación.',
                ),
                SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.folder_copy_outlined,
                  text:
                      'El expediente definitivo se creará después de aceptar la cotización.',
                ),
                SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.verified_outlined,
                  text:
                      'La información del recibo se debe revisar manualmente antes de calcular.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        color: theme.colorScheme.primaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.20),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onTap != null;

    return Card(
      elevation: 0,
      color: isEnabled
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: isEnabled
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: isEnabled
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                child: Text('$stepNumber'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
                          size: 22,
                          color: isEnabled
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
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
              Icon(
                isEnabled ? Icons.chevron_right : Icons.lock_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 22,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
