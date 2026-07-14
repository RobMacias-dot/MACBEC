import 'dart:io';
import 'dart:typed_data';

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
import '../../../documentos_pdf/data/pdf_service.dart';
import '../../../documentos_pdf/domain/entities/contract_pdf_data.dart';
import '../../../documentos_pdf/domain/entities/quotation_pdf_data.dart';
import '../../data/contract_repository.dart';
import '../../domain/contract_template_builder.dart';
import '../../domain/entities/contract.dart';
import 'firma_captura_screen.dart';

class ContratoScreen extends ConsumerStatefulWidget {
  const ContratoScreen({super.key});

  @override
  ConsumerState<ContratoScreen> createState() => _ContratoScreenState();
}

class _ContratoScreenState extends ConsumerState<ContratoScreen> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final activeDraftId = ref.watch(activeQuotationDraftIdProvider);

    if (activeDraftId == null) {
      return AppScaffold(
        title: 'Contrato',
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
      title: 'Contrato',
      child: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _EmptyStateWithButton(
          title: 'Falta completar la cotización interna',
          message:
              'Guarda primero los precios en la cotización interna antes de generar el contrato.',
          icon: Icons.calculate_outlined,
          buttonLabel: 'Ir a cotización interna',
          onPressed: () => context.go(AppRoutes.cotizacionInterna),
        ),
        data: (summary) {
          if (summary.commercialQuote == null) {
            return _EmptyStateWithButton(
              title: 'Falta completar la cotización interna',
              message:
                  'Guarda primero los precios en la cotización interna antes de generar el contrato.',
              icon: Icons.calculate_outlined,
              buttonLabel: 'Ir a cotización interna',
              onPressed: () => context.go(AppRoutes.cotizacionInterna),
            );
          }

          final contractAsync =
              ref.watch(contractByDraftProvider(activeDraftId));

          return contractAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                EmptyState(title: 'Error', message: error.toString()),
            data: (contract) => _buildContent(
              activeDraftId: activeDraftId,
              summary: summary,
              contract: contract,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required String activeDraftId,
    required QuotationSummary summary,
    required Contract? contract,
  }) {
    return ListView(
      children: [
        if (contract == null)
          SectionCard(
            title: 'Generar contrato',
            subtitle:
                'Se creará una plantilla base con los datos de esta cotización. '
                'Revísala antes de compartirla; no sustituye asesoría legal.',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isBusy
                    ? null
                    : () => _generateContractText(
                          activeDraftId: activeDraftId,
                          summary: summary,
                        ),
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Generar texto del contrato'),
              ),
            ),
          )
        else ...[
          SectionCard(
            title: 'Estado del contrato',
            trailing: Chip(
              visualDensity: VisualDensity.compact,
              backgroundColor: contract.isSigned
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              label: Text(contract.isSigned ? 'Firmado' : 'Borrador'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SignatureStatusRow(
                  label: 'Firma del cliente',
                  signed: contract.hasClientSignature,
                  onPressed: contract.isSigned
                      ? null
                      : () => _goToSignature(
                            activeDraftId,
                            SignatureRole.client,
                          ),
                ),
                const SizedBox(height: 8),
                _SignatureStatusRow(
                  label: 'Firma del proveedor',
                  signed: contract.hasProviderSignature,
                  onPressed: contract.isSigned
                      ? null
                      : () => _goToSignature(
                            activeDraftId,
                            SignatureRole.provider,
                          ),
                ),
                if (!contract.isSigned) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _isBusy
                        ? null
                        : () => _generateContractText(
                              activeDraftId: activeDraftId,
                              summary: summary,
                            ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar texto del contrato'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Texto del contrato',
            child: Text(
              contract.contractText,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isBusy
                  ? null
                  : () => _generateAndSharePdf(
                        activeDraftId: activeDraftId,
                        summary: summary,
                        contract: contract,
                      ),
              icon: _isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_isBusy ? 'Generando...' : 'Generar y compartir PDF'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.prefactura),
              icon: const Icon(Icons.request_quote_outlined),
              label: const Text('Ir a pre-factura'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _generateContractText({
    required String activeDraftId,
    required QuotationSummary summary,
  }) async {
    setState(() {
      _isBusy = true;
    });

    try {
      final draft = summary.draft;
      final quote = summary.commercialQuote!;
      final pv = summary.pvCalculation;

      final text = ContractTemplateBuilder.build(
        ContractTemplateInput(
          companyName: summary.companyProfile.companyName.trim().isEmpty
              ? AppConstants.companyName
              : summary.companyProfile.companyName,
          companyRfc: summary.companyProfile.rfc,
          companyAddress: summary.companyProfile.address,
          clientName: draft.prospectName,
          clientAddress: draft.address,
          systemDescription:
              '${pv.requiredPanels} × ${summary.panel.displayName}, '
              '${summary.requiredInverters} × ${summary.inverter.displayName}',
          totalPvKw: pv.requiredPanels * summary.panel.powerWatts / 1000,
          currency: quote.currency,
          total: quote.total,
          advancePayment: quote.advancePaymentAmount,
          paymentTermsNote: quote.paymentTermsNote,
          warrantyNote: summary.commercialSettings.warrantyNote,
          date: DateTime.now(),
        ),
      );

      await ref.read(contractRepositoryProvider).upsertContractText(
            quotationDraftId: activeDraftId,
            contractText: text,
          );

      ref.invalidate(contractByDraftProvider(activeDraftId));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contrato generado.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el contrato: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _goToSignature(String activeDraftId, SignatureRole role) {
    context.push(
      AppRoutes.contratoFirma,
      extra: FirmaCapturaArgs(
        quotationDraftId: activeDraftId,
        role: role,
      ),
    );
  }

  Future<void> _generateAndSharePdf({
    required String activeDraftId,
    required QuotationSummary summary,
    required Contract contract,
  }) async {
    setState(() {
      _isBusy = true;
    });

    try {
      final repository = ref.read(contractRepositoryProvider);

      final clientSignatureBytes = await _loadSignatureBytes(
        repository,
        contract.clientSignatureDocumentId,
      );
      final providerSignatureBytes = await _loadSignatureBytes(
        repository,
        contract.providerSignatureDocumentId,
      );

      final draftCode = summary.draft.draftCode ??
          summary.draft.id.substring(0, 8).toUpperCase();

      final data = ContractPdfData(
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
        contractText: contract.contractText,
        clientSignatureBytes: clientSignatureBytes,
        providerSignatureBytes: providerSignatureBytes,
        signedAt: contract.signedAt,
      );

      final bytes = await ref.read(pdfServiceProvider).generateContractPdf(data);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'contrato_${draftCode}_$timestamp.pdf';

      final file = await ref.read(fileStorageServiceProvider).saveBytes(
            bytes: bytes,
            fileName: fileName,
            subfolder: 'quotation_drafts/$activeDraftId/contrato',
          );

      await repository.attachContractPdf(
        quotationDraftId: activeDraftId,
        localPath: file.path,
        fileName: fileName,
        sizeBytes: bytes.length,
      );

      ref.invalidate(contractByDraftProvider(activeDraftId));

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
          _isBusy = false;
        });
      }
    }
  }

  Future<Uint8List?> _loadSignatureBytes(
    ContractRepository repository,
    String? documentId,
  ) async {
    if (documentId == null) return null;

    final path = await repository.getDocumentLocalPath(documentId);
    if (path == null) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    return file.readAsBytes();
  }
}

class _SignatureStatusRow extends StatelessWidget {
  const _SignatureStatusRow({
    required this.label,
    required this.signed,
    required this.onPressed,
  });

  final String label;
  final bool signed;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          signed ? Icons.check_circle : Icons.pending_outlined,
          color: signed
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        if (!signed)
          TextButton(
            onPressed: onPressed,
            child: const Text('Firmar'),
          ),
      ],
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
