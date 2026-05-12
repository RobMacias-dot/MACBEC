import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/components/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../../cotizaciones/data/quotation_draft_repository.dart';
import '../../../cotizaciones/domain/entities/quotation_draft.dart';

class ReciboCfeRevisionScreen extends ConsumerStatefulWidget {
  const ReciboCfeRevisionScreen({super.key});

  @override
  ConsumerState<ReciboCfeRevisionScreen> createState() =>
      _ReciboCfeRevisionScreenState();
}

class _ReciboCfeRevisionScreenState
    extends ConsumerState<ReciboCfeRevisionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _holderNameController = TextEditingController();
  final _serviceAddressController = TextEditingController();
  final _rpuController = TextEditingController();

  bool _isSaving = false;
  String? _prefilledDraftId;

  @override
  void dispose() {
    _holderNameController.dispose();
    _serviceAddressController.dispose();
    _rpuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeDraftId = ref.watch(activeQuotationDraftIdProvider);

    if (activeDraftId == null) {
      return const AppScaffold(
        title: 'Revisión CFE',
        child: EmptyState(
          title: 'No hay cotización activa',
          message:
              'Primero crea o selecciona un prospecto y agrega su recibo CFE.',
          icon: Icons.fact_check_outlined,
        ),
      );
    }

    final draftsAsync = ref.watch(quotationDraftsControllerProvider);

    return AppScaffold(
      title: 'Revisión CFE',
      child: draftsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => EmptyState(
          title: 'No se pudo cargar la revisión',
          message: error.toString(),
          icon: Icons.error_outline,
        ),
        data: (drafts) {
          final draft = _findActiveDraft(drafts, activeDraftId);

          if (draft == null) {
            return const EmptyState(
              title: 'Borrador no encontrado',
              message:
                  'Regresa a Cotización y selecciona nuevamente el prospecto activo.',
              icon: Icons.search_off_outlined,
            );
          }

          if (!draft.hasCfeReceipt || draft.cfeReceiptDocumentId == null) {
            return const EmptyState(
              title: 'Recibo CFE pendiente',
              message:
                  'Primero agrega una foto o PDF del recibo CFE antes de capturar la revisión.',
              icon: Icons.receipt_long_outlined,
            );
          }

          _prefillFormIfNeeded(draft);

          return ListView(
            children: [
              SectionCard(
                title: 'Prospecto activo',
                subtitle:
                    'La revisión se guardará dentro de este borrador de cotización.',
                child: _DraftSummary(draft: draft),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Datos del recibo CFE',
                subtitle:
                    'Captura manualmente los datos principales. En esta fase todavía no usamos OCR.',
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _holderNameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Titular del servicio CFE',
                          helperText:
                              'Puede ser diferente al prospecto o cliente.',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Captura el titular del servicio CFE.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _serviceAddressController,
                        textInputAction: TextInputAction.next,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Dirección del servicio',
                          helperText:
                              'Dirección donde está contratado el servicio eléctrico.',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Captura la dirección del servicio.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _rpuController,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'RMU / RPU / Número de servicio CFE',
                          helperText:
                              'Identificador del servicio eléctrico que aparece en el recibo CFE.',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Captura el RMU, RPU o número de servicio del recibo.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () => _saveReview(activeDraftId),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving
                                ? 'Guardando...'
                                : 'Guardar y continuar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SectionCard(
                title: 'Siguiente paso',
                subtitle:
                    'Después de guardar estos datos, continuaremos al análisis energético.',
                child: _InfoRow(
                  icon: Icons.analytics_outlined,
                  text:
                      'En la siguiente fase capturaremos consumos, periodo, tarifa y total pagado para alimentar el análisis.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  QuotationDraft? _findActiveDraft(
    List<QuotationDraft> drafts,
    String activeDraftId,
  ) {
    for (final draft in drafts) {
      if (draft.id == activeDraftId) {
        return draft;
      }
    }

    return null;
  }

  void _prefillFormIfNeeded(QuotationDraft draft) {
    if (_prefilledDraftId == draft.id) return;

    _holderNameController.text = draft.cfeHolderName ?? '';
    _serviceAddressController.text = draft.cfeServiceAddress ?? '';
    _rpuController.text = draft.rpu ?? '';

    _prefilledDraftId = draft.id;
  }

  Future<void> _saveReview(String activeDraftId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(quotationDraftRepositoryProvider).updateCfeReceiptReview(
            UpdateCfeReceiptReviewInput(
              draftId: activeDraftId,
              holderName: _holderNameController.text,
              serviceAddress: _serviceAddressController.text,
              rpu: _rpuController.text,
            ),
          );

      ref.invalidate(quotationDraftsControllerProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisión CFE guardada correctamente.'),
        ),
      );

      context.push(AppRoutes.analisisConsumo);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar la revisión CFE: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _DraftSummary extends StatelessWidget {
  const _DraftSummary({required this.draft});

  final QuotationDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final details = <String>[
      if (draft.hasPhone) draft.phone!.trim(),
      if (draft.hasWhatsapp) 'WhatsApp: ${draft.whatsapp!.trim()}',
      if (draft.hasEmail) draft.email!.trim(),
      if (draft.hasAddress) draft.address!.trim(),
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
                  draft.prospectName,
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
                const SizedBox(height: 8),
                const Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(Icons.receipt_long_outlined),
                  label: Text('Recibo CFE recibido'),
                ),
              ],
            ),
          ),
        ],
      ),
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
