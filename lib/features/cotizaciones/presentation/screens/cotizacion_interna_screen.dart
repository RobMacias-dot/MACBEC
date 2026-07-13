import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/formatters/currency_formatter.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../application/quotation_draft_controller.dart';
import '../../application/quotation_summary_provider.dart';
import '../../data/quotation_commercial_repository.dart';
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
  final _ivaRateController = TextEditingController();
  final _discountController = TextEditingController();
  final _advanceController = TextEditingController();
  final _currencyFormatter = CurrencyFormatter();

  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _utilityRateController.dispose();
    _ivaRateController.dispose();
    _discountController.dispose();
    _advanceController.dispose();
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

          return ListView(
            children: [
              SectionCard(
                title: 'Resumen técnico',
                child: _TechnicalSummary(summary: summary),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Parámetros comerciales',
                child: _CommercialInputs(
                  utilityRateController: _utilityRateController,
                  ivaRateController: _ivaRateController,
                  discountController: _discountController,
                  advanceController: _advanceController,
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Desglose interno',
                subtitle: 'Costos, utilidad y margen (no visibles al cliente).',
                child: _buildBreakdown(summary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _saveQuote(
                            activeDraftId: activeDraftId,
                            summary: summary,
                          ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar cotización'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: summary.commercialQuote == null
                      ? null
                      : () => context.push(AppRoutes.cotizacionClientePreview),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Ir a vista de cliente / PDF'),
                ),
              ),
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
    _ivaRateController.text =
        (quote?.ivaRatePercent ?? summary.commercialSettings.ivaRatePercent)
            .toStringAsFixed(2);
    _discountController.text = (quote?.discountAmount ?? 0).toStringAsFixed(2);
    _advanceController.text =
        (quote?.advancePaymentAmount ?? 0).toStringAsFixed(2);
  }

  Widget _buildBreakdown(QuotationSummary summary) {
    final input = QuotationCommercialCalculator.calculate(
      panel: summary.panel,
      panelQuantity: summary.pvCalculation.requiredPanels,
      inverter: summary.inverter,
      inverterQuantity: summary.requiredInverters,
      generalUtilityRatePercent: _parseDouble(_utilityRateController.text) ??
          summary.commercialSettings.generalUtilityRatePercent,
      ivaRatePercent: _parseDouble(_ivaRateController.text) ??
          summary.commercialSettings.ivaRatePercent,
      discountAmount: _parseDouble(_discountController.text) ?? 0,
      advancePaymentAmount: _parseDouble(_advanceController.text) ?? 0,
      currency: summary.commercialSettings.currency,
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
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final input = QuotationCommercialCalculator.calculate(
        panel: summary.panel,
        panelQuantity: summary.pvCalculation.requiredPanels,
        inverter: summary.inverter,
        inverterQuantity: summary.requiredInverters,
        generalUtilityRatePercent: _parseDouble(_utilityRateController.text) ??
            summary.commercialSettings.generalUtilityRatePercent,
        ivaRatePercent: _parseDouble(_ivaRateController.text) ??
            summary.commercialSettings.ivaRatePercent,
        discountAmount: _parseDouble(_discountController.text) ?? 0,
        advancePaymentAmount: _parseDouble(_advanceController.text) ?? 0,
        currency: summary.commercialSettings.currency,
      );

      await ref
          .read(quotationCommercialRepositoryProvider)
          .upsertDraftQuote(quotationDraftId: activeDraftId, quote: input);

      ref.invalidate(quotationCommercialQuoteProvider(activeDraftId));
      ref.invalidate(quotationSummaryProvider(activeDraftId));
      ref.invalidate(quotationDraftsControllerProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cotización guardada.')),
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
    required this.ivaRateController,
    required this.discountController,
    required this.advanceController,
    required this.onChanged,
  });

  final TextEditingController utilityRateController;
  final TextEditingController ivaRateController;
  final TextEditingController discountController;
  final TextEditingController advanceController;
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
        const SizedBox(height: 12),
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
      ],
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
