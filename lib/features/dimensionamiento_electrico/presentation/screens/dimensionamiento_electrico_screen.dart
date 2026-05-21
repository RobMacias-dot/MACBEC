import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/components/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../analisis_energetico/application/energy_analysis_controller.dart';
import '../../../catalogo_tecnico/application/inverter_catalog_controller.dart';
import '../../../catalogo_tecnico/application/panel_catalog_controller.dart';
import '../../../catalogo_tecnico/domain/entities/solar_panel.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../domain/electrical_dimensioning_rules.dart';

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
  AcConductorMaterial _acMaterial = AcConductorMaterial.copper;
  AcPhaseType _acPhaseType = AcPhaseType.bifasic;

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

                  _ensureSelectedInverter(result);

                  final selectedOption = _findOptionByInverterId(
                    result.options,
                    _selectedInverterId,
                  );

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
                        title: 'Base del dimensionamiento',
                        subtitle:
                            'Validación preliminar con panel real, potencia FV, Voc, Isc y MPPT.',
                        child: _DimensioningSummary(
                          result: result,
                          selectedPanel: selectedPanel,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (selectedOption != null)
                        SectionCard(
                          title: 'Inversor seleccionado',
                          subtitle:
                              'Esta opción se tomará como base para fusibles, cableado y protecciones.',
                          child: _SelectedInverterCard(
                            option: selectedOption,
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (selectedOption != null)
                        SectionCard(
                          title: 'Protección y cableado DC preliminar',
                          subtitle:
                              'Cálculo preliminar por string usando Isc del panel, fusible, calibre y número aproximado de conductores.',
                          child: _DcProtectionAndCableCard(
                            option: selectedOption,
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (selectedOption != null)
                        SectionCard(
                          title: 'Lado AC básico',
                          subtitle:
                              'Captura distancia, material y tensión para revisar conductor AC y caída de tensión preliminar.',
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
                      if (selectedOption != null)
                        SectionCard(
                          title: 'Snapshot técnico preliminar',
                          subtitle:
                              'Resumen congelable para revisar con el cliente o con el equipo técnico. En una fase posterior se guardará en SQLite/PDF.',
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
                      SectionCard(
                        title: 'Opciones de inversores',
                        subtitle:
                            'Toca una opción para seleccionarla. La recomendación prioriza uso razonable del inversor y compatibilidad eléctrica.',
                        child: Column(
                          children: [
                            for (final option in result.options) ...[
                              _DimensioningOptionTile(
                                option: option,
                                isSelected:
                                    option.inverter.id == _selectedInverterId,
                                onTap: () {
                                  setState(() {
                                    _selectedInverterId = option.inverter.id;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SectionCard(
                        title: 'Cierre de Fase 6',
                        subtitle:
                            'La fase técnica base queda lista para conectar estructura, cotización económica y PDF.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _InfoRow(
                              icon: Icons.check_circle_outline,
                              text:
                                  'Ya hay flujo completo: panel real, inversor, strings, fusible DC, cable DC, tubería, lado AC básico y snapshot técnico.',
                            ),
                            const SizedBox(height: 8),
                            const _InfoRow(
                              icon: Icons.save_outlined,
                              text:
                                  'El guardado permanente del snapshot se recomienda hacerlo cuando definamos la estructura final de cotización técnica/PDF.',
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: selectedOption == null
                                    ? null
                                    : () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Fase 6 cerrada a nivel funcional preliminar.',
                                            ),
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Marcar revisión técnica OK'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    context.go(AppRoutes.seleccionTecnica),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Editar selección técnica'),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  void _ensureSelectedInverter(ElectricalDimensioningResult result) {
    if (_selectedInverterId != null &&
        _findOptionByInverterId(result.options, _selectedInverterId) != null) {
      return;
    }

    _selectedInverterId = result.bestOption?.inverter.id;
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
        content: Text('Snapshot técnico copiado.'),
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
      'SNAPSHOT TÉCNICO PRELIMINAR MACBEC SOLAR',
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
        'Fusible DC preliminar: ${fuse.suggestedCommercialFuseAmps} A (${fuse.formulaLabel})',
      if (cable != null) 'Cable DC preliminar: ${cable.summaryLabel}',
      if (conduit != null)
        'Tubería DC preliminar: ${conduit.suggestedConduitTradeSize}',
      if (acRecommendation != null)
        'Cable AC preliminar: ${acRecommendation.summaryLabel}',
      if (acRecommendation != null)
        'Lado AC: ${acRecommendation.distanceMeters.toStringAsFixed(1)} m, ${acRecommendation.phaseType.label}, ${acRecommendation.voltage.toStringAsFixed(0)} V, ${acRecommendation.material.label}',
      'Nota: cálculo preliminar sujeto a validación normativa, datasheets completos, temperatura, canalización, caída de tensión y criterio técnico final.',
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
          icon: Icons.electrical_services_outlined,
          title: 'Compatibles completas',
          value: '${result.compatibleOptions.length}',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.fact_check_outlined,
          title: 'Voc / Isc panel',
          value:
              '${selectedPanel.voc?.toStringAsFixed(2) ?? '-'} V / ${selectedPanel.isc?.toStringAsFixed(2) ?? '-'} A',
        ),
      ],
    );
  }
}

class _SelectedInverterCard extends StatelessWidget {
  const _SelectedInverterCard({
    required this.option,
  });

  final ElectricalDimensioningOption option;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          icon: Icons.check_circle_outline,
          text: '${option.requiredInverters} × ${option.inverter.displayName}',
        ),
        const SizedBox(height: 8),
        _InfoRow(
          icon: Icons.speed_outlined,
          text:
              'Uso del inversor: ${option.inverterUsagePercent.toStringAsFixed(1)}%. Reserva disponible: ${option.reserveCapacityPercent.toStringAsFixed(1)}%.',
        ),
        const SizedBox(height: 8),
        _InfoRow(
          icon: Icons.bolt_outlined,
          text:
              'Capacidad FV total: ${option.totalPvCapacityWatts.toStringAsFixed(0)} W para ${option.totalPanelPowerWatts.toStringAsFixed(0)} W de paneles.',
        ),
        if (option.maxPanelsPerString != null) ...[
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.schema_outlined,
            text:
                'Máximo aproximado por string: ${option.maxPanelsPerString}. Strings requeridos: ${option.requiredStrings ?? '-'}.',
          ),
        ],
      ],
    );
  }
}

class _DcProtectionAndCableCard extends StatelessWidget {
  const _DcProtectionAndCableCard({
    required this.option,
  });

  final ElectricalDimensioningOption option;

  @override
  Widget build(BuildContext context) {
    final fuse = option.dcFuseRecommendation;
    final cable = option.dcCableRecommendation;
    final conduit = option.dcConduitRecommendation;

    if (fuse == null) {
      return const _InfoRow(
        icon: Icons.warning_amber_outlined,
        text:
            'No se puede calcular fusible, cable ni tubería porque el panel seleccionado no tiene Isc válido.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResultTile(
          icon: Icons.security_outlined,
          title: 'Fusible DC sugerido',
          value: '${fuse.suggestedCommercialFuseAmps} A',
          isMainResult: true,
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.calculate_outlined,
          title: 'Fórmula fusible',
          value: fuse.formulaLabel,
        ),
        if (cable != null) ...[
          const SizedBox(height: 10),
          _ResultTile(
            icon: Icons.cable_outlined,
            title: 'Cable DC preliminar',
            value: '${cable.suggestedAwg} AWG',
            isMainResult: true,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.electric_bolt_outlined,
            text:
                'Corriente de diseño: ${cable.designCurrentAmps.toStringAsFixed(2)} A. Ampacidad preliminar del cable: ${cable.ampacityAmps} A.',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.schema_outlined,
            text:
                '${cable.requiredStrings} string(s) × ${cable.conductorsPerString} conductores = ${cable.totalConductors} conductores DC aproximados.',
          ),
        ],
        if (conduit != null) ...[
          const SizedBox(height: 10),
          _ResultTile(
            icon: Icons.water_drop_outlined,
            title: 'Tubería preliminar',
            value: conduit.suggestedConduitTradeSize,
            isMainResult: true,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.info_outline,
            text: conduit.note,
          ),
        ],
        const SizedBox(height: 10),
        const _InfoRow(
          icon: Icons.warning_amber_outlined,
          text:
              'Cable y tubería son preliminares. Después se conectarán a las referencias técnicas reales de ampacidad y llenado.',
        ),
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
            title: 'Cable AC preliminar',
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
                'Corriente máxima de salida usada: ${acRecommendation.currentAmps.toStringAsFixed(2)} A. Ampacidad preliminar: ${acRecommendation.ampacityAmps} A.',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: acRecommendation.isVoltageDropOk
                ? Icons.check_circle_outline
                : Icons.warning_amber_outlined,
            text: acRecommendation.isVoltageDropOk
                ? 'La caída preliminar cumple el objetivo menor o igual a 3%.'
                : 'La caída preliminar supera 3%. Revisar calibre, distancia o configuración.',
          ),
        ],
        const SizedBox(height: 10),
        const _InfoRow(
          icon: Icons.info_outline,
          text:
              'Este lado AC es preliminar. Debe validarse con norma, temperatura, canalización, método de instalación y criterios finales de ingeniería.',
        ),
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
            text:
                'Fusible DC preliminar: ${fuse.suggestedCommercialFuseAmps} A.',
          ),
        ],
        if (dcCable != null) ...[
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.cable_outlined,
            text: 'Cable DC preliminar: ${dcCable.summaryLabel}.',
          ),
        ],
        if (conduit != null) ...[
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.water_drop_outlined,
            text:
                'Tubería DC preliminar: ${conduit.suggestedConduitTradeSize}.',
          ),
        ],
        if (acCable != null) ...[
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.bolt_outlined,
            text: 'Cable AC preliminar: ${acCable.summaryLabel}.',
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copiar snapshot técnico'),
          ),
        ),
      ],
    );
  }
}

class _DimensioningOptionTile extends StatelessWidget {
  const _DimensioningOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final ElectricalDimensioningOption option;
  final bool isSelected;
  final VoidCallback onTap;

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

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  foregroundColor: color,
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : option.isRecommendedUsage && option.isCompatible
                            ? Icons.recommend_outlined
                            : option.isCompatible
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.inverter.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isSelected)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'Seleccionado',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              option.statusLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _UsageBar(option: option),
            const SizedBox(height: 8),
            Text(
              [
                '${option.requiredInverters} inversor(es)',
                'Uso ${option.inverterUsagePercent.toStringAsFixed(1)}%',
                'Reserva ${option.reserveCapacityPercent.toStringAsFixed(1)}%',
                'Capacidad ${option.totalPvCapacityWatts.toStringAsFixed(0)} W',
                if (option.inverter.purchasePrice != null)
                  '\$${option.inverter.purchasePrice!.toStringAsFixed(2)} compra c/u',
              ].join(' • '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _TechnicalMiniSummary(option: option),
            if (option.dcFuseRecommendation != null ||
                option.dcCableRecommendation != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (option.dcFuseRecommendation != null)
                    'Fusible ${option.dcFuseRecommendation!.suggestedCommercialFuseAmps} A',
                  if (option.dcCableRecommendation != null)
                    'Cable ${option.dcCableRecommendation!.suggestedAwg} AWG',
                  if (option.dcConduitRecommendation != null)
                    'Tubería ${option.dcConduitRecommendation!.suggestedConduitTradeSize}',
                ].join(' • '),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (option.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final warning in option.warnings.take(2)) ...[
                Text(
                  '• $warning',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({
    required this.option,
  });

  final ElectricalDimensioningOption option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (option.inverterUsagePercent / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          option.usageLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
          ),
        ),
      ],
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
