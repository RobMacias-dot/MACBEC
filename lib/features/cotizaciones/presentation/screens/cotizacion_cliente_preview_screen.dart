import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/files/file_storage_service.dart';
import '../../../../shared/formatters/currency_formatter.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../documentos_pdf/data/pdf_service.dart';
import '../../../documentos_pdf/domain/entities/quotation_pdf_data.dart';
import '../../../documentos_pdf/domain/entities/structure_technical_pdf_data.dart';
import '../../../estructura/domain/structure_design_rules.dart';
import '../../application/quotation_draft_controller.dart';
import '../../application/quotation_summary_provider.dart';
import '../../data/quotation_commercial_repository.dart';

class CotizacionClientePreviewScreen extends ConsumerStatefulWidget {
  const CotizacionClientePreviewScreen({super.key});

  @override
  ConsumerState<CotizacionClientePreviewScreen> createState() =>
      _CotizacionClientePreviewScreenState();
}

class _CotizacionClientePreviewScreenState
    extends ConsumerState<CotizacionClientePreviewScreen> {
  final _currencyFormatter = CurrencyFormatter();
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final activeDraftId = ref.watch(activeQuotationDraftIdProvider);

    if (activeDraftId == null) {
      return AppScaffold(
        title: 'Vista cliente',
        child: _EmptyStateWithButton(
          title: 'No hay cotización activa',
          message: 'Ve a Clientes y continúa una cotización pendiente, o crea un cliente nuevo.',
          icon: Icons.picture_as_pdf_outlined,
          buttonLabel: 'Ir a Clientes',
          onPressed: () => context.go(AppRoutes.clientes),
        ),
      );
    }

    final summaryAsync = ref.watch(quotationSummaryProvider(activeDraftId));

    return AppScaffold(
      title: 'Vista cliente',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () =>
              ref.invalidate(quotationSummaryProvider(activeDraftId)),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _EmptyStateWithButton(
          title: 'Falta completar la cotización interna',
          message:
              'Guarda primero los precios, utilidad e IVA en la cotización interna.',
          icon: Icons.calculate_outlined,
          buttonLabel: 'Ir a cotización interna',
          onPressed: () => context.go(AppRoutes.cotizacionInterna),
        ),
        data: (summary) {
          final quote = summary.commercialQuote;

          if (quote == null) {
            return _EmptyStateWithButton(
              title: 'Falta completar la cotización interna',
              message:
                  'Guarda primero los precios, utilidad e IVA en la cotización interna.',
              icon: Icons.calculate_outlined,
              buttonLabel: 'Ir a cotización interna',
              onPressed: () => context.go(AppRoutes.cotizacionInterna),
            );
          }

          final pv = summary.pvCalculation;
          final annualGenerationKwh =
              pv.generationPerPanelKwhDay * pv.requiredPanels * 365;

          return ListView(
            children: [
              SectionCard(
                title: 'Sistema propuesto',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${pv.requiredPanels} × ${summary.panel.displayName}'),
                    Text(
                      '${summary.requiredInverters} × ${summary.inverter.displayName}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Capacidad instalada: '
                      '${(pv.requiredPanels * summary.panel.powerWatts / 1000).toStringAsFixed(2)} kWp',
                    ),
                    Text(
                      'Generación estimada: '
                      '${(annualGenerationKwh / 12).toStringAsFixed(0)} kWh/mes '
                      '· ${annualGenerationKwh.toStringAsFixed(0)} kWh/año',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Inversión',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ClientRow(
                      label: 'Subtotal',
                      value: _currencyFormatter.format(quote.subtotal),
                    ),
                    if (quote.discountAmount > 0)
                      _ClientRow(
                        label: 'Descuento',
                        value:
                            '-${_currencyFormatter.format(quote.discountAmount)}',
                      ),
                    _ClientRow(
                      label: 'IVA (${quote.ivaRatePercent.toStringAsFixed(0)}%)',
                      value: _currencyFormatter.format(quote.ivaAmount),
                    ),
                    _ClientRow(
                      label: 'Total',
                      value: _currencyFormatter.format(quote.total),
                      isMainResult: true,
                    ),
                    if (quote.advancePaymentAmount > 0)
                      _ClientRow(
                        label: 'Anticipo',
                        value: _currencyFormatter
                            .format(quote.advancePaymentAmount),
                      ),
                    if (quote.advancePaymentAmount > 0)
                      _ClientRow(
                        label: 'Saldo restante',
                        value: _currencyFormatter.format(quote.balanceDue),
                      ),
                    if (quote.paymentTermsNote != null &&
                        quote.paymentTermsNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Esquema de pagos: ${quote.paymentTermsNote}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Garantías',
                child: Text(summary.commercialSettings.warrantyNote),
              ),
              const SizedBox(height: 16),
              if (quote.hasGeneratedPdf)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Último PDF generado: '
                    '${_formatDate(quote.pdfGeneratedAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isGenerating
                      ? null
                      : () => _generateAndShare(
                            activeDraftId: activeDraftId,
                            summary: summary,
                          ),
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_outlined),
                  label: Text(
                    _isGenerating ? 'Generando...' : 'Generar y compartir PDF',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGenerating
                      ? null
                      : () => _previewPdf(summary: summary),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Vista previa / imprimir'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.propuestaTecnica),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Generar propuesta técnica'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.contrato),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Ir a contrato y firma'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<QuotationPdfData> _buildPdfData(QuotationSummary summary) async {
    final draft = summary.draft;
    final quote = summary.commercialQuote!;
    final pv = summary.pvCalculation;
    final annualGenerationKwh =
        pv.generationPerPanelKwhDay * pv.requiredPanels * 365;

    return QuotationPdfData(
      draftCode: draft.draftCode ?? draft.id.substring(0, 8).toUpperCase(),
      generatedAt: DateTime.now(),
      company: QuotationPdfCompanyInfo(
        companyName: summary.companyProfile.companyName.trim().isEmpty
            ? AppConstants.companyName
            : summary.companyProfile.companyName,
        phone: summary.companyProfile.phone,
        email: summary.companyProfile.email,
        address: summary.companyProfile.address,
      ),
      client: QuotationPdfClientInfo(
        fullName: draft.prospectName,
        phone: draft.phone,
        email: draft.email,
        address: draft.address,
      ),
      system: QuotationPdfSystemSummary(
        panelDisplayName: summary.panel.displayName,
        panelPowerWatts: summary.panel.powerWatts,
        panelQuantity: pv.requiredPanels,
        totalPanelPowerWatts: pv.requiredPanels * summary.panel.powerWatts,
        inverterDisplayName: summary.inverter.displayName,
        inverterQuantity: summary.requiredInverters,
        estimatedDailyGenerationKwh: pv.generationPerPanelKwhDay *
            pv.requiredPanels,
        estimatedMonthlyGenerationKwh: annualGenerationKwh / 12,
        estimatedAnnualGenerationKwh: annualGenerationKwh,
      ),
      commercial: QuotationPdfCommercialSummary(
        currency: quote.currency,
        subtotal: quote.subtotal,
        ivaRatePercent: quote.ivaRatePercent,
        ivaAmount: quote.ivaAmount,
        discountAmount: quote.discountAmount,
        advancePaymentAmount: quote.advancePaymentAmount,
        total: quote.total,
        validityDays: summary.commercialSettings.defaultQuotationValidityDays,
        paymentTermsNote: quote.paymentTermsNote,
        structureMaterialsPrice: quote.structureMaterialsPrice,
        structureMaterialsHasMissingPrices:
            quote.structureMaterialsHasMissingPrices,
      ),
      warrantyNote: summary.commercialSettings.warrantyNote,
      legalNote: summary.commercialSettings.quotationLegalNote,
    );
  }

  /// Construye los datos del PDF de planos estructurales a partir del
  /// mismo [QuotationSummary] ya cargado, para fusionarlo con la
  /// cotización en un solo documento (Fase 6.23). Devuelve `null` si el
  /// borrador todavía no tiene un diseño de estructura guardado.
  StructureTechnicalPdfData? _buildStructurePdfData(
    QuotationSummary summary,
    String draftCode,
  ) {
    final structureResult = summary.structureResult;
    final structureSelection = summary.structureSelection;

    if (structureResult == null || structureSelection == null) return null;

    return StructureTechnicalPdfData(
      draftCode: draftCode,
      generatedAt: DateTime.now(),
      company: QuotationPdfCompanyInfo(
        companyName: summary.companyProfile.companyName.trim().isEmpty
            ? AppConstants.companyName
            : summary.companyProfile.companyName,
        phone: summary.companyProfile.phone,
        email: summary.companyProfile.email,
        address: summary.companyProfile.address,
      ),
      projectLabel: summary.draft.prospectName,
      mountTypeLabel: _mountTypeLabel(structureSelection.mountType),
      fixingTypeLabel: _fixingTypeLabel(structureSelection.fixingType),
      panelLengthMm: summary.panel.lengthMm ?? 0,
      panelWidthMm: summary.panel.widthMm ?? 0,
      result: structureResult,
    );
  }

  String _mountTypeLabel(String key) {
    for (final value in StructureMountType.values) {
      if (value.name == key) return value.label;
    }
    return key;
  }

  String _fixingTypeLabel(String key) {
    for (final value in StructureFixingType.values) {
      if (value.name == key) return value.label;
    }
    return key;
  }

  Future<void> _previewPdf({required QuotationSummary summary}) async {
    final data = await _buildPdfData(summary);
    final structureData = _buildStructurePdfData(summary, data.draftCode);

    final bytes = structureData == null
        ? await ref.read(pdfServiceProvider).generateQuotationPdf(data)
        : await ref.read(pdfServiceProvider).generateQuotationWithStructuralPdf(
              quotationData: data,
              structureData: structureData,
            );

    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _generateAndShare({
    required String activeDraftId,
    required QuotationSummary summary,
  }) async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final data = await _buildPdfData(summary);
      final structureData = _buildStructurePdfData(summary, data.draftCode);

      final bytes = structureData == null
          ? await ref.read(pdfServiceProvider).generateQuotationPdf(data)
          : await ref
              .read(pdfServiceProvider)
              .generateQuotationWithStructuralPdf(
                quotationData: data,
                structureData: structureData,
              );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'cotizacion_${data.draftCode}_$timestamp.pdf';

      final file = await ref.read(fileStorageServiceProvider).saveBytes(
            bytes: bytes,
            fileName: fileName,
            subfolder: 'quotation_drafts/$activeDraftId/quotations',
          );

      await ref.read(quotationCommercialRepositoryProvider).attachGeneratedPdf(
            AttachQuotationPdfInput(
              draftId: activeDraftId,
              localPath: file.path,
              fileName: fileName,
              sizeBytes: bytes.length,
            ),
          );

      ref.invalidate(quotationSummaryProvider(activeDraftId));
      ref.invalidate(quotationDraftsControllerProvider);

      if (!mounted) return;

      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el PDF: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.label,
    required this.value,
    this.isMainResult = false,
  });

  final String label;
  final String value;
  final bool isMainResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: isMainResult
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: (isMainResult
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.bodyMedium)
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
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
