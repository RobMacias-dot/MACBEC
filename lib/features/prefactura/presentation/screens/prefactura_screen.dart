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
import '../../../clientes/data/client_fiscal_repository.dart';
import '../../../clientes/domain/sat_catalogs.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../../cotizaciones/application/quotation_summary_provider.dart';
import '../../../cotizaciones/domain/entities/quotation_commercial_quote.dart';
import '../../../documentos_pdf/data/pdf_service.dart';
import '../../../documentos_pdf/domain/entities/pre_invoice_pdf_data.dart';
import '../../../documentos_pdf/domain/entities/quotation_pdf_data.dart';
import '../../../proyectos/application/projects_controller.dart';
import '../../data/pre_invoice_repository.dart';
import '../../domain/entities/pre_invoice.dart';

class PrefacturaScreen extends ConsumerStatefulWidget {
  const PrefacturaScreen({super.key});

  @override
  ConsumerState<PrefacturaScreen> createState() => _PrefacturaScreenState();
}

class _PrefacturaScreenState extends ConsumerState<PrefacturaScreen> {
  final _rfcController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _folioController = TextEditingController();

  String? _fiscalRegime;
  String? _cfdiUse;
  String _paymentForm = SatCatalogs.formasPago.keys.first;
  String _paymentMethod = SatCatalogs.metodosPago.keys.first;

  bool _initialized = false;
  bool _isSaving = false;
  bool _isGenerating = false;

  @override
  void dispose() {
    _rfcController.dispose();
    _legalNameController.dispose();
    _zipCodeController.dispose();
    _folioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeDraftId = ref.watch(activeQuotationDraftIdProvider);

    if (activeDraftId == null) {
      return AppScaffold(
        title: 'Pre-factura',
        child: _EmptyStateWithButton(
          title: 'No hay cotización activa',
          message: 'Crea o selecciona una cotización para continuar.',
          icon: Icons.receipt_long_outlined,
          buttonLabel: 'Ir a cotización',
          onPressed: () => context.go(AppRoutes.cotizacion),
        ),
      );
    }

    final summaryAsync = ref.watch(quotationSummaryProvider(activeDraftId));

    return AppScaffold(
      title: 'Pre-factura',
      child: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _EmptyStateWithButton(
          title: 'Falta completar la cotización interna',
          message:
              'Guarda primero los precios en la cotización interna antes de generar la pre-factura.',
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
                  'Guarda primero los precios en la cotización interna antes de generar la pre-factura.',
              icon: Icons.calculate_outlined,
              buttonLabel: 'Ir a cotización interna',
              onPressed: () => context.go(AppRoutes.cotizacionInterna),
            );
          }

          final preInvoiceAsync =
              ref.watch(preInvoiceByDraftProvider(activeDraftId));

          return preInvoiceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                EmptyState(title: 'Error', message: error.toString()),
            data: (preInvoice) {
              _ensureInitialized(preInvoice);

              return _buildForm(
                activeDraftId: activeDraftId,
                summary: summary,
                preInvoice: preInvoice,
              );
            },
          );
        },
      ),
    );
  }

  void _ensureInitialized(PreInvoice? preInvoice) {
    if (_initialized) return;
    _initialized = true;

    _rfcController.text = preInvoice?.clientRfc ?? '';
    _legalNameController.text = preInvoice?.clientLegalName ?? '';
    _zipCodeController.text = preInvoice?.clientFiscalZipCode ?? '';
    _folioController.text = preInvoice?.folio ?? '';
    _fiscalRegime = preInvoice?.clientFiscalRegime;
    _cfdiUse = preInvoice?.cfdiUse;
    _paymentForm = preInvoice?.paymentForm ?? _paymentForm;
    _paymentMethod = preInvoice?.paymentMethod ?? _paymentMethod;
  }

  Widget _buildForm({
    required String activeDraftId,
    required QuotationSummary summary,
    required PreInvoice? preInvoice,
  }) {
    final quote = summary.commercialQuote!;

    return ListView(
      children: [
        if (summary.draft.projectId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => _prefillFromClientFiscalData(
                summary.draft.projectId!,
              ),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Usar datos fiscales del cliente'),
            ),
          ),
        SectionCard(
          title: 'Datos fiscales',
          child: Column(
            children: [
              TextField(
                controller: _rfcController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'RFC'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _legalNameController,
                decoration: const InputDecoration(labelText: 'Razón social'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _fiscalRegime,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Régimen fiscal'),
                items: [
                  for (final entry in SatCatalogs.regimenesFiscales.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        '${entry.key} - ${entry.value}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _fiscalRegime = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _zipCodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'CP fiscal'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _cfdiUse,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Uso CFDI'),
                items: [
                  for (final entry in SatCatalogs.usosCfdi.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        '${entry.key} - ${entry.value}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _cfdiUse = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Forma y método de pago',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _paymentForm,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Forma de pago'),
                items: [
                  for (final entry in SatCatalogs.formasPago.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text('${entry.key} - ${entry.value}'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _paymentForm = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Método de pago'),
                items: [
                  for (final entry in SatCatalogs.metodosPago.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text('${entry.key} - ${entry.value}'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _paymentMethod = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _folioController,
                decoration: const InputDecoration(
                  labelText: 'Folio interno (opcional)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Importes (de la cotización)',
          child: Text(
            'Subtotal ${quote.currency} ${quote.subtotal.toStringAsFixed(2)} · '
            'IVA ${quote.currency} ${quote.ivaAmount.toStringAsFixed(2)} · '
            'Total ${quote.currency} ${quote.total.toStringAsFixed(2)}',
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSaving
                ? null
                : () => _save(activeDraftId: activeDraftId, quote: quote),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Guardando...' : 'Guardar pre-factura'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (preInvoice == null || _isGenerating)
                ? null
                : () => _generateAndShare(
                      activeDraftId: activeDraftId,
                      summary: summary,
                      preInvoice: preInvoice,
                    ),
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              _isGenerating ? 'Generando...' : 'Generar y compartir PDF',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _prefillFromClientFiscalData(String projectId) async {
    try {
      final project = await ref.read(projectByIdProvider(projectId).future);
      if (project == null) return;

      final profile = await ref.read(
        clientFiscalProfileProvider(project.clientId).future,
      );

      if (profile == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El cliente todavía no tiene datos fiscales.'),
          ),
        );
        return;
      }

      setState(() {
        _rfcController.text = profile.rfc ?? '';
        _legalNameController.text = profile.legalName ?? '';
        _zipCodeController.text = profile.fiscalZipCode ?? '';
        _fiscalRegime = profile.fiscalRegime;
        _cfdiUse = profile.cfdiUse;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los datos: $error')),
      );
    }
  }

  Future<void> _save({
    required String activeDraftId,
    required QuotationCommercialQuote quote,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(preInvoiceRepositoryProvider).upsert(
            quotationDraftId: activeDraftId,
            input: SavePreInvoiceInput(
              clientRfc: _rfcController.text,
              clientLegalName: _legalNameController.text,
              clientFiscalRegime: _fiscalRegime,
              clientFiscalZipCode: _zipCodeController.text,
              cfdiUse: _cfdiUse,
              paymentForm: _paymentForm,
              paymentMethod: _paymentMethod,
              subtotal: quote.subtotal,
              ivaAmount: quote.ivaAmount,
              total: quote.total,
              folio: _folioController.text,
            ),
          );

      ref.invalidate(preInvoiceByDraftProvider(activeDraftId));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pre-factura guardada.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _generateAndShare({
    required String activeDraftId,
    required QuotationSummary summary,
    required PreInvoice preInvoice,
  }) async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final draft = summary.draft;
      final draftCode =
          draft.draftCode ?? draft.id.substring(0, 8).toUpperCase();

      final data = PreInvoicePdfData(
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
        clientName: draft.prospectName,
        clientRfc: preInvoice.clientRfc,
        clientLegalName: preInvoice.clientLegalName,
        clientFiscalRegimeLabel: preInvoice.clientFiscalRegime == null
            ? null
            : '${preInvoice.clientFiscalRegime} - '
                '${SatCatalogs.regimenesFiscales[preInvoice.clientFiscalRegime] ?? ''}',
        clientFiscalZipCode: preInvoice.clientFiscalZipCode,
        cfdiUseLabel: preInvoice.cfdiUse == null
            ? null
            : '${preInvoice.cfdiUse} - '
                '${SatCatalogs.usosCfdi[preInvoice.cfdiUse] ?? ''}',
        paymentFormLabel:
            '${preInvoice.paymentForm} - ${SatCatalogs.formasPago[preInvoice.paymentForm] ?? ''}',
        paymentMethodLabel:
            '${preInvoice.paymentMethod} - ${SatCatalogs.metodosPago[preInvoice.paymentMethod] ?? ''}',
        currency: summary.commercialSettings.currency,
        subtotal: preInvoice.subtotal,
        ivaAmount: preInvoice.ivaAmount,
        total: preInvoice.total,
        folio: preInvoice.folio,
      );

      final bytes = await ref.read(pdfServiceProvider).generatePreInvoicePdf(data);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'prefactura_${draftCode}_$timestamp.pdf';

      final file = await ref.read(fileStorageServiceProvider).saveBytes(
            bytes: bytes,
            fileName: fileName,
            subfolder: 'quotation_drafts/$activeDraftId/prefactura',
          );

      await ref.read(preInvoiceRepositoryProvider).attachGeneratedPdf(
            quotationDraftId: activeDraftId,
            localPath: file.path,
            fileName: fileName,
            sizeBytes: bytes.length,
          );

      ref.invalidate(preInvoiceByDraftProvider(activeDraftId));

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
