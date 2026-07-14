import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/files/file_storage_service.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../../cotizaciones/application/quotation_summary_provider.dart';
import '../../../estructura/domain/structure_design_rules.dart';
import '../../../expediente/data/documents_repository.dart';
import '../../../expediente/domain/entities/document_record.dart';
import '../../data/pdf_service.dart';
import '../../domain/entities/quotation_pdf_data.dart';
import '../../domain/entities/technical_proposal_pdf_data.dart';

class PropuestaTecnicaScreen extends ConsumerStatefulWidget {
  const PropuestaTecnicaScreen({super.key});

  @override
  ConsumerState<PropuestaTecnicaScreen> createState() =>
      _PropuestaTecnicaScreenState();
}

class _PropuestaTecnicaScreenState
    extends ConsumerState<PropuestaTecnicaScreen> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final activeDraftId = ref.watch(activeQuotationDraftIdProvider);

    if (activeDraftId == null) {
      return AppScaffold(
        title: 'Propuesta técnica',
        child: _EmptyStateWithButton(
          title: 'No hay cotización activa',
          message: 'Crea o selecciona una cotización para continuar.',
          icon: Icons.description_outlined,
          buttonLabel: 'Ir a cotización',
          onPressed: () => context.go(AppRoutes.cotizacion),
        ),
      );
    }

    final summaryAsync = ref.watch(quotationSummaryProvider(activeDraftId));

    return AppScaffold(
      title: 'Propuesta técnica',
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
        error: (error, stackTrace) => EmptyState(
          title: 'No se pudo cargar la información técnica',
          message: error.toString(),
          icon: Icons.error_outline,
        ),
        data: (summary) {
          return ListView(
            children: [
              SectionCard(
                title: 'Contenido del documento',
                subtitle:
                    'Portada, cliente, resumen del sistema, dimensionamiento '
                    'eléctrico${summary.structureResult != null ? ', estructura' : ''} '
                    'y garantías.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.pvCalculation.requiredPanels} × '
                      '${summary.panel.displayName}',
                    ),
                    Text(
                      '${summary.requiredInverters} × '
                      '${summary.inverter.displayName}',
                    ),
                    const SizedBox(height: 8),
                    if (summary.structureResult == null)
                      const Text(
                        'Nota: todavía no hay un diseño de estructura '
                        'guardado; el documento se generará sin esa sección.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                  onPressed:
                      _isGenerating ? null : () => _previewPdf(summary),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Vista previa / imprimir'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  TechnicalProposalPdfData _buildPdfData(QuotationSummary summary) {
    final draft = summary.draft;
    final pv = summary.pvCalculation;
    final annualGenerationKwh =
        pv.generationPerPanelKwhDay * pv.requiredPanels * 365;
    final option = summary.electricalOption;
    final structureResult = summary.structureResult;
    final structureSelection = summary.structureSelection;

    return TechnicalProposalPdfData(
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
        estimatedDailyGenerationKwh:
            pv.generationPerPanelKwhDay * pv.requiredPanels,
        estimatedMonthlyGenerationKwh: annualGenerationKwh / 12,
        estimatedAnnualGenerationKwh: annualGenerationKwh,
      ),
      electrical: TechnicalProposalElectricalSummary(
        panelVoc: summary.panel.voc,
        panelIsc: summary.panel.isc,
        maxPanelsPerString: option.maxPanelsPerString,
        maxParallelStringsPerMppt: option.maxParallelStringsPerMppt,
        requiredStrings: option.requiredStrings,
        inverterUsagePercent: option.inverterUsagePercent,
        reserveCapacityPercent: option.reserveCapacityPercent,
        dcFuseAmps: option.dcFuseRecommendation?.suggestedCommercialFuseAmps,
        dcCableAwg: option.dcCableRecommendation?.suggestedAwg,
        dcConduitSize: option.dcConduitRecommendation?.suggestedConduitTradeSize,
        acCableAwg: summary.acRecommendation?.suggestedAwg,
        acVoltageDropPercent: summary.acRecommendation?.voltageDropPercent,
        warnings: option.warnings,
      ),
      structure: (structureResult == null || structureSelection == null)
          ? null
          : TechnicalProposalStructureSummary(
              mountTypeLabel: StructureMountType.inclinedFlatRoof.label,
              fixingTypeLabel: _fixingLabel(structureSelection.fixingType),
              structuresCount: structureResult.structuresCount,
              panelsHorizontal: structureResult.panelsHorizontal,
              panelRows: structureResult.panelRows,
              totalLegCount: structureResult.totalLegCount,
              areaMetersSquared: structureResult.areaMetersSquared,
              angleMaterialMeters: structureResult.angleMaterialMeters,
            ),
      warrantyNote: summary.commercialSettings.warrantyNote,
    );
  }

  String _fixingLabel(String key) {
    for (final value in StructureFixingType.values) {
      if (value.name == key) return value.label;
    }
    return key;
  }

  Future<void> _previewPdf(QuotationSummary summary) async {
    final data = _buildPdfData(summary);
    final bytes =
        await ref.read(pdfServiceProvider).generateTechnicalProposalPdf(data);

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
      final data = _buildPdfData(summary);
      final bytes = await ref
          .read(pdfServiceProvider)
          .generateTechnicalProposalPdf(data);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'propuesta_tecnica_${data.draftCode}_$timestamp.pdf';

      final file = await ref.read(fileStorageServiceProvider).saveBytes(
            bytes: bytes,
            fileName: fileName,
            subfolder: 'quotation_drafts/$activeDraftId/propuesta_tecnica',
          );

      await ref.read(documentsRepositoryProvider).attachDraftDocument(
            quotationDraftId: activeDraftId,
            documentType: DocumentTypes.technicalProposalPdf,
            localPath: file.path,
            fileName: fileName,
            mimeType: 'application/pdf',
            sizeBytes: bytes.length,
          );

      if (!mounted) return;

      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el documento: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
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
