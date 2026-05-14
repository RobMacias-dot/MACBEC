import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/components/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../../cotizaciones/domain/entities/quotation_draft.dart';
import '../../application/energy_analysis_controller.dart';
import '../../domain/entities/quotation_draft_consumption.dart';

class AnalisisConsumoScreen extends ConsumerStatefulWidget {
  const AnalisisConsumoScreen({super.key});

  @override
  ConsumerState<AnalisisConsumoScreen> createState() =>
      _AnalisisConsumoScreenState();
}

class _AnalisisConsumoScreenState extends ConsumerState<AnalisisConsumoScreen> {
  final _formKey = GlobalKey<FormState>();

  final List<TextEditingController> _consumptionControllers =
      List.generate(6, (_) => TextEditingController());

  final _peakSunHoursController = TextEditingController(text: '5.0');
  final _panelPowerController = TextEditingController(text: '550');

  String? _prefilledDraftId;
  _CalculationResult? _result;
  bool _isSaving = false;

  static const double _lossFactor = 0.80;

  @override
  void dispose() {
    for (final controller in _consumptionControllers) {
      controller.dispose();
    }

    _peakSunHoursController.dispose();
    _panelPowerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeDraftId = ref.watch(activeQuotationDraftIdProvider);

    if (activeDraftId == null) {
      return const AppScaffold(
        title: 'Análisis energético',
        child: EmptyState(
          title: 'No hay cotización activa',
          message:
              'Primero crea o selecciona un prospecto, agrega su recibo CFE y guarda la revisión.',
          icon: Icons.analytics_outlined,
        ),
      );
    }

    final draftsAsync = ref.watch(quotationDraftsControllerProvider);
    final consumptionsAsync =
        ref.watch(quotationDraftConsumptionsProvider(activeDraftId));

    return AppScaffold(
      title: 'Análisis energético',
      child: draftsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => EmptyState(
          title: 'No se pudo cargar el análisis',
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

          return consumptionsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stackTrace) => EmptyState(
              title: 'No se pudieron cargar los consumos',
              message: error.toString(),
              icon: Icons.error_outline,
            ),
            data: (savedConsumptions) {
              _prefillFormIfNeeded(draft, savedConsumptions);

              return ListView(
                children: [
                  SectionCard(
                    title: 'Prospecto activo',
                    subtitle:
                        'El análisis se calculará para este borrador de cotización.',
                    child: _DraftSummary(
                      draft: draft,
                      savedConsumptionsCount: savedConsumptions.length,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Consumos del recibo CFE',
                    subtitle:
                        'Captura hasta 6 periodos bimestrales. Estos consumos quedarán guardados localmente para reutilizarlos en la cotización.',
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (draft.cfeCurrentPeriodKwh != null) ...[
                            _ImportedConsumptionNotice(
                              kwh: draft.cfeCurrentPeriodKwh!,
                              billingPeriod: draft.cfeBillingPeriod,
                              onReplicate: _replicateFirstConsumption,
                            ),
                            const SizedBox(height: 14),
                          ],
                          for (int index = 0;
                              index < _consumptionControllers.length;
                              index++) ...[
                            TextFormField(
                              controller: _consumptionControllers[index],
                              textInputAction: TextInputAction.next,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Consumo periodo ${index + 1}',
                                helperText: index == 0 &&
                                        draft.cfeBillingPeriod != null &&
                                        draft.cfeBillingPeriod!
                                            .trim()
                                            .isNotEmpty
                                    ? 'Periodo capturado: ${draft.cfeBillingPeriod}'
                                    : 'Captura kWh del recibo o historial.',
                                suffixText: 'kWh',
                                prefixIcon: const Icon(
                                  Icons.electric_meter_outlined,
                                ),
                              ),
                              validator: (value) => _optionalNumberValidator(
                                value,
                                invalidMessage:
                                    'Captura un consumo válido. Ejemplo: 385',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _peakSunHoursController,
                            textInputAction: TextInputAction.next,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Horas solares pico',
                              helperText:
                                  'Valor estimado inicial. Después se tomará por estado/municipio.',
                              suffixText: 'h',
                              prefixIcon: Icon(Icons.wb_sunny_outlined),
                            ),
                            validator: (value) =>
                                _requiredPositiveNumberValidator(
                              value,
                              emptyMessage: 'Captura las horas solares pico.',
                              invalidMessage:
                                  'Captura un valor válido. Ejemplo: 5.0',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _panelPowerController,
                            textInputAction: TextInputAction.done,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Potencia del panel',
                              helperText:
                                  'Usa la potencia nominal del panel seleccionado o estimado.',
                              suffixText: 'W',
                              prefixIcon: Icon(Icons.solar_power_outlined),
                            ),
                            validator: (value) =>
                                _requiredPositiveNumberValidator(
                              value,
                              emptyMessage: 'Captura la potencia del panel.',
                              invalidMessage:
                                  'Captura una potencia válida. Ejemplo: 550',
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _calculate,
                              icon: const Icon(Icons.calculate_outlined),
                              label: const Text('Calcular sistema inicial'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () => _saveConsumptions(activeDraftId),
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
                                    ? 'Guardando consumos...'
                                    : 'Guardar consumos históricos',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'Resultado inicial',
                      subtitle:
                          'Este cálculo es una estimación preliminar para dimensionar la propuesta.',
                      child: _CalculationResultView(result: _result!),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const SectionCard(
                    title: 'Nota de esta fase',
                    subtitle:
                        'El cálculo visual todavía se guarda después. En este paso ya persistimos los consumos históricos.',
                    child: _InfoRow(
                      icon: Icons.info_outline,
                      text:
                          'En la siguiente fase guardaremos también el resultado del cálculo: consumo anual, consumo diario, generación por panel y paneles estimados.',
                    ),
                  ),
                ],
              );
            },
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

  void _prefillFormIfNeeded(
    QuotationDraft draft,
    List<QuotationDraftConsumption> savedConsumptions,
  ) {
    if (_prefilledDraftId == draft.id) return;

    for (final controller in _consumptionControllers) {
      controller.clear();
    }

    if (savedConsumptions.isNotEmpty) {
      for (final consumption in savedConsumptions) {
        final index = consumption.sortOrder;

        if (index >= 0 && index < _consumptionControllers.length) {
          _consumptionControllers[index].text =
              _formatNullableNumber(consumption.kwh);
        }
      }
    } else if (draft.cfeCurrentPeriodKwh != null) {
      _consumptionControllers.first.text =
          _formatNullableNumber(draft.cfeCurrentPeriodKwh);
    }

    _prefilledDraftId = draft.id;
  }

  void _replicateFirstConsumption() {
    final firstConsumption = _parseFlexibleDouble(
      _consumptionControllers.first.text,
    );

    if (firstConsumption == null || firstConsumption <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero captura un consumo válido en el periodo 1.',
          ),
        ),
      );
      return;
    }

    for (final controller in _consumptionControllers) {
      controller.text = _formatNullableNumber(firstConsumption);
    }

    _calculate();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final consumptions = _consumptionControllers
        .map((controller) => _parseFlexibleDouble(controller.text) ?? 0)
        .toList();

    final annualConsumptionKwh = consumptions.fold<double>(
      0,
      (previousValue, value) => previousValue + value,
    );

    final peakSunHours = _parseFlexibleDouble(_peakSunHoursController.text);
    final panelPowerWatts = _parseFlexibleDouble(_panelPowerController.text);

    if (annualConsumptionKwh <= 0 ||
        peakSunHours == null ||
        peakSunHours <= 0 ||
        panelPowerWatts == null ||
        panelPowerWatts <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Captura al menos un consumo y datos válidos del panel/radiación.',
          ),
        ),
      );
      return;
    }

    final dailyConsumptionKwh = annualConsumptionKwh / 365;
    final generationPerPanelKwhDay =
        (panelPowerWatts * peakSunHours * _lossFactor) / 1000;

    final requiredPanels = generationPerPanelKwhDay <= 0
        ? 0
        : max(1, (dailyConsumptionKwh / generationPerPanelKwhDay).ceil());

    setState(() {
      _result = _CalculationResult(
        consumptions: consumptions,
        annualConsumptionKwh: annualConsumptionKwh,
        dailyConsumptionKwh: dailyConsumptionKwh,
        peakSunHours: peakSunHours,
        panelPowerWatts: panelPowerWatts,
        lossFactor: _lossFactor,
        generationPerPanelKwhDay: generationPerPanelKwhDay,
        requiredPanels: requiredPanels,
      );
    });
  }

  Future<void> _saveConsumptions(String activeDraftId) async {
    if (!_formKey.currentState!.validate()) return;

    final consumptions = <SaveQuotationDraftConsumptionInput>[];

    for (int index = 0; index < _consumptionControllers.length; index++) {
      final kwh = _parseFlexibleDouble(_consumptionControllers[index].text);

      if (kwh == null || kwh <= 0) continue;

      consumptions.add(
        SaveQuotationDraftConsumptionInput(
          periodLabel: 'Periodo ${index + 1}',
          kwh: kwh,
          sortOrder: index,
        ),
      );
    }

    if (consumptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Captura al menos un consumo válido antes de guardar.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(energyAnalysisRepositoryProvider).replaceDraftConsumptions(
            quotationDraftId: activeDraftId,
            consumptions: consumptions,
          );

      ref.invalidate(quotationDraftConsumptionsProvider(activeDraftId));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consumos históricos guardados correctamente.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron guardar los consumos: $error'),
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

  String? _optionalNumberValidator(
    String? value, {
    required String invalidMessage,
  }) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsedValue = _parseFlexibleDouble(value);

    if (parsedValue == null || parsedValue < 0) {
      return invalidMessage;
    }

    return null;
  }

  String? _requiredPositiveNumberValidator(
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

class _DraftSummary extends StatelessWidget {
  const _DraftSummary({
    required this.draft,
    required this.savedConsumptionsCount,
  });

  final QuotationDraft draft;
  final int savedConsumptionsCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final details = <String>[
      if (draft.hasPhone) draft.phone!.trim(),
      if (draft.hasWhatsapp) 'WhatsApp: ${draft.whatsapp!.trim()}',
      if (draft.hasEmail) draft.email!.trim(),
      if (draft.hasAddress) draft.address!.trim(),
      if (draft.cfeTariff != null && draft.cfeTariff!.trim().isNotEmpty)
        'Tarifa: ${draft.cfeTariff!.trim()}',
      if (draft.cfeBillingPeriod != null &&
          draft.cfeBillingPeriod!.trim().isNotEmpty)
        'Periodo: ${draft.cfeBillingPeriod!.trim()}',
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
            Icons.analytics_outlined,
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
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (draft.cfeCurrentPeriodKwh != null)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.electric_meter_outlined),
                        label: Text(
                          'Consumo importado: ${draft.cfeCurrentPeriodKwh!.toStringAsFixed(0)} kWh',
                        ),
                      ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.save_outlined),
                      label: Text(
                        savedConsumptionsCount > 0
                            ? '$savedConsumptionsCount consumos guardados'
                            : 'Sin consumos guardados',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportedConsumptionNotice extends StatelessWidget {
  const _ImportedConsumptionNotice({
    required this.kwh,
    required this.billingPeriod,
    required this.onReplicate,
  });

  final double kwh;
  final String? billingPeriod;
  final VoidCallback onReplicate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final periodText = billingPeriod == null || billingPeriod!.trim().isEmpty
        ? 'periodo capturado'
        : billingPeriod!.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consumo importado del recibo',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${kwh.toStringAsFixed(0)} kWh de $periodText se precargó en el periodo 1.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onReplicate,
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Replicar en los 6 periodos'),
          ),
        ],
      ),
    );
  }
}

class _CalculationResultView extends StatelessWidget {
  const _CalculationResultView({required this.result});

  final _CalculationResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ResultTile(
          icon: Icons.summarize_outlined,
          title: 'Consumo anual',
          value: '${result.annualConsumptionKwh.toStringAsFixed(2)} kWh',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.today_outlined,
          title: 'Consumo diario',
          value: '${result.dailyConsumptionKwh.toStringAsFixed(2)} kWh/día',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.solar_power_outlined,
          title: 'Generación por panel',
          value:
              '${result.generationPerPanelKwhDay.toStringAsFixed(2)} kWh/día',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.grid_view_outlined,
          title: 'Paneles estimados',
          value: '${result.requiredPanels} paneles',
          isMainResult: true,
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.title,
    required this.value,
    this.isMainResult = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool isMainResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMainResult
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isMainResult
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
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

class _CalculationResult {
  const _CalculationResult({
    required this.consumptions,
    required this.annualConsumptionKwh,
    required this.dailyConsumptionKwh,
    required this.peakSunHours,
    required this.panelPowerWatts,
    required this.lossFactor,
    required this.generationPerPanelKwhDay,
    required this.requiredPanels,
  });

  final List<double> consumptions;
  final double annualConsumptionKwh;
  final double dailyConsumptionKwh;
  final double peakSunHours;
  final double panelPowerWatts;
  final double lossFactor;
  final double generationPerPanelKwhDay;
  final int requiredPanels;
}
