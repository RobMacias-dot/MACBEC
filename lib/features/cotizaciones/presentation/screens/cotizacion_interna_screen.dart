import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/formatters/currency_formatter.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../estructura/domain/structure_design_rules.dart';
import '../../../estructura/domain/structure_material_pricer.dart';
import '../../../materiales_catalogo/data/material_catalog_repository.dart';
import '../../../materiales_catalogo/domain/entities/material_catalog_product.dart';
import '../../application/quotation_draft_controller.dart';
import '../../application/quotation_summary_provider.dart';
import '../../data/quotation_commercial_repository.dart';
import '../../domain/entities/quotation_commercial_quote.dart';
import '../../domain/entities/quotation_draft.dart';
import '../../domain/quotation_commercial_calculator.dart';

class CotizacionInternaScreen extends ConsumerStatefulWidget {
  const CotizacionInternaScreen({super.key});

  @override
  ConsumerState<CotizacionInternaScreen> createState() =>
      _CotizacionInternaScreenState();
}

class _CotizacionInternaScreenState
    extends ConsumerState<CotizacionInternaScreen> {
  final _utilityRateController = TextEditingController();
  final _panelUtilityRateController = TextEditingController();
  final _inverterUtilityRateController = TextEditingController();
  final _ivaRateController = TextEditingController();
  final _discountController = TextEditingController();
  final _advanceController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _currencyFormatter = CurrencyFormatter();

  bool _initialized = false;
  bool _isSaving = false;
  bool _isAccepting = false;
  bool _showAdvancedUtility = false;
  bool _showHistory = false;

  @override
  void dispose() {
    _utilityRateController.dispose();
    _panelUtilityRateController.dispose();
    _inverterUtilityRateController.dispose();
    _ivaRateController.dispose();
    _discountController.dispose();
    _advanceController.dispose();
    _paymentTermsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeDraftId = ref.watch(activeQuotationDraftIdProvider);

    if (activeDraftId == null) {
      return AppScaffold(
        title: 'Cotización interna',
        child: _EmptyStateWithButton(
          title: 'No hay cotización activa',
          message: 'Crea o selecciona una cotización para continuar.',
          icon: Icons.calculate_outlined,
          buttonLabel: 'Ir a cotización',
          onPressed: () => context.go(AppRoutes.cotizacion),
        ),
      );
    }

    final summaryAsync = ref.watch(quotationSummaryProvider(activeDraftId));

    return AppScaffold(
      title: 'Cotización interna',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => ref.invalidate(
            quotationSummaryProvider(activeDraftId),
          ),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _buildErrorState(context, error, activeDraftId),
        data: (summary) {
          _ensureInitialized(summary);

          final quote = summary.commercialQuote;
          final catalog =
              ref.watch(materialCatalogProductsProvider).valueOrNull ??
                  const [];
          final structureLines = _computeStructureLines(summary, catalog);
          final structureMaterialsCost = structureLines.fold<double>(
            0,
            (sum, line) => sum + (line.lineTotalMxn ?? 0),
          );
          final structureHasMissingPrices =
              structureLines.any((line) => !line.hasPrice);

          return ListView(
            children: [
              if (quote != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('Versión ${quote.versionNumber}'),
                      ),
                      const SizedBox(width: 8),
                      if (quote.isAccepted)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          label: const Text('Aceptada'),
                        ),
                    ],
                  ),
                ),
              SectionCard(
                title: 'Resumen técnico',
                child: _TechnicalSummary(summary: summary),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Parámetros comerciales',
                child: _CommercialInputs(
                  utilityRateController: _utilityRateController,
                  panelUtilityRateController: _panelUtilityRateController,
                  inverterUtilityRateController: _inverterUtilityRateController,
                  ivaRateController: _ivaRateController,
                  discountController: _discountController,
                  advanceController: _advanceController,
                  paymentTermsController: _paymentTermsController,
                  showAdvancedUtility: _showAdvancedUtility,
                  onToggleAdvanced: () => setState(() {
                    _showAdvancedUtility = !_showAdvancedUtility;
                  }),
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Desglose interno',
                subtitle: 'Costos, utilidad y margen (no visibles al cliente).',
                child: _buildBreakdown(
                  summary,
                  structureMaterialsCost: structureMaterialsCost,
                  structureMaterialsHasMissingPrices:
                      structureHasMissingPrices,
                ),
              ),
              if (structureLines.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Materiales de estructura (catálogo)',
                  subtitle: structureHasMissingPrices
                      ? 'Ya se suma al total del cliente. Hay partidas sin precio '
                          '("-"): el total es un estimado parcial hasta que '
                          'completes el catálogo.'
                      : 'Ya se suma al total del cliente, con la utilidad general '
                          'aplicada igual que panel e inversor.',
                  child: _StructureMaterialsPricing(lines: structureLines),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _saveQuote(
                            activeDraftId: activeDraftId,
                            summary: summary,
                            structureMaterialsCost: structureMaterialsCost,
                            structureMaterialsHasMissingPrices:
                                structureHasMissingPrices,
                          ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar nueva versión',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (quote == null || quote.isAccepted || _isAccepting)
                      ? null
                      : () => _acceptQuote(activeDraftId),
                  icon: _isAccepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isAccepting
                        ? 'Guardando...'
                        : 'Marcar como aceptada por el cliente',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: quote == null
                      ? null
                      : () => context.push(AppRoutes.cotizacionClientePreview),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Ir a vista de cliente / PDF'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => setState(() {
                  _showHistory = !_showHistory;
                }),
                icon: Icon(
                  _showHistory ? Icons.expand_less : Icons.expand_more,
                ),
                label: const Text('Historial de versiones'),
              ),
              if (_showHistory)
                _QuoteHistory(draftId: activeDraftId),
            ],
          );
        },
      ),
    );
  }

  void _ensureInitialized(QuotationSummary summary) {
    if (_initialized) return;
    _initialized = true;

    final quote = summary.commercialQuote;

    _utilityRateController.text = (quote?.generalUtilityRatePercent ??
            summary.commercialSettings.generalUtilityRatePercent)
        .toStringAsFixed(2);
    _panelUtilityRateController.text =
        quote?.panelUtilityRatePercent?.toStringAsFixed(2) ?? '';
    _inverterUtilityRateController.text =
        quote?.inverterUtilityRatePercent?.toStringAsFixed(2) ?? '';
    _ivaRateController.text =
        (quote?.ivaRatePercent ?? summary.commercialSettings.ivaRatePercent)
            .toStringAsFixed(2);
    _discountController.text = (quote?.discountAmount ?? 0).toStringAsFixed(2);
    _advanceController.text =
        (quote?.advancePaymentAmount ?? 0).toStringAsFixed(2);
    _paymentTermsController.text = quote?.paymentTermsNote ?? '';
    _showAdvancedUtility = quote?.panelUtilityRatePercent != null ||
        quote?.inverterUtilityRatePercent != null;
  }

  Widget _buildBreakdown(
    QuotationSummary summary, {
    required double structureMaterialsCost,
    required bool structureMaterialsHasMissingPrices,
  }) {
    final input = _calculate(
      summary,
      structureMaterialsCost: structureMaterialsCost,
      structureMaterialsHasMissingPrices: structureMaterialsHasMissingPrices,
    );

    return Column(
      children: [
        _BreakdownRow(
          label:
              'Paneles (${input.panelQuantity} × ${_currencyFormatter.format(input.panelUnitCost)} costo)',
          value: _currencyFormatter.format(
            input.panelUnitPrice * input.panelQuantity,
          ),
        ),
        _BreakdownRow(
          label:
              'Inversor (${input.inverterQuantity} × ${_currencyFormatter.format(input.inverterUnitCost)} costo)',
          value: _currencyFormatter.format(
            input.inverterUnitPrice * input.inverterQuantity,
          ),
        ),
        if (input.structureMaterialsPrice > 0)
          _BreakdownRow(
            label: 'Estructura y materiales '
                '(${_currencyFormatter.format(input.structureMaterialsCost)} costo)'
                '${input.structureMaterialsHasMissingPrices ? ' — parcial' : ''}',
            value: _currencyFormatter.format(input.structureMaterialsPrice),
          ),
        const Divider(),
        _BreakdownRow(
          label: 'Subtotal',
          value: _currencyFormatter.format(input.subtotal),
        ),
        if (input.discountAmount > 0)
          _BreakdownRow(
            label: 'Descuento',
            value: '-${_currencyFormatter.format(input.discountAmount)}',
          ),
        _BreakdownRow(
          label: 'IVA (${input.ivaRatePercent.toStringAsFixed(0)}%)',
          value: _currencyFormatter.format(input.ivaAmount),
        ),
        _BreakdownRow(
          label: 'Total',
          value: _currencyFormatter.format(input.total),
          isMainResult: true,
        ),
        if (input.advancePaymentAmount > 0)
          _BreakdownRow(
            label: 'Saldo restante tras anticipo',
            value: _currencyFormatter.format(
              input.total - input.advancePaymentAmount,
            ),
          ),
      ],
    );
  }

  SaveQuotationCommercialQuoteInput _calculate(
    QuotationSummary summary, {
    required double structureMaterialsCost,
    required bool structureMaterialsHasMissingPrices,
  }) {
    return QuotationCommercialCalculator.calculate(
      panel: summary.panel,
      panelQuantity: summary.pvCalculation.requiredPanels,
      inverter: summary.inverter,
      inverterQuantity: summary.requiredInverters,
      generalUtilityRatePercent: _parseDouble(_utilityRateController.text) ??
          summary.commercialSettings.generalUtilityRatePercent,
      panelUtilityRatePercent: _showAdvancedUtility
          ? _parseDouble(_panelUtilityRateController.text)
          : null,
      inverterUtilityRatePercent: _showAdvancedUtility
          ? _parseDouble(_inverterUtilityRateController.text)
          : null,
      ivaRatePercent: _parseDouble(_ivaRateController.text) ??
          summary.commercialSettings.ivaRatePercent,
      discountAmount: _parseDouble(_discountController.text) ?? 0,
      advancePaymentAmount: _parseDouble(_advanceController.text) ?? 0,
      currency: summary.commercialSettings.currency,
      paymentTermsNote: _paymentTermsController.text,
      structureMaterialsCost: structureMaterialsCost,
      structureMaterialsHasMissingPrices: structureMaterialsHasMissingPrices,
    );
  }

  /// Reconstruye las líneas de materiales de estructura con precio de
  /// catálogo a partir del resultado ya calculado en [summary] (Fase 6.22
  /// conectado al total oficial del cliente).
  List<PricedStructureLine> _computeStructureLines(
    QuotationSummary summary,
    List<MaterialCatalogProduct> catalog,
  ) {
    final result = summary.structureResult;
    final selection = summary.structureSelection;

    if (result == null || selection == null) return const [];

    final angleMaterial =
        _angleMaterialFromKey(selection.angleMaterial) ??
            StructureAngleMaterial.steelPtr;
    final fixingType =
        _fixingTypeFromKey(selection.fixingType) ??
            StructureFixingType.chemicalAnchor;

    return StructureMaterialPricer.price(
      result: result,
      angleMaterial: angleMaterial,
      fixingType: fixingType,
      catalog: catalog,
    );
  }

  StructureAngleMaterial? _angleMaterialFromKey(String key) {
    for (final value in StructureAngleMaterial.values) {
      if (value.name == key) return value;
    }
    return null;
  }

  StructureFixingType? _fixingTypeFromKey(String key) {
    for (final value in StructureFixingType.values) {
      if (value.name == key) return value;
    }
    return null;
  }

  Widget _buildErrorState(
    BuildContext context,
    Object error,
    String activeDraftId,
  ) {
    if (error is QuotationSummaryException) {
      switch (error.issue) {
        case QuotationSummaryIssue.missingPvCalculation:
          return _EmptyStateWithButton(
            title: 'Falta análisis energético',
            message: 'Guarda el cálculo energético antes de cotizar.',
            icon: Icons.analytics_outlined,
            buttonLabel: 'Ir a análisis energético',
            onPressed: () => context.go(AppRoutes.analisisConsumo),
          );
        case QuotationSummaryIssue.missingPanel:
          return _EmptyStateWithButton(
            title: 'Falta selección técnica',
            message: 'Selecciona un panel real del catálogo.',
            icon: Icons.solar_power_outlined,
            buttonLabel: 'Ir a selección técnica',
            onPressed: () => context.go(AppRoutes.seleccionTecnica),
          );
        case QuotationSummaryIssue.missingElectricalSelection:
        case QuotationSummaryIssue.missingInverter:
          return _EmptyStateWithButton(
            title: 'Falta dimensionamiento eléctrico',
            message: 'Selecciona un inversor compatible para continuar.',
            icon: Icons.electrical_services_outlined,
            buttonLabel: 'Ir a dimensionamiento eléctrico',
            onPressed: () => context.go(AppRoutes.dimensionamientoElectrico),
          );
      }
    }

    return EmptyState(
      title: 'No se pudo cargar la cotización',
      message: error.toString(),
      icon: Icons.error_outline,
    );
  }

  Future<void> _saveQuote({
    required String activeDraftId,
    required QuotationSummary summary,
    required double structureMaterialsCost,
    required bool structureMaterialsHasMissingPrices,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final input = _calculate(
        summary,
        structureMaterialsCost: structureMaterialsCost,
        structureMaterialsHasMissingPrices: structureMaterialsHasMissingPrices,
      );

      await ref.read(quotationCommercialRepositoryProvider).createQuoteVersion(
            quotationDraftId: activeDraftId,
            quote: input,
          );

      await ref.read(quotationDraftRepositoryProvider).updateLastCompletedStep(
            draftId: activeDraftId,
            step: QuotationDraftStep.commercialQuote,
          );

      ref.invalidate(quotationCommercialQuoteProvider(activeDraftId));
      ref.invalidate(quotationCommercialHistoryProvider(activeDraftId));
      ref.invalidate(quotationSummaryProvider(activeDraftId));
      ref.invalidate(quotationDraftsControllerProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nueva versión de la cotización guardada.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la cotización: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _acceptQuote(String activeDraftId) async {
    setState(() {
      _isAccepting = true;
    });

    try {
      await ref
          .read(quotationCommercialRepositoryProvider)
          .markCurrentAsAccepted(activeDraftId);

      ref.invalidate(quotationCommercialQuoteProvider(activeDraftId));
      ref.invalidate(quotationCommercialHistoryProvider(activeDraftId));
      ref.invalidate(quotationSummaryProvider(activeDraftId));
      ref.invalidate(quotationDraftsControllerProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cotización marcada como aceptada.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo marcar como aceptada: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  double? _parseDouble(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }
}

class _TechnicalSummary extends StatelessWidget {
  const _TechnicalSummary({required this.summary});

  final QuotationSummary summary;

  @override
  Widget build(BuildContext context) {
    final pv = summary.pvCalculation;
    final annualGenerationKwh =
        pv.generationPerPanelKwhDay * pv.requiredPanels * 365;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${pv.requiredPanels} × ${summary.panel.displayName}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          '${summary.requiredInverters} × ${summary.inverter.displayName}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Generación estimada anual: ${annualGenerationKwh.toStringAsFixed(0)} kWh',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CommercialInputs extends StatelessWidget {
  const _CommercialInputs({
    required this.utilityRateController,
    required this.panelUtilityRateController,
    required this.inverterUtilityRateController,
    required this.ivaRateController,
    required this.discountController,
    required this.advanceController,
    required this.paymentTermsController,
    required this.showAdvancedUtility,
    required this.onToggleAdvanced,
    required this.onChanged,
  });

  final TextEditingController utilityRateController;
  final TextEditingController panelUtilityRateController;
  final TextEditingController inverterUtilityRateController;
  final TextEditingController ivaRateController;
  final TextEditingController discountController;
  final TextEditingController advanceController;
  final TextEditingController paymentTermsController;
  final bool showAdvancedUtility;
  final VoidCallback onToggleAdvanced;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: utilityRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Utilidad general',
                  suffixText: '%',
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: ivaRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'IVA',
                  suffixText: '%',
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onToggleAdvanced,
            icon: Icon(
              showAdvancedUtility ? Icons.expand_less : Icons.expand_more,
            ),
            label: const Text('Utilidad por partida (avanzado)'),
          ),
        ),
        if (showAdvancedUtility) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: panelUtilityRateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Utilidad paneles',
                    suffixText: '%',
                    helperText: 'Vacío = usa la utilidad general',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: inverterUtilityRateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Utilidad inversor',
                    suffixText: '%',
                    helperText: 'Vacío = usa la utilidad general',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: discountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Descuento',
                  prefixText: r'$',
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: advanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Anticipo',
                  prefixText: r'$',
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: paymentTermsController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Esquema de pagos',
            helperText: 'Ej: 50% anticipo, 50% contra entrega e instalación',
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

class _QuoteHistory extends ConsumerWidget {
  const _QuoteHistory({required this.draftId});

  final String draftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(quotationCommercialHistoryProvider(draftId));
    final currencyFormatter = CurrencyFormatter();

    return historyAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Text('Error: $error'),
      data: (versions) {
        if (versions.isEmpty) {
          return const Text('Todavía no hay versiones guardadas.');
        }

        return Column(
          children: versions
              .map(
                (version) => Card(
                  elevation: 0,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  child: ListTile(
                    dense: true,
                    title: Text('Versión ${version.versionNumber}'),
                    subtitle: Text(
                      'Total: ${currencyFormatter.format(version.total)}'
                      '${version.isAccepted ? ' · Aceptada' : ''}',
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
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

class _StructureMaterialsPricing extends StatelessWidget {
  const _StructureMaterialsPricing({required this.lines});

  final List<PricedStructureLine> lines;

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = CurrencyFormatter();

    final includedTotal = lines.fold<double>(
      0,
      (sum, line) => sum + (line.lineTotalMxn ?? 0),
    );
    final hasMissingPrices = lines.any((line) => !line.hasPrice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines) ...[
          _StructureMaterialLineRow(
            line: line,
            currencyFormatter: currencyFormatter,
          ),
          const SizedBox(height: 8),
        ],
        const Divider(),
        Text(
          'Incluido en el total del cliente: '
          '${currencyFormatter.format(includedTotal)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (hasMissingPrices) ...[
          const SizedBox(height: 6),
          Text(
            'Hay líneas sin precio ("-"): no están incluidas en el total. '
            'Revisa el catálogo o captura el precio manualmente.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],
      ],
    );
  }
}

class _StructureMaterialLineRow extends StatelessWidget {
  const _StructureMaterialLineRow({
    required this.line,
    required this.currencyFormatter,
  });

  final PricedStructureLine line;
  final CurrencyFormatter currencyFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.label, style: theme.textTheme.bodyMedium),
              Text(
                line.quantityLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          line.hasPrice
              ? currencyFormatter.format(line.lineTotalMxn!)
              : '-',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: line.hasPrice ? null : theme.colorScheme.error,
          ),
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
