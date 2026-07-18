import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/address_autocomplete_field.dart';
import '../../../../shared/widgets/document_preview.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../analisis_energetico/application/energy_analysis_controller.dart';
import '../../../analisis_energetico/domain/entities/quotation_draft_consumption.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../../cotizaciones/data/quotation_draft_repository.dart';
import '../../../cotizaciones/domain/entities/quotation_draft.dart';
import '../../../expediente/data/documents_repository.dart';
import '../../application/ocr_service.dart';
import '../../domain/cfe_receipt_text_parser.dart';

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
  final _tariffController = TextEditingController();
  final _billingPeriodController = TextEditingController();
  final _currentPeriodKwhController = TextEditingController();
  final _totalToPayController = TextEditingController();

  bool _isSaving = false;
  bool _isEditing = true;
  bool _usedOcrSuggestion = false;
  bool _isRunningManualOcr = false;
  String? _prefilledDraftId;

  @override
  void dispose() {
    _holderNameController.dispose();
    _serviceAddressController.dispose();
    _rpuController.dispose();
    _tariffController.dispose();
    _billingPeriodController.dispose();
    _currentPeriodKwhController.dispose();
    _totalToPayController.dispose();
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

          final hasSavedReview = draft.hasCompleteCfeReview;
          final fieldsEnabled = _isEditing && !_isSaving;

          return ListView(
            children: [
              SectionCard(
                title: 'Prospecto activo',
                subtitle:
                    'La revisión se guardará dentro de este borrador de cotización.',
                child: _DraftSummary(draft: draft),
              ),
              const SizedBox(height: 16),
              if (draft.cfeReceiptDocumentId != null)
                SectionCard(
                  title: 'Recibo CFE adjunto',
                  subtitle: 'Vista previa del archivo guardado.',
                  child: _ReceiptDocumentPreview(
                    documentId: draft.cfeReceiptDocumentId!,
                  ),
                ),
              if (draft.cfeReceiptDocumentId != null)
                const SizedBox(height: 16),
              SectionCard(
                title: 'Datos del recibo CFE',
                subtitle: hasSavedReview && !_isEditing
                    ? 'Estos datos ya fueron guardados. Para modificarlos, primero activa la edición.'
                    : 'Captura o corrige los datos principales del recibo.',
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_isEditing) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isRunningManualOcr
                                ? null
                                : () => _runManualOcr(draft),
                            icon: _isRunningManualOcr
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_outlined),
                            label: Text(
                              _isRunningManualOcr
                                  ? 'Obteniendo información...'
                                  : 'Obtener información',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_usedOcrSuggestion && _isEditing) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.auto_awesome_outlined),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Algunos campos se rellenaron automáticamente '
                                  'con datos detectados del recibo. Verifica '
                                  'cada uno antes de guardar.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (hasSavedReview) ...[
                        _SavedReviewNotice(
                          isEditing: _isEditing,
                          onEdit: () {
                            setState(() {
                              _isEditing = true;
                            });
                          },
                          onContinue: () {
                            unawaited(
                              ref
                                  .read(quotationDraftRepositoryProvider)
                                  .updateLastCompletedStep(
                                    draftId: activeDraftId,
                                    step: QuotationDraftStep.cfeReview,
                                  ),
                            );
                            context.push(AppRoutes.analisisConsumo);
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        enabled: fieldsEnabled,
                        controller: _holderNameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Titular del servicio CFE',
                          helperText:
                              'Puede ser diferente al prospecto o cliente.',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) => _requiredTextValidator(
                          value,
                          'Captura el titular del servicio CFE.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      AddressAutocompleteField(
                        controller: _serviceAddressController,
                        enabled: fieldsEnabled,
                        labelText: 'Dirección del servicio',
                        helperText:
                            'Dirección donde está contratado el servicio eléctrico. '
                            'Se sugiere la del prospecto/cliente; ajústala si el '
                            'titular del recibo CFE vive en otro domicilio.',
                        validator: (value) => _requiredTextValidator(
                          value,
                          'Captura la dirección del servicio.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        enabled: fieldsEnabled,
                        controller: _rpuController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'RMU / RPU / Número de servicio CFE',
                          helperText:
                              'Identificador del servicio eléctrico que aparece en el recibo CFE.',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                        ),
                        validator: (value) => _requiredTextValidator(
                          value,
                          'Captura el RMU, RPU o número de servicio del recibo.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        enabled: fieldsEnabled,
                        controller: _tariffController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Tarifa CFE',
                          helperText: 'Ejemplo: 1, 1A, 1B, DAC, GDMTO, PDBT.',
                          prefixIcon: Icon(Icons.bolt_outlined),
                        ),
                        validator: (value) => _requiredTextValidator(
                          value,
                          'Captura la tarifa del recibo CFE.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        enabled: fieldsEnabled,
                        controller: _billingPeriodController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Periodo facturado',
                          helperText:
                              'Ejemplo: 13 MAR 25 - 14 MAY 25 o Mayo 2025.',
                          prefixIcon: Icon(Icons.date_range_outlined),
                        ),
                        validator: (value) => _requiredTextValidator(
                          value,
                          'Captura el periodo facturado.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        enabled: fieldsEnabled,
                        controller: _currentPeriodKwhController,
                        textInputAction: TextInputAction.next,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Consumo del periodo',
                          helperText:
                              'Captura el consumo en kWh que aparece en el recibo.',
                          suffixText: 'kWh',
                          prefixIcon: Icon(Icons.electric_meter_outlined),
                        ),
                        validator: (value) => _requiredNumberValidator(
                          value,
                          emptyMessage:
                              'Captura el consumo del periodo en kWh.',
                          invalidMessage:
                              'Captura un consumo válido. Ejemplo: 385',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        enabled: fieldsEnabled,
                        controller: _totalToPayController,
                        textInputAction: TextInputAction.done,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Total pagado',
                          helperText:
                              'Captura el importe total del recibo CFE.',
                          prefixText: '\$ ',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: (value) => _requiredNumberValidator(
                          value,
                          emptyMessage: 'Captura el total pagado.',
                          invalidMessage:
                              'Captura un total válido. Ejemplo: 1250.50',
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_isEditing)
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
                                  : hasSavedReview
                                      ? 'Guardar cambios y continuar'
                                      : 'Guardar y continuar',
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Editar datos CFE'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  unawaited(
                                    ref
                                        .read(quotationDraftRepositoryProvider)
                                        .updateLastCompletedStep(
                                          draftId: activeDraftId,
                                          step: QuotationDraftStep.cfeReview,
                                        ),
                                  );
                                  context.push(AppRoutes.analisisConsumo);
                                },
                                icon: const Icon(Icons.arrow_forward_outlined),
                                label: const Text(
                                  'Continuar a análisis energético',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
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
    _tariffController.text = draft.cfeTariff ?? '';
    _billingPeriodController.text = draft.cfeBillingPeriod ?? '';
    _currentPeriodKwhController.text =
        _formatNullableNumber(draft.cfeCurrentPeriodKwh);
    _totalToPayController.text = _formatNullableNumber(draft.cfeTotalToPay);

    // Si todavía no hay una revisión guardada, usa la sugerencia de OCR
    // (si existe) solo para rellenar los campos que sigan vacíos. El
    // usuario siempre debe revisar y guardar manualmente.
    if (!draft.hasCompleteCfeReview) {
      final suggestion = ref.read(cfeOcrSuggestionProvider);

      if (suggestion != null) {
        _applySuggestionToEmptyFields(suggestion);
        _usedOcrSuggestion = true;
      }

      // La dirección del prospecto/cliente es la fuente de verdad por
      // defecto; el titular del recibo CFE puede ser distinto (ver doc
      // funcional §9.2), así que solo se usa como sugerencia editable.
      if (_serviceAddressController.text.isEmpty && draft.hasAddress) {
        _serviceAddressController.text = draft.address!.trim();
      }
    }

    _isEditing = !draft.hasCompleteCfeReview;
    _prefilledDraftId = draft.id;
  }

  /// Rellena solo los campos vacíos del formulario con la sugerencia de
  /// OCR — compartido entre el prefill automático al entrar y el botón
  /// manual "Obtener información".
  void _applySuggestionToEmptyFields(CfeReceiptOcrSuggestion suggestion) {
    if (_holderNameController.text.isEmpty && suggestion.holderName != null) {
      _holderNameController.text = suggestion.holderName!;
    }
    if (_serviceAddressController.text.isEmpty &&
        suggestion.serviceAddress != null) {
      _serviceAddressController.text = suggestion.serviceAddress!;
    }
    if (_rpuController.text.isEmpty && suggestion.rpu != null) {
      _rpuController.text = suggestion.rpu!;
    }
    if (_tariffController.text.isEmpty && suggestion.tariff != null) {
      _tariffController.text = suggestion.tariff!;
    }
    if (_billingPeriodController.text.isEmpty &&
        suggestion.billingPeriod != null) {
      _billingPeriodController.text = suggestion.billingPeriod!;
    }
    if (_currentPeriodKwhController.text.isEmpty &&
        suggestion.currentPeriodKwh != null) {
      _currentPeriodKwhController.text =
          _formatNullableNumber(suggestion.currentPeriodKwh);
    }
    if (_totalToPayController.text.isEmpty && suggestion.totalToPay != null) {
      _totalToPayController.text =
          _formatNullableNumber(suggestion.totalToPay);
    }
  }

  Future<void> _runManualOcr(QuotationDraft draft) async {
    final documentId = draft.cfeReceiptDocumentId;
    if (documentId == null) return;

    setState(() {
      _isRunningManualOcr = true;
    });

    try {
      final document = await ref.read(documentByIdProvider(documentId).future);

      if (document == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El recibo adjunto ya no está disponible.'),
          ),
        );
        return;
      }

      final suggestion = await ref
          .read(ocrServiceProvider)
          .extractCfeReceiptSuggestion(document.localPath);

      if (!mounted) return;

      if (suggestion == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se detectó información nueva en el recibo.'),
          ),
        );
        return;
      }

      ref.read(cfeOcrSuggestionProvider.notifier).state = suggestion;

      setState(() {
        _applySuggestionToEmptyFields(suggestion);
        _usedOcrSuggestion = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Datos detectados. Verifica cada campo antes de guardar.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo obtener información del recibo: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRunningManualOcr = false;
        });
      }
    }
  }

  Future<void> _saveReview(String activeDraftId) async {
    if (!_formKey.currentState!.validate()) return;

    final currentPeriodKwh = _parseFlexibleDouble(
      _currentPeriodKwhController.text,
    );
    final totalToPay = _parseFlexibleDouble(_totalToPayController.text);

    if (currentPeriodKwh == null || totalToPay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa los importes capturados antes de continuar.'),
        ),
      );
      return;
    }

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
              tariff: _tariffController.text,
              billingPeriod: _billingPeriodController.text,
              currentPeriodKwh: currentPeriodKwh,
              totalToPay: totalToPay,
            ),
          );

      await ref.read(quotationDraftRepositoryProvider).updateLastCompletedStep(
            draftId: activeDraftId,
            step: QuotationDraftStep.cfeReview,
          );

      final ocrSuggestion = ref.read(cfeOcrSuggestionProvider);
      if (ocrSuggestion != null && ocrSuggestion.historicalPeriods.isNotEmpty) {
        await _seedHistoricalConsumptionsIfEmpty(
          activeDraftId,
          ocrSuggestion,
          currentPeriodKwh: currentPeriodKwh,
        );
      }

      ref.invalidate(quotationDraftsControllerProvider);
      ref.read(cfeOcrSuggestionProvider.notifier).state = null;

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

  /// Precarga hasta 6 periodos de consumo reales (el actual + los más
  /// recientes de la tabla "Consumo histórico" del recibo) en el análisis
  /// energético, para que el instalador no tenga que teclearlos a mano.
  ///
  /// Solo se hace si el borrador todavía no tiene consumos guardados: no se
  /// pisa lo que el instalador ya haya capturado o ajustado a mano (incluido
  /// el botón "Replicar", que sigue disponible sin cambios en esa pantalla).
  Future<void> _seedHistoricalConsumptionsIfEmpty(
    String draftId,
    CfeReceiptOcrSuggestion suggestion, {
    required double currentPeriodKwh,
  }) async {
    try {
      final repository = ref.read(energyAnalysisRepositoryProvider);
      final existing = await repository.getDraftConsumptions(draftId);
      if (existing.isNotEmpty) return;

      final billingPeriod = _billingPeriodController.text.trim();
      final consumptions = <SaveQuotationDraftConsumptionInput>[
        SaveQuotationDraftConsumptionInput(
          periodLabel: billingPeriod.isEmpty ? 'Periodo actual' : billingPeriod,
          kwh: currentPeriodKwh,
          sortOrder: 0,
        ),
      ];

      const remainingSlots = 5;
      for (var i = 0;
          i < suggestion.historicalPeriods.length && i < remainingSlots;
          i++) {
        final period = suggestion.historicalPeriods[i];
        consumptions.add(
          SaveQuotationDraftConsumptionInput(
            periodLabel: period.periodLabel,
            kwh: period.kwh,
            sortOrder: i + 1,
          ),
        );
      }

      await repository.replaceDraftConsumptions(
        quotationDraftId: draftId,
        consumptions: consumptions,
      );

      ref.invalidate(quotationDraftConsumptionsProvider(draftId));
    } catch (_) {
      // Es una ayuda opcional: si falla, el instalador sigue capturando los
      // consumos a mano en la pantalla de análisis energético.
    }
  }

  String? _requiredTextValidator(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }

    return null;
  }

  String? _requiredNumberValidator(
    String? value, {
    required String emptyMessage,
    required String invalidMessage,
  }) {
    if (value == null || value.trim().isEmpty) {
      return emptyMessage;
    }

    final parsedValue = _parseFlexibleDouble(value);

    if (parsedValue == null || parsedValue <= 0) {
      return invalidMessage;
    }

    return null;
  }

  double? _parseFlexibleDouble(String value) {
    var cleanValue = value.trim();

    if (cleanValue.isEmpty) return null;

    cleanValue = cleanValue.replaceAll(RegExp(r'[\$\s]'), '');

    if (cleanValue.contains(',') && cleanValue.contains('.')) {
      cleanValue = cleanValue.replaceAll(',', '');
    } else if (cleanValue.contains(',')) {
      final parts = cleanValue.split(',');

      if (parts.length == 2 &&
          parts.first.isNotEmpty &&
          parts.first.length <= 3 &&
          parts.last.length == 3) {
        cleanValue = '${parts.first}${parts.last}';
      } else {
        cleanValue = cleanValue.replaceAll(',', '.');
      }
    }

    return double.tryParse(cleanValue);
  }

  String _formatNullableNumber(double? value) {
    if (value == null) return '';

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

class _ReceiptDocumentPreview extends ConsumerWidget {
  const _ReceiptDocumentPreview({required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentAsync = ref.watch(documentByIdProvider(documentId));

    return documentAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Text('No se pudo cargar el recibo: $error'),
      data: (document) {
        if (document == null) {
          return const Text('El recibo adjunto ya no está disponible.');
        }

        return DocumentPreview(
          localPath: document.localPath,
          mimeType: document.mimeType,
        );
      },
    );
  }
}

class _SavedReviewNotice extends StatelessWidget {
  const _SavedReviewNotice({
    required this.isEditing,
    required this.onEdit,
    required this.onContinue,
  });

  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEditing
            ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.45)
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditing
              ? theme.colorScheme.tertiary.withValues(alpha: 0.25)
              : theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isEditing ? Icons.edit_note_outlined : Icons.lock_outline,
            color: isEditing
                ? theme.colorScheme.tertiary
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing
                  ? 'Modo edición activo. Revisa los cambios antes de guardar.'
                  : 'Revisión CFE guardada. Los datos están bloqueados para evitar cambios accidentales.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
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
