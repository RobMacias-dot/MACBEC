import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../analisis_energetico/application/energy_analysis_controller.dart';
import '../../../catalogo_tecnico/application/inverter_catalog_controller.dart';
import '../../../catalogo_tecnico/application/panel_catalog_controller.dart';
import '../../../catalogo_tecnico/domain/entities/solar_panel.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../../estructura/domain/structure_design_context.dart';
import '../../data/electrical_selection_repository.dart';
import '../../domain/electrical_dimensioning_rules.dart';
import '../../domain/entities/electrical_selection.dart';

class DimensionamientoElectricoScreen extends ConsumerStatefulWidget {
  const DimensionamientoElectricoScreen({super.key});

  @override
  ConsumerState<DimensionamientoElectricoScreen> createState() =>
      _DimensionamientoElectricoScreenState();
}

class _DimensionamientoElectricoScreenState
    extends ConsumerState<DimensionamientoElectricoScreen> {
  final _acDistanceController = TextEditingController(text: '17');
  final _acVoltageController = TextEditingController(text: '220');

  String? _selectedInverterId;
  String? _expandedInverterId;
  AcConductorMaterial _acMaterial = AcConductorMaterial.copper;
  AcPhaseType _acPhaseType = AcPhaseType.bifasic;
  bool _initializedFromPersisted = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _acDistanceController.dispose();
    _acVoltageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeDraftId = ref.watch(activeQuotationDraftIdProvider);

    if (activeDraftId == null) {
      return AppScaffold(
        title: 'Dimensionamiento eléctrico',
        child: _EmptyStateWithButton(
          title: 'No hay cotización activa',
          message:
              'Primero crea o selecciona una cotización provisional y guarda su análisis energético.',
          icon: Icons.electrical_services_outlined,
          buttonIcon: Icons.request_quote_outlined,
          buttonLabel: 'Ir a cotización',
          onPressed: () => context.go(AppRoutes.cotizacion),
        ),
      );
    }

    final pvCalculationAsync =
        ref.watch(quotationDraftPvCalculationProvider(activeDraftId));
    final panelsAsync = ref.watch(panelsCatalogProvider);
    final invertersAsync = ref.watch(invertersCatalogProvider);

    return AppScaffold(
      title: 'Dimensionamiento eléctrico',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () {
            ref.invalidate(quotationDraftPvCalculationProvider(activeDraftId));
            ref.invalidate(panelsCatalogProvider);
            ref.invalidate(invertersCatalogProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: pvCalculationAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => EmptyState(
          title: 'No se pudo cargar el cálculo FV',
          message: error.toString(),
          icon: Icons.error_outline,
        ),
        data: (pvCalculation) {
          if (pvCalculation == null) {
            return _EmptyStateWithButton(
              title: 'Falta análisis energético',
              message:
                  'Guarda primero el cálculo de consumo y número de paneles para poder dimensionar.',
              icon: Icons.analytics_outlined,
              buttonIcon: Icons.analytics_outlined,
              buttonLabel: 'Ir a análisis energético',
              onPressed: () => context.go(AppRoutes.analisisConsumo),
            );
          }

          return panelsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stackTrace) => EmptyState(
              title: 'No se pudieron cargar los paneles',
              message: error.toString(),
              icon: Icons.error_outline,
            ),
            data: (panels) {
              final selectedPanel = _findPanelById(
                panels,
                pvCalculation.panelId,
              );

              if (selectedPanel == null) {
                return _EmptyStateWithButton(
                  title: 'Falta selección técnica',
                  message:
                      'Primero selecciona el panel real del catálogo para poder validar Voc, Isc y MPPT.',
                  icon: Icons.fact_check_outlined,
                  buttonIcon: Icons.fact_check_outlined,
                  buttonLabel: 'Ir a selección técnica',
                  onPressed: () => context.go(AppRoutes.seleccionTecnica),
                );
              }

              return invertersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => EmptyState(
                  title: 'No se pudieron cargar los inversores',
                  message: error.toString(),
                  icon: Icons.error_outline,
                ),
                data: (inverters) {
                  if (inverters.isEmpty) {
                    return _EmptyStateWithButton(
                      title: 'Sin inversores en catálogo',
                      message:
                          'Importa inversores desde el Excel estándar o agrégalos manualmente antes de dimensionar.',
                      icon: Icons.electrical_services_outlined,
                      buttonIcon: Icons.electrical_services_outlined,
                      buttonLabel: 'Ir a catálogo de inversores',
                      onPressed: () => context.go(AppRoutes.catalogoInversores),
                    );
                  }

                  final result = ElectricalDimensioningRules.calculate(
                    ElectricalDimensioningInput(
                      requiredPanels: pvCalculation.requiredPanels,
                      panelPowerWatts: pvCalculation.panelPowerWatts,
                      selectedPanel: selectedPanel,
                      inverters: inverters,
                    ),
                  );

                  final persistedSelection = ref
                      .watch(electricalSelectionProvider(activeDraftId))
                      .valueOrNull;

                  if (!_initializedFromPersisted && persistedSelection != null) {
                    _initializedFromPersisted = true;
                    _selectedInverterId ??= persistedSelection.inverterId;
                    _acMaterial = _acMaterialFromKey(
                          persistedSelection.acMaterial,
                        ) ??
                        _acMaterial;
                    _acPhaseType = _acPhaseTypeFromKey(
                          persistedSelection.acPhaseType,
                        ) ??
                        _acPhaseType;

                    if (persistedSelection.acDistanceMeters != null) {
                      _acDistanceController.text =
                          persistedSelection.acDistanceMeters!
                              .toStringAsFixed(1);
                    }
                    if (persistedSelection.acVoltage != null) {
                      _acVoltageController.text =
                          persistedSelection.acVoltage!.toStringAsFixed(0);
                    }
                  }

                  final selectedOption = _findOptionByInverterId(
                    result.options,
                    _selectedInverterId,
                  );
                  final featuredOption = selectedOption ?? result.bestOption;
                  final compatibleCount = result.compatibleOptions.length;

                  final acInput = _buildAcInput();
                  final acRecommendation = selectedOption == null
                      ? null
                      : ElectricalDimensioningRules
                          .calculateAcCableRecommendation(
                          option: selectedOption,
                          input: acInput,
                        );

                  return ListView(
                    children: [
                      SectionCard(
                        title: 'Datos del sistema',
                        child: _DimensioningSummary(
                          result: result,
                          selectedPanel: selectedPanel,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SectionCard(
                        title: selectedOption == null
                            ? 'Inversor recomendado'
                            : 'Inversor seleccionado',
                        child: featuredOption == null
                            ? const _InfoRow(
                                icon: Icons.warning_amber_outlined,
                                text:
                                    'No hay opciones disponibles en el catálogo.',
                              )
                            : Column(
                                children: [
                                  _DimensioningOptionTile(
                                    option: featuredOption,
                                    isSelected: selectedOption != null,
                                    isExpanded: featuredOption.inverter.id ==
                                        _expandedInverterId,
                                    onToggleDetails: () {
                                      setState(() {
                                        _expandedInverterId =
                                            _expandedInverterId ==
                                                    featuredOption.inverter.id
                                                ? null
                                                : featuredOption.inverter.id;
                                      });
                                    },
                                    onSelect: selectedOption == null &&
                                            featuredOption.isCompatible
                                        ? () {
                                            setState(() {
                                              _selectedInverterId =
                                                  featuredOption.inverter.id;
                                              _expandedInverterId = null;
                                            });
                                            _persistSelection(
                                              activeDraftId: activeDraftId,
                                              inverterId:
                                                  featuredOption.inverter.id,
                                            );
                                          }
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _openInverterSelector(
                                        activeDraftId: activeDraftId,
                                        result: result,
                                      ),
                                      icon: Icon(
                                        selectedOption == null
                                            ? Icons.tune_outlined
                                            : Icons.swap_horiz_outlined,
                                      ),
                                      label: Text(
                                        selectedOption == null
                                            ? compatibleCount > 0
                                                ? 'Ver opciones compatibles ($compatibleCount)'
                                                : 'Ver opciones'
                                            : 'Cambiar inversor',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      if (selectedOption != null) ...[
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Protección y cableado DC',
                          child:
                              _DcProtectionAndCableCard(option: selectedOption),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Lado AC',
                          child: _AcSideCard(
                            distanceController: _acDistanceController,
                            voltageController: _acVoltageController,
                            material: _acMaterial,
                            phaseType: _acPhaseType,
                            recommendation: acRecommendation,
                            onDistanceChanged: (_) => setState(() {}),
                            onVoltageChanged: (_) => setState(() {}),
                            onMaterialChanged: (value) {
                              setState(() {
                                _acMaterial = value;
                              });
                            },
                            onPhaseTypeChanged: (value) {
                              setState(() {
                                _acPhaseType = value;
                                _acVoltageController.text =
                                    value.defaultVoltage.toStringAsFixed(0);
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Resumen técnico',
                          child: _TechnicalSnapshotCard(
                            selectedPanel: selectedPanel,
                            selectedOption: selectedOption,
                            acRecommendation: acRecommendation,
                            onCopy: () => _copySnapshot(
                              context: context,
                              selectedPanel: selectedPanel,
                              selectedOption: selectedOption,
                              acRecommendation: acRecommendation,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _saveSelectionAndContinue(
                                      activeDraftId: activeDraftId,
                                      selectedPanel: selectedPanel,
                                      selectedOption: selectedOption,
                                      result: result,
                                    ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.foundation_outlined),
                            label: Text(
                              _isSaving
                                  ? 'Guardando...'
                                  : 'Continuar a estructura',
                            ),
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

  void _persistSelection({
    required String activeDraftId,
    required String inverterId,
  }) {
    ref
        .read(electricalSelectionRepositoryProvider)
        .upsertDraftSelection(
          quotationDraftId: activeDraftId,
          selection: SaveElectricalSelectionInput(
            inverterId: inverterId,
            acDistanceMeters: _parseFlexibleDouble(_acDistanceController.text),
            acVoltage: _parseFlexibleDouble(_acVoltageController.text),
            acMaterial: _acMaterial.name,
            acPhaseType: _acPhaseType.name,
          ),
        )
        .then((_) {
      ref.invalidate(electricalSelectionProvider(activeDraftId));
    });
  }

  Future<void> _saveSelectionAndContinue({
    required String activeDraftId,
    required SolarPanel selectedPanel,
    required ElectricalDimensioningOption selectedOption,
    required ElectricalDimensioningResult result,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(electricalSelectionRepositoryProvider).upsertDraftSelection(
            quotationDraftId: activeDraftId,
            selection: SaveElectricalSelectionInput(
              inverterId: selectedOption.inverter.id,
              acDistanceMeters:
                  _parseFlexibleDouble(_acDistanceController.text),
              acVoltage: _parseFlexibleDouble(_acVoltageController.text),
              acMaterial: _acMaterial.name,
              acPhaseType: _acPhaseType.name,
            ),
          );

      ref.invalidate(electricalSelectionProvider(activeDraftId));

      if (!mounted) return;

      context.push(
        AppRoutes.estructura,
        extra: StructureDesignContext(
          panelName: selectedPanel.displayName,
          panelPowerWatts: selectedPanel.powerWatts,
          requiredPanels: result.requiredPanels,
          totalPvPowerWatts: result.totalPanelPowerWatts,
          panelLengthMm: selectedPanel.lengthMm,
          panelWidthMm: selectedPanel.widthMm,
          inverterName: selectedOption.inverter.displayName,
          inverterQuantity: selectedOption.requiredInverters,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar la selección eléctrica: $error'),
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

  AcConductorMaterial? _acMaterialFromKey(String? key) {
    if (key == null) return null;

    for (final value in AcConductorMaterial.values) {
      if (value.name == key) return value;
    }

    return null;
  }

  AcPhaseType? _acPhaseTypeFromKey(String? key) {
    if (key == null) return null;

    for (final value in AcPhaseType.values) {
      if (value.name == key) return value;
    }

    return null;
  }

  ElectricalAcInput _buildAcInput() {
    final voltage = _parseFlexibleDouble(_acVoltageController.text) ??
        _acPhaseType.defaultVoltage;

    return ElectricalAcInput(
      distanceMeters: _parseFlexibleDouble(_acDistanceController.text) ?? 0,
      material: _acMaterial,
      phaseType: _acPhaseType,
      voltage: voltage,
    );
  }

  Future<void> _openInverterSelector({
    required String activeDraftId,
    required ElectricalDimensioningResult result,
  }) async {
    final searchController = TextEditingController();
    var filter = _InverterFilter.recommended;
    String? expandedId = _selectedInverterId ?? result.bestOption?.inverter.id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final visibleOptions = _filteredInverterOptions(
              result: result,
              filter: filter,
              query: searchController.text,
            );

            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Seleccionar inversor',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar marca o modelo',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Recomendados'),
                          selected: filter == _InverterFilter.recommended,
                          onSelected: (_) => setModalState(() {
                            filter = _InverterFilter.recommended;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Compatibles'),
                          selected: filter == _InverterFilter.compatible,
                          onSelected: (_) => setModalState(() {
                            filter = _InverterFilter.compatible;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: filter == _InverterFilter.all,
                          onSelected: (_) => setModalState(() {
                            filter = _InverterFilter.all;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${visibleOptions.length} opción${visibleOptions.length == 1 ? '' : 'es'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visibleOptions.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay inversores para este filtro.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              itemCount: visibleOptions.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final option = visibleOptions[index];

                                return _DimensioningOptionTile(
                                  option: option,
                                  isSelected:
                                      option.inverter.id == _selectedInverterId,
                                  isExpanded: option.inverter.id == expandedId,
                                  onToggleDetails: () {
                                    setModalState(() {
                                      expandedId =
                                          expandedId == option.inverter.id
                                              ? null
                                              : option.inverter.id;
                                    });
                                  },
                                  onSelect: option.isCompatible
                                      ? () {
                                          setState(() {
                                            _selectedInverterId =
                                                option.inverter.id;
                                            _expandedInverterId = null;
                                          });
                                          _persistSelection(
                                            activeDraftId: activeDraftId,
                                            inverterId: option.inverter.id,
                                          );
                                          Navigator.of(sheetContext).pop();
                                        }
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
  }

  List<ElectricalDimensioningOption> _filteredInverterOptions({
    required ElectricalDimensioningResult result,
    required _InverterFilter filter,
    required String query,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final matched = result.options.where((option) {
      return normalizedQuery.isEmpty ||
          option.inverter.displayName.toLowerCase().contains(normalizedQuery);
    }).toList();

    switch (filter) {
      case _InverterFilter.recommended:
        final recommended = matched
            .where((option) => option.isCompatible && option.isRecommendedUsage)
            .toList();

        if (recommended.isNotEmpty) return recommended;

        final bestOption = result.bestOption;
        if (bestOption == null || !matched.contains(bestOption)) return [];
        return [bestOption];
      case _InverterFilter.compatible:
        return matched.where((option) => option.isCompatible).toList();
      case _InverterFilter.all:
        return matched;
    }
  }

  ElectricalDimensioningOption? _findOptionByInverterId(
    List<ElectricalDimensioningOption> options,
    String? inverterId,
  ) {
    if (inverterId == null) return null;

    for (final option in options) {
      if (option.inverter.id == inverterId) {
        return option;
      }
    }

    return null;
  }

  SolarPanel? _findPanelById(List<SolarPanel> panels, String? panelId) {
    if (panelId == null) return null;

    for (final panel in panels) {
      if (panel.id == panelId) {
        return panel;
      }
    }

    return null;
  }

  Future<void> _copySnapshot({
    required BuildContext context,
    required SolarPanel selectedPanel,
    required ElectricalDimensioningOption selectedOption,
    required AcCableRecommendation? acRecommendation,
  }) async {
    final lines = _buildSnapshotLines(
      selectedPanel: selectedPanel,
      selectedOption: selectedOption,
      acRecommendation: acRecommendation,
    );

    await Clipboard.setData(
      ClipboardData(
        text: lines.join('\n'),
      ),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resumen técnico copiado.'),
      ),
    );
  }

  List<String> _buildSnapshotLines({
    required SolarPanel selectedPanel,
    required ElectricalDimensioningOption selectedOption,
    required AcCableRecommendation? acRecommendation,
  }) {
    final fuse = selectedOption.dcFuseRecommendation;
    final cable = selectedOption.dcCableRecommendation;
    final conduit = selectedOption.dcConduitRecommendation;

    return [
      'RESUMEN TÉCNICO MACBEC SOLAR',
      'Panel: ${selectedPanel.displayName}',
      'Paneles requeridos: ${(selectedOption.totalPanelPowerWatts / selectedPanel.powerWatts).round()}',
      'Potencia FV total: ${selectedOption.totalPanelPowerWatts.toStringAsFixed(0)} W',
      'Voc/Isc panel: ${selectedPanel.voc?.toStringAsFixed(2) ?? '-'} V / ${selectedPanel.isc?.toStringAsFixed(2) ?? '-'} A',
      'Inversor: ${selectedOption.requiredInverters} x ${selectedOption.inverter.displayName}',
      'Uso inversor: ${selectedOption.inverterUsagePercent.toStringAsFixed(1)}%',
      'Reserva inversor: ${selectedOption.reserveCapacityPercent.toStringAsFixed(1)}%',
      'Paneles/string máx.: ${selectedOption.maxPanelsPerString ?? '-'}',
      'Strings requeridos: ${selectedOption.requiredStrings ?? '-'}',
      if (fuse != null)
        'Fusible DC: ${fuse.suggestedCommercialFuseAmps} A (${fuse.formulaLabel})',
      if (cable != null) 'Cable DC: ${cable.summaryLabel}',
      if (conduit != null) 'Tubería DC: ${conduit.suggestedConduitTradeSize}',
      if (acRecommendation != null)
        'Cable AC: ${acRecommendation.summaryLabel}',
      if (acRecommendation != null)
        'Lado AC: ${acRecommendation.distanceMeters.toStringAsFixed(1)} m, ${acRecommendation.phaseType.label}, ${acRecommendation.voltage.toStringAsFixed(0)} V, ${acRecommendation.material.label}',
      'Validar con fichas técnicas y criterios finales de ingeniería.',
    ];
  }

  double? _parseFlexibleDouble(String value) {
    var cleanValue = value.trim();

    if (cleanValue.isEmpty) return null;

    cleanValue = cleanValue.replaceAll(RegExp(r'[\$\s]'), '');

    if (cleanValue.contains(',') && cleanValue.contains('.')) {
      cleanValue = cleanValue.replaceAll(',', '');
    } else if (cleanValue.contains(',')) {
      cleanValue = cleanValue.replaceAll(',', '.');
    }

    return double.tryParse(cleanValue);
  }
}

class _EmptyStateWithButton extends StatelessWidget {
  const _EmptyStateWithButton({
    required this.title,
    required this.message,
    required this.icon,
    required this.buttonIcon,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final IconData icon;
  final IconData buttonIcon;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        EmptyState(
          title: title,
          message: message,
          icon: icon,
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(buttonIcon),
            label: Text(buttonLabel),
          ),
        ),
      ],
    );
  }
}

class _DimensioningSummary extends StatelessWidget {
  const _DimensioningSummary({
    required this.result,
    required this.selectedPanel,
  });

  final ElectricalDimensioningResult result;
  final SolarPanel selectedPanel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ResultTile(
          icon: Icons.solar_power_outlined,
          title: 'Panel seleccionado',
          value: selectedPanel.displayName,
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.grid_view_outlined,
          title: 'Paneles requeridos',
          value: '${result.requiredPanels}',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.bolt_outlined,
          title: 'Potencia total FV',
          value: '${result.totalPanelPowerWatts.toStringAsFixed(0)} W',
          isMainResult: true,
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.fact_check_outlined,
          title: 'Voc / Isc',
          value:
              '${selectedPanel.voc?.toStringAsFixed(2) ?? '-'} V / ${selectedPanel.isc?.toStringAsFixed(2) ?? '-'} A',
        ),
      ],
    );
  }
}

class _DcProtectionAndCableCard extends StatelessWidget {
  const _DcProtectionAndCableCard({required this.option});

  final ElectricalDimensioningOption option;

  @override
  Widget build(BuildContext context) {
    final fuse = option.dcFuseRecommendation;
    final cable = option.dcCableRecommendation;
    final conduit = option.dcConduitRecommendation;

    if (fuse == null) {
      return const _InfoRow(
        icon: Icons.warning_amber_outlined,
        text: 'Faltan datos del panel para calcular la protección DC.',
      );
    }

    return Column(
      children: [
        _ResultTile(
          icon: Icons.security_outlined,
          title: 'Fusible DC',
          value: '${fuse.suggestedCommercialFuseAmps} A',
          isMainResult: true,
        ),
        if (cable != null) ...[
          const SizedBox(height: 10),
          _ResultTile(
            icon: Icons.cable_outlined,
            title: 'Cable DC',
            value: '${cable.suggestedAwg} AWG',
          ),
        ],
        if (conduit != null) ...[
          const SizedBox(height: 10),
          _ResultTile(
            icon: Icons.water_drop_outlined,
            title: 'Tubería',
            value: conduit.suggestedConduitTradeSize,
          ),
        ],
      ],
    );
  }
}

class _AcSideCard extends StatelessWidget {
  const _AcSideCard({
    required this.distanceController,
    required this.voltageController,
    required this.material,
    required this.phaseType,
    required this.recommendation,
    required this.onDistanceChanged,
    required this.onVoltageChanged,
    required this.onMaterialChanged,
    required this.onPhaseTypeChanged,
  });

  final TextEditingController distanceController;
  final TextEditingController voltageController;
  final AcConductorMaterial material;
  final AcPhaseType phaseType;
  final AcCableRecommendation? recommendation;
  final ValueChanged<String> onDistanceChanged;
  final ValueChanged<String> onVoltageChanged;
  final ValueChanged<AcConductorMaterial> onMaterialChanged;
  final ValueChanged<AcPhaseType> onPhaseTypeChanged;

  @override
  Widget build(BuildContext context) {
    final acRecommendation = recommendation;

    return Column(
      children: [
        TextField(
          controller: distanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onDistanceChanged,
          decoration: const InputDecoration(
            labelText: 'Distancia inversor → centro de carga',
            suffixText: 'm',
            prefixIcon: Icon(Icons.straighten_outlined),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AcPhaseType>(
          initialValue: phaseType,
          decoration: const InputDecoration(
            labelText: 'Tipo de conexión AC',
            prefixIcon: Icon(Icons.electrical_services_outlined),
          ),
          items: [
            for (final value in AcPhaseType.values)
              DropdownMenuItem(
                value: value,
                child: Text(value.label),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            onPhaseTypeChanged(value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: voltageController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onVoltageChanged,
          decoration: const InputDecoration(
            labelText: 'Voltaje AC',
            suffixText: 'V',
            prefixIcon: Icon(Icons.bolt_outlined),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AcConductorMaterial>(
          initialValue: material,
          decoration: const InputDecoration(
            labelText: 'Material del conductor',
            prefixIcon: Icon(Icons.cable_outlined),
          ),
          items: [
            for (final value in AcConductorMaterial.values)
              DropdownMenuItem(
                value: value,
                child: Text(value.label),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            onMaterialChanged(value);
          },
        ),
        const SizedBox(height: 14),
        if (acRecommendation == null)
          const _InfoRow(
            icon: Icons.warning_amber_outlined,
            text:
                'No se puede calcular lado AC porque falta corriente máxima de salida del inversor o datos válidos de distancia/voltaje.',
          )
        else ...[
          _ResultTile(
            icon: Icons.cable_outlined,
            title: 'Cable AC',
            value: '${acRecommendation.suggestedAwg} AWG',
            isMainResult: true,
          ),
          const SizedBox(height: 10),
          _ResultTile(
            icon: Icons.percent_outlined,
            title: 'Caída de tensión',
            value: '${acRecommendation.voltageDropPercent.toStringAsFixed(2)}%',
            isMainResult: acRecommendation.isVoltageDropOk,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.electric_bolt_outlined,
            text:
                'Corriente máxima: ${acRecommendation.currentAmps.toStringAsFixed(2)} A · Ampacidad: ${acRecommendation.ampacityAmps} A.',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: acRecommendation.isVoltageDropOk
                ? Icons.check_circle_outline
                : Icons.warning_amber_outlined,
            text: acRecommendation.isVoltageDropOk
                ? 'Caída de tensión dentro del objetivo.'
                : 'La caída supera 3%. Revisa calibre o distancia.',
          ),
        ],
      ],
    );
  }
}

class _TechnicalSnapshotCard extends StatelessWidget {
  const _TechnicalSnapshotCard({
    required this.selectedPanel,
    required this.selectedOption,
    required this.acRecommendation,
    required this.onCopy,
  });

  final SolarPanel selectedPanel;
  final ElectricalDimensioningOption selectedOption;
  final AcCableRecommendation? acRecommendation;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final fuse = selectedOption.dcFuseRecommendation;
    final dcCable = selectedOption.dcCableRecommendation;
    final conduit = selectedOption.dcConduitRecommendation;
    final acCable = acRecommendation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          icon: Icons.solar_power_outlined,
          text:
              'Panel: ${selectedPanel.displayName} · ${selectedPanel.powerWatts.toStringAsFixed(0)} W',
        ),
        const SizedBox(height: 8),
        _InfoRow(
          icon: Icons.electrical_services_outlined,
          text:
              'Inversor: ${selectedOption.requiredInverters} × ${selectedOption.inverter.displayName}',
        ),
        const SizedBox(height: 8),
        _InfoRow(
          icon: Icons.speed_outlined,
          text:
              'Uso inversor: ${selectedOption.inverterUsagePercent.toStringAsFixed(1)}%. Reserva: ${selectedOption.reserveCapacityPercent.toStringAsFixed(1)}%.',
        ),
        if (fuse != null) ...[
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.security_outlined,
            text: 'Fusible DC: ${fuse.suggestedCommercialFuseAmps} A.',
          ),
        ],
        if (dcCable != null) ...[
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.cable_outlined,
            text: 'Cable DC: ${dcCable.summaryLabel}.',
          ),
        ],
        if (conduit != null) ...[
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.water_drop_outlined,
            text: 'Tubería DC: ${conduit.suggestedConduitTradeSize}.',
          ),
        ],
        if (acCable != null) ...[
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.bolt_outlined,
            text: 'Cable AC: ${acCable.summaryLabel}.',
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copiar resumen técnico'),
          ),
        ),
      ],
    );
  }
}

enum _InverterFilter {
  recommended,
  compatible,
  all,
}

class _DimensioningOptionTile extends StatelessWidget {
  const _DimensioningOptionTile({
    required this.option,
    required this.isSelected,
    required this.isExpanded,
    required this.onToggleDetails,
    required this.onSelect,
  });

  final ElectricalDimensioningOption option;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onToggleDetails;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = isSelected
        ? theme.colorScheme.primary
        : option.isRecommendedUsage && option.isCompatible
            ? theme.colorScheme.primary
            : option.isCompatible
                ? theme.colorScheme.tertiary
                : option.isPowerCompatible
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.error;

    final statusText = option.isCompatible
        ? 'Uso FV: ${option.inverterUsagePercent.toStringAsFixed(1)}% · ${option.usageLabel}'
        : option.statusLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: isSelected ? 0.9 : 0.25),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : option.isCompatible
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option.inverter.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isSelected)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label:
                      Text('Seleccionado', style: theme.textTheme.labelSmall),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!option.isCompatible && option.isPowerCompatible) ...[
            const SizedBox(height: 4),
            Text(
              'Uso FV: ${option.inverterUsagePercent.toStringAsFixed(1)}% · ${option.usageLabel}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (isExpanded) ...[
            const SizedBox(height: 12),
            _UsageBar(option: option),
            const SizedBox(height: 10),
            Text(
              [
                '${option.requiredInverters} inversor(es)',
                'Capacidad ${option.totalPvCapacityWatts.toStringAsFixed(0)} W',
                if (option.inverter.purchasePrice != null)
                  '\$${option.inverter.purchasePrice!.toStringAsFixed(2)} compra c/u',
              ].join(' • '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _TechnicalMiniSummary(option: option),
            if (option.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final warning in option.warnings.take(2))
                Text('• $warning', style: theme.textTheme.bodySmall),
            ],
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: onToggleDetails,
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(isExpanded ? 'Ocultar detalles' : 'Ver detalles'),
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: isSelected ? null : onSelect,
                child: Text(isSelected ? 'Seleccionado' : 'Seleccionar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.option});

  final ElectricalDimensioningOption option;

  @override
  Widget build(BuildContext context) {
    final progress = (option.inverterUsagePercent / 100).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 8,
      ),
    );
  }
}

class _TechnicalMiniSummary extends StatelessWidget {
  const _TechnicalMiniSummary({
    required this.option,
  });

  final ElectricalDimensioningOption option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final values = [
      'Paneles/string máx.: ${option.maxPanelsPerString?.toString() ?? '-'}',
      'Paralelos/MPPT máx.: ${option.maxParallelStringsPerMppt?.toString() ?? '-'}',
      'Capacidad paneles: ${option.totalStringCapacity?.toString() ?? '-'}',
      'Strings requeridos: ${option.requiredStrings?.toString() ?? '-'}',
    ];

    return Text(
      values.join(' • '),
      style: theme.textTheme.bodySmall,
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
