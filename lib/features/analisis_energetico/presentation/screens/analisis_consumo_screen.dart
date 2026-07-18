import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../../cotizaciones/domain/entities/quotation_draft.dart';
import '../../application/energy_analysis_controller.dart';
import '../../data/nasa_power_client.dart';
import '../../data/solar_radiation_repository.dart';
import '../../domain/entities/quotation_draft_consumption.dart';
import '../../domain/entities/quotation_draft_pv_calculation.dart';
import '../../domain/mexico_states.dart';

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
  String? _selectedState;
  bool _isLoadingRadiation = false;

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
    final pvCalculationAsync =
        ref.watch(quotationDraftPvCalculationProvider(activeDraftId));

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
              return pvCalculationAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => EmptyState(
                  title: 'No se pudo cargar el cálculo guardado',
                  message: error.toString(),
                  icon: Icons.error_outline,
                ),
                data: (savedPvCalculation) {
                  _prefillFormIfNeeded(
                    draft,
                    savedConsumptions,
                    savedPvCalculation,
                  );

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
                        title: 'Análisis energético',
                        subtitle:
                            'Captura consumos, horas solares pico y potencia estimada del panel. Después se elegirá un panel real en selección técnica.',
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              if (savedConsumptions.length > 1) ...[
                                _HistoricalConsumptionsNotice(
                                  periodsCount: savedConsumptions.length,
                                  onReplicate: _replicateFirstConsumption,
                                ),
                                const SizedBox(height: 14),
                              ] else if (draft.cfeCurrentPeriodKwh !=
                                  null) ...[
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
                                    helperText:
                                        'Captura kWh del recibo o historial.',
                                    suffixText: 'kWh',
                                    prefixIcon: const Icon(
                                      Icons.electric_meter_outlined,
                                    ),
                                  ),
                                  validator: (value) =>
                                      _optionalNumberValidator(
                                    value,
                                    invalidMessage:
                                        'Captura un consumo válido. Ejemplo: 385',
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              DropdownButtonFormField<String>(
                                initialValue: _selectedState,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Estado (para radiación solar)',
                                  prefixIcon: Icon(Icons.map_outlined),
                                ),
                                items: [
                                  for (final state in MexicoStates.values)
                                    DropdownMenuItem(
                                      value: state.name,
                                      child: Text(state.name),
                                    ),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedState = value);
                                },
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: (_selectedState == null ||
                                          _isLoadingRadiation)
                                      ? null
                                      : _loadPeakSunHoursForState,
                                  icon: _isLoadingRadiation
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.satellite_alt_outlined),
                                  label: Text(
                                    _isLoadingRadiation
                                        ? 'Consultando...'
                                        : 'Obtener horas solares del estado (NASA)',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _peakSunHoursController,
                                textInputAction: TextInputAction.next,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Horas solares pico',
                                  helperText:
                                      'Captura manual o desde NASA. Siempre editable.',
                                  suffixText: 'h',
                                  prefixIcon: Icon(Icons.wb_sunny_outlined),
                                ),
                                validator: (value) =>
                                    _requiredPositiveNumberValidator(
                                  value,
                                  emptyMessage:
                                      'Captura las horas solares pico.',
                                  invalidMessage:
                                      'Captura un valor válido. Ejemplo: 5.0',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _panelPowerController,
                                textInputAction: TextInputAction.done,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Potencia estimada del panel',
                                  helperText:
                                      'Selecciona después el modelo real del panel.',
                                  suffixText: 'W',
                                  prefixIcon: Icon(Icons.solar_power_outlined),
                                ),
                                validator: (value) =>
                                    _requiredPositiveNumberValidator(
                                  value,
                                  emptyMessage:
                                      'Captura la potencia del panel.',
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
                                  label: const Text(
                                    'Actualizar cálculo',
                                  ),
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
                                        ? 'Guardando análisis...'
                                        : 'Guardar análisis energético',
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
                          title: 'Resultado energético',
                          subtitle:
                              'Consumo y generación estimada del sistema.',
                          child: _CalculationResultView(result: _result!),
                        ),
                      ],
                      if (savedPvCalculation != null) ...[
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Continuar',
                          subtitle:
                              'El análisis energético está guardado. Selecciona el panel solar para continuar.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _InfoRow(
                                icon: Icons.fact_check_outlined,
                                text:
                                    'Selecciona un panel disponible del catálogo.',
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    context.go(AppRoutes.seleccionTecnica);
                                  },
                                  icon:
                                      const Icon(Icons.arrow_forward_outlined),
                                  label: const Text(
                                    'Continuar a selección técnica',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
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
    QuotationDraftPvCalculation? savedPvCalculation,
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

    _peakSunHoursController.text = _formatNullableNumber(
      savedPvCalculation?.peakSunHours ?? draft.analysisPeakSunHours ?? 5.0,
    );

    _panelPowerController.text = _formatNullableNumber(
      savedPvCalculation?.panelPowerWatts ??
          draft.analysisPanelPowerWatts ??
          550,
    );

    if (savedPvCalculation != null) {
      _result = _CalculationResult(
        annualConsumptionKwh: savedPvCalculation.annualConsumptionKwh,
        dailyConsumptionKwh: savedPvCalculation.dailyConsumptionKwh,
        peakSunHours: savedPvCalculation.peakSunHours,
        panelPowerWatts: savedPvCalculation.panelPowerWatts,
        lossFactor: savedPvCalculation.lossFactor,
        generationPerPanelKwhDay: savedPvCalculation.generationPerPanelKwhDay,
        requiredPanels: savedPvCalculation.requiredPanels,
      );
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

  _CalculationResult? _buildCalculationResultFromForm() {
    if (!_formKey.currentState!.validate()) return null;

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
      return null;
    }

    final dailyConsumptionKwh = annualConsumptionKwh / 365;
    final generationPerPanelKwhDay =
        (panelPowerWatts * peakSunHours * _lossFactor) / 1000;

    final requiredPanels = generationPerPanelKwhDay <= 0
        ? 0
        : max(1, (dailyConsumptionKwh / generationPerPanelKwhDay).ceil());

    return _CalculationResult(
      annualConsumptionKwh: annualConsumptionKwh,
      dailyConsumptionKwh: dailyConsumptionKwh,
      peakSunHours: peakSunHours,
      panelPowerWatts: panelPowerWatts,
      lossFactor: _lossFactor,
      generationPerPanelKwhDay: generationPerPanelKwhDay,
      requiredPanels: requiredPanels,
    );
  }

  Future<void> _loadPeakSunHoursForState() async {
    final stateName = _selectedState;
    if (stateName == null) return;

    setState(() {
      _isLoadingRadiation = true;
    });

    try {
      final repository = ref.read(solarRadiationRepositoryProvider);

      // Offline-first: si ya hay un valor guardado para el estado, se usa
      // directamente sin llamar a la red.
      final cached = await repository.getStateAverage(stateName);

      if (cached != null) {
        setState(() {
          _peakSunHoursController.text = cached.peakSunHours.toStringAsFixed(2);
        });
        _calculate();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se usó el valor guardado localmente.'),
          ),
        );
        return;
      }

      final location = MexicoStates.findByName(stateName);
      if (location == null) return;

      final annualPeakSunHours = await ref
          .read(nasaPowerClientProvider)
          .fetchAnnualPeakSunHours(
            latitude: location.latitude,
            longitude: location.longitude,
          );

      if (annualPeakSunHours == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay conexión o no se pudo consultar NASA. Captura las '
              'horas solares manualmente.',
            ),
          ),
        );
        return;
      }

      await repository.upsertStateAverage(
        stateName: stateName,
        peakSunHours: annualPeakSunHours,
        latitude: location.latitude,
        longitude: location.longitude,
      );

      setState(() {
        _peakSunHoursController.text = annualPeakSunHours.toStringAsFixed(2);
      });
      _calculate();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Horas solares obtenidas de NASA POWER y guardadas.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRadiation = false;
        });
      }
    }
  }

  void _calculate() {
    final result = _buildCalculationResultFromForm();

    if (result == null) return;

    setState(() {
      _result = result;
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
            'Captura al menos un consumo válido antes de guardar el análisis.',
          ),
        ),
      );
      return;
    }

    final calculationResult = _buildCalculationResultFromForm();

    if (calculationResult == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(energyAnalysisRepositoryProvider);

      await repository.replaceDraftConsumptions(
        quotationDraftId: activeDraftId,
        consumptions: consumptions,
      );

      await repository.updateDraftAnalysisSettings(
        quotationDraftId: activeDraftId,
        peakSunHours: calculationResult.peakSunHours,
        panelPowerWatts: calculationResult.panelPowerWatts,
      );

      await repository.upsertDraftPvCalculation(
        quotationDraftId: activeDraftId,
        calculation: SaveQuotationDraftPvCalculationInput(
          annualConsumptionKwh: calculationResult.annualConsumptionKwh,
          dailyConsumptionKwh: calculationResult.dailyConsumptionKwh,
          peakSunHours: calculationResult.peakSunHours,
          panelPowerWatts: calculationResult.panelPowerWatts,
          lossFactor: calculationResult.lossFactor,
          generationPerPanelKwhDay: calculationResult.generationPerPanelKwhDay,
          requiredPanels: calculationResult.requiredPanels,
        ),
      );

      setState(() {
        _result = calculationResult;
      });

      await ref.read(quotationDraftRepositoryProvider).updateLastCompletedStep(
            draftId: activeDraftId,
            step: QuotationDraftStep.energyAnalysis,
          );

      ref.invalidate(quotationDraftConsumptionsProvider(activeDraftId));
      ref.invalidate(quotationDraftPvCalculationProvider(activeDraftId));
      ref.invalidate(quotationDraftsControllerProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Análisis energético guardado correctamente.'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          icon: Icons.analytics_outlined,
          text: draft.prospectName,
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(details.join(' • ')),
        ],
        const SizedBox(height: 10),
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
                    ? '$savedConsumptionsCount consumos en historial'
                    : 'Sin historial de consumos',
              ),
            ),
            if (draft.hasEnergyAnalysisSettings)
              const Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.analytics_outlined),
                label: Text('Parámetros guardados'),
              ),
          ],
        ),
        if (draft.hasCompleteCfeReview) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.push(AppRoutes.reciboCfeRevision);
              },
              icon: const Icon(Icons.edit_document),
              label: const Text('Ver / editar datos CFE'),
            ),
          ),
        ],
      ],
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
    final periodText = billingPeriod == null || billingPeriod!.trim().isEmpty
        ? 'periodo capturado'
        : billingPeriod!.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          icon: Icons.electric_meter_outlined,
          text:
              '${kwh.toStringAsFixed(0)} kWh de $periodText se precargó en el periodo 1.',
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onReplicate,
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Replicar en los 6 periodos'),
        ),
      ],
    );
  }
}

/// Se muestra cuando ya hay varios periodos reales (del recibo CFE, tabla
/// de consumo histórico) precargados. A diferencia de
/// [_ImportedConsumptionNotice], aquí "Replicar" no llena huecos: sustituye
/// el detalle real por una estimación general, así que se dejan ambas
/// opciones claras para que el instalador elija.
class _HistoricalConsumptionsNotice extends StatelessWidget {
  const _HistoricalConsumptionsNotice({
    required this.periodsCount,
    required this.onReplicate,
  });

  final int periodsCount;
  final VoidCallback onReplicate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          icon: Icons.electric_meter_outlined,
          text:
              'Se precargaron $periodsCount periodos con el consumo real '
              'de tu recibo CFE (actual + historial). Puedes dejarlos así '
              'para un cálculo más preciso, o reemplazarlos por una '
              'estimación general.',
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onReplicate,
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Reemplazar por estimación general (replicar)'),
        ),
      ],
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
    required this.annualConsumptionKwh,
    required this.dailyConsumptionKwh,
    required this.peakSunHours,
    required this.panelPowerWatts,
    required this.lossFactor,
    required this.generationPerPanelKwhDay,
    required this.requiredPanels,
  });

  final double annualConsumptionKwh;
  final double dailyConsumptionKwh;
  final double peakSunHours;
  final double panelPowerWatts;
  final double lossFactor;
  final double generationPerPanelKwhDay;
  final int requiredPanels;
}
