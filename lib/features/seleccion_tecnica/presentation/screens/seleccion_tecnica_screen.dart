import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/components/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../analisis_energetico/application/energy_analysis_controller.dart';
import '../../../analisis_energetico/domain/entities/quotation_draft_pv_calculation.dart';
import '../../../catalogo_tecnico/application/panel_catalog_controller.dart';
import '../../../catalogo_tecnico/domain/entities/solar_panel.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../domain/technical_selection_rules.dart';

class SeleccionTecnicaScreen extends ConsumerStatefulWidget {
  const SeleccionTecnicaScreen({super.key});

  @override
  ConsumerState<SeleccionTecnicaScreen> createState() =>
      _SeleccionTecnicaScreenState();
}

class _SeleccionTecnicaScreenState
    extends ConsumerState<SeleccionTecnicaScreen> {
  String? _selectedPanelId;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final activeDraftId = ref.watch(activeQuotationDraftIdProvider);

    if (activeDraftId == null) {
      return AppScaffold(
        title: 'Selección técnica',
        child: _EmptyStateWithButton(
          title: 'No hay cotización activa',
          message: 'Crea o selecciona una cotización para continuar.',
          icon: Icons.fact_check_outlined,
          buttonIcon: Icons.request_quote_outlined,
          buttonLabel: 'Ir a cotización',
          onPressed: () => context.go(AppRoutes.cotizacion),
        ),
      );
    }

    final pvCalculationAsync =
        ref.watch(quotationDraftPvCalculationProvider(activeDraftId));
    final panelsAsync = ref.watch(panelsCatalogProvider);

    return AppScaffold(
      title: 'Selección técnica',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () {
            ref.invalidate(quotationDraftPvCalculationProvider(activeDraftId));
            ref.invalidate(panelsCatalogProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: pvCalculationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          title: 'No se pudo cargar el análisis',
          message: error.toString(),
          icon: Icons.error_outline,
        ),
        data: (pvCalculation) {
          if (pvCalculation == null) {
            return _EmptyStateWithButton(
              title: 'Falta análisis energético',
              message:
                  'Guarda el cálculo energético para seleccionar un panel.',
              icon: Icons.analytics_outlined,
              buttonIcon: Icons.analytics_outlined,
              buttonLabel: 'Ir a análisis energético',
              onPressed: () => context.go(AppRoutes.analisisConsumo),
            );
          }

          return panelsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => EmptyState(
              title: 'No se pudieron cargar los paneles',
              message: error.toString(),
              icon: Icons.error_outline,
            ),
            data: (panels) {
              final activePanels =
                  panels.where((panel) => panel.isActive).toList();

              if (activePanels.isEmpty) {
                return _EmptyStateWithButton(
                  title: 'Sin paneles activos',
                  message: 'Agrega o importa paneles solares para continuar.',
                  icon: Icons.solar_power_outlined,
                  buttonIcon: Icons.solar_power_outlined,
                  buttonLabel: 'Ir a catálogo de paneles',
                  onPressed: () => context.go(AppRoutes.catalogoPaneles),
                );
              }

              _ensureSelectedPanel(
                pvCalculation: pvCalculation,
                panels: activePanels,
              );

              final selectedPanel = _findPanelById(
                activePanels,
                _selectedPanelId,
              );

              if (selectedPanel == null) {
                return _EmptyStateWithButton(
                  title: 'Panel no disponible',
                  message: 'Selecciona otro panel del catálogo.',
                  icon: Icons.warning_amber_outlined,
                  buttonIcon: Icons.solar_power_outlined,
                  buttonLabel: 'Ir a catálogo de paneles',
                  onPressed: () => context.go(AppRoutes.catalogoPaneles),
                );
              }

              final panelResult = TechnicalSelectionRules.calculatePanel(
                pvCalculation: pvCalculation,
                selectedPanel: selectedPanel,
              );

              return ListView(
                children: [
                  SectionCard(
                    title: 'Resultado energético',
                    child: _PvCalculationSummary(pvCalculation: pvCalculation),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Panel solar',
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPanelId,
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar panel',
                            prefixIcon: Icon(Icons.solar_power_outlined),
                          ),
                          items: [
                            for (final panel in activePanels)
                              DropdownMenuItem(
                                value: panel.id,
                                child: Text(
                                  '${panel.displayName} · ${panel.powerWatts.toStringAsFixed(0)} W',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedPanelId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        _SelectedPanelSummary(result: panelResult),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _saveAndContinue(
                                activeDraftId: activeDraftId,
                                pvCalculation: pvCalculation,
                                panelResult: panelResult,
                              ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_outlined),
                      label: Text(
                        _isSaving
                            ? 'Guardando...'
                            : 'Continuar al dimensionamiento eléctrico',
                      ),
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

  void _ensureSelectedPanel({
    required QuotationDraftPvCalculation pvCalculation,
    required List<SolarPanel> panels,
  }) {
    if (_selectedPanelId != null &&
        _findPanelById(panels, _selectedPanelId) != null) {
      return;
    }

    if (pvCalculation.panelId != null &&
        _findPanelById(panels, pvCalculation.panelId) != null) {
      _selectedPanelId = pvCalculation.panelId;
      return;
    }

    _selectedPanelId = panels.first.id;
  }

  SolarPanel? _findPanelById(List<SolarPanel> panels, String? panelId) {
    if (panelId == null) return null;

    for (final panel in panels) {
      if (panel.id == panelId) return panel;
    }

    return null;
  }

  Future<void> _saveAndContinue({
    required String activeDraftId,
    required QuotationDraftPvCalculation pvCalculation,
    required TechnicalPanelSelectionResult panelResult,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(energyAnalysisRepositoryProvider);

      await repository.updateDraftAnalysisSettings(
        quotationDraftId: activeDraftId,
        peakSunHours: panelResult.peakSunHours,
        panelPowerWatts: panelResult.panel.powerWatts,
      );

      await repository.upsertDraftPvCalculation(
        quotationDraftId: activeDraftId,
        calculation: SaveQuotationDraftPvCalculationInput(
          panelId: panelResult.panel.id,
          annualConsumptionKwh: pvCalculation.annualConsumptionKwh,
          dailyConsumptionKwh: pvCalculation.dailyConsumptionKwh,
          peakSunHours: panelResult.peakSunHours,
          panelPowerWatts: panelResult.panel.powerWatts,
          lossFactor: panelResult.lossFactor,
          generationPerPanelKwhDay: panelResult.generationPerPanelKwhDay,
          requiredPanels: panelResult.requiredPanels,
        ),
      );

      ref.invalidate(quotationDraftPvCalculationProvider(activeDraftId));
      ref.invalidate(quotationDraftsControllerProvider);

      if (!mounted) return;

      context.go(AppRoutes.dimensionamientoElectrico);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el panel seleccionado: $error'),
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
        EmptyState(title: title, message: message, icon: icon),
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

class _PvCalculationSummary extends StatelessWidget {
  const _PvCalculationSummary({required this.pvCalculation});

  final QuotationDraftPvCalculation pvCalculation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ResultTile(
          icon: Icons.summarize_outlined,
          title: 'Consumo anual',
          value: '${pvCalculation.annualConsumptionKwh.toStringAsFixed(2)} kWh',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.today_outlined,
          title: 'Consumo diario',
          value:
              '${pvCalculation.dailyConsumptionKwh.toStringAsFixed(2)} kWh/día',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.grid_view_outlined,
          title: 'Paneles estimados',
          value: '${pvCalculation.requiredPanels}',
        ),
      ],
    );
  }
}

class _SelectedPanelSummary extends StatelessWidget {
  const _SelectedPanelSummary({required this.result});

  final TechnicalPanelSelectionResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ResultTile(
          icon: Icons.solar_power_outlined,
          title: 'Potencia del panel',
          value: '${result.panel.powerWatts.toStringAsFixed(0)} W',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.bolt_outlined,
          title: 'Generación por panel',
          value:
              '${result.generationPerPanelKwhDay.toStringAsFixed(2)} kWh/día',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.grid_view_outlined,
          title: 'Paneles requeridos',
          value: '${result.requiredPanels}',
          isMainResult: true,
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.electric_bolt_outlined,
          title: 'Potencia FV total',
          value: '${result.totalPanelPowerWatts.toStringAsFixed(0)} W',
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
          Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
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
