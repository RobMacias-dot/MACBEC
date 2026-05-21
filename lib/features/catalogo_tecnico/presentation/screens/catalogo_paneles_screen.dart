import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../application/panel_catalog_controller.dart';
import '../../domain/entities/solar_panel.dart';

enum _PanelCatalogFilter {
  active,
  all,
  inactive,
  incomplete,
}

class CatalogoPanelesScreen extends ConsumerStatefulWidget {
  const CatalogoPanelesScreen({super.key});

  @override
  ConsumerState<CatalogoPanelesScreen> createState() =>
      _CatalogoPanelesScreenState();
}

class _CatalogoPanelesScreenState extends ConsumerState<CatalogoPanelesScreen> {
  final _searchController = TextEditingController();

  _PanelCatalogFilter _filter = _PanelCatalogFilter.active;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panelsAsync = ref.watch(panelsCatalogProvider);

    return AppScaffold(
      title: 'Catálogo de paneles',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => ref.invalidate(panelsCatalogProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPanelForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Panel'),
      ),
      child: panelsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => EmptyState(
          title: 'No se pudieron cargar los paneles',
          message: error.toString(),
          icon: Icons.error_outline,
        ),
        data: (panels) {
          if (panels.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyState(
                      title: 'Sin paneles registrados',
                      message:
                          'Agrega paneles reales con potencia, Voc, Isc, dimensiones y precio de compra.',
                      icon: Icons.solar_power_outlined,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _openPanelForm(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar primer panel'),
                    ),
                  ],
                ),
              ),
            );
          }

          final filteredPanels = _applyFilters(panels);

          final activeCount = panels.where((panel) => panel.isActive).length;
          final inactiveCount = panels.where((panel) => !panel.isActive).length;
          final incompleteCount =
              panels.where((panel) => !panel.hasRequiredTechnicalData).length;

          return ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              _PanelCatalogToolbar(
                searchController: _searchController,
                filter: _filter,
                totalCount: panels.length,
                visibleCount: filteredPanels.length,
                activeCount: activeCount,
                inactiveCount: inactiveCount,
                incompleteCount: incompleteCount,
                onSearchChanged: (_) {
                  setState(() {});
                },
                onClearSearch: () {
                  _searchController.clear();
                  setState(() {});
                },
                onFilterChanged: (filter) {
                  setState(() {
                    _filter = filter;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (filteredPanels.isEmpty)
                _FilteredEmptyPanelsView(
                  onClearFilters: () {
                    _searchController.clear();
                    setState(() {
                      _filter = _PanelCatalogFilter.all;
                    });
                  },
                )
              else
                for (final panel in filteredPanels) ...[
                  _PanelCard(
                    panel: panel,
                    onEdit: () => _openPanelForm(context, panel: panel),
                    onToggleActive: () => _togglePanelActive(context, panel),
                    onDelete: () => _confirmDeletePanel(context, panel),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }

  List<SolarPanel> _applyFilters(List<SolarPanel> panels) {
    final query = _searchController.text.trim().toLowerCase();

    Iterable<SolarPanel> filteredPanels = panels;

    switch (_filter) {
      case _PanelCatalogFilter.active:
        filteredPanels = filteredPanels.where((panel) => panel.isActive);
        break;
      case _PanelCatalogFilter.inactive:
        filteredPanels = filteredPanels.where((panel) => !panel.isActive);
        break;
      case _PanelCatalogFilter.incomplete:
        filteredPanels = filteredPanels.where(
          (panel) => !panel.hasRequiredTechnicalData,
        );
        break;
      case _PanelCatalogFilter.all:
        break;
    }

    if (query.isNotEmpty) {
      filteredPanels = filteredPanels.where((panel) {
        final searchableText = [
          panel.brand,
          panel.model,
          panel.powerWatts.toStringAsFixed(0),
          panel.voc?.toStringAsFixed(2) ?? '',
          panel.isc?.toStringAsFixed(2) ?? '',
        ].join(' ').toLowerCase();

        return searchableText.contains(query);
      });
    }

    return filteredPanels.toList();
  }

  void _openPanelForm(
    BuildContext context, {
    SolarPanel? panel,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _PanelFormSheet(
          panel: panel,
          onSave: (input) async {
            final repository = ref.read(panelCatalogRepositoryProvider);

            if (panel == null) {
              await repository.createPanel(input);
            } else {
              await repository.updatePanel(
                panelId: panel.id,
                input: input,
              );
            }

            ref.invalidate(panelsCatalogProvider);

            if (!context.mounted) return;

            Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  panel == null
                      ? 'Panel agregado correctamente.'
                      : 'Panel actualizado correctamente.',
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _togglePanelActive(
    BuildContext context,
    SolarPanel panel,
  ) async {
    await ref.read(panelCatalogRepositoryProvider).setPanelActive(
          panelId: panel.id,
          isActive: !panel.isActive,
        );

    ref.invalidate(panelsCatalogProvider);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          panel.isActive
              ? 'Panel desactivado del catálogo.'
              : 'Panel activado en el catálogo.',
        ),
      ),
    );
  }

  Future<void> _confirmDeletePanel(
    BuildContext context,
    SolarPanel panel,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar panel'),
          content: Text(
            '¿Deseas eliminar ${panel.displayName} del catálogo? Esta acción lo ocultará del catálogo activo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await ref.read(panelCatalogRepositoryProvider).softDeletePanel(panel.id);

    ref.invalidate(panelsCatalogProvider);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Panel eliminado del catálogo.'),
      ),
    );
  }
}

class _PanelCatalogToolbar extends StatelessWidget {
  const _PanelCatalogToolbar({
    required this.searchController,
    required this.filter,
    required this.totalCount,
    required this.visibleCount,
    required this.activeCount,
    required this.inactiveCount,
    required this.incompleteCount,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final _PanelCatalogFilter filter;
  final int totalCount;
  final int visibleCount;
  final int activeCount;
  final int inactiveCount;
  final int incompleteCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_PanelCatalogFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSearch = searchController.text.trim().isNotEmpty;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Buscar panel',
                hintText: 'Marca, modelo, potencia, Voc o Isc',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: hasSearch
                    ? IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: onClearSearch,
                        icon: const Icon(Icons.close),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Activos ($activeCount)'),
                  selected: filter == _PanelCatalogFilter.active,
                  onSelected: (_) {
                    onFilterChanged(_PanelCatalogFilter.active);
                  },
                ),
                ChoiceChip(
                  label: Text('Todos ($totalCount)'),
                  selected: filter == _PanelCatalogFilter.all,
                  onSelected: (_) {
                    onFilterChanged(_PanelCatalogFilter.all);
                  },
                ),
                ChoiceChip(
                  label: Text('Inactivos ($inactiveCount)'),
                  selected: filter == _PanelCatalogFilter.inactive,
                  onSelected: (_) {
                    onFilterChanged(_PanelCatalogFilter.inactive);
                  },
                ),
                ChoiceChip(
                  label: Text('Incompletos ($incompleteCount)'),
                  selected: filter == _PanelCatalogFilter.incomplete,
                  onSelected: (_) {
                    onFilterChanged(_PanelCatalogFilter.incomplete);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$visibleCount de $totalCount paneles visibles',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyPanelsView extends StatelessWidget {
  const _FilteredEmptyPanelsView({
    required this.onClearFilters,
  });

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const EmptyState(
            title: 'Sin resultados',
            message:
                'No hay paneles que coincidan con la búsqueda o el filtro seleccionado.',
            icon: Icons.search_off_outlined,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.panel,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final SolarPanel panel;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final details = <String>[
      '${panel.powerWatts.toStringAsFixed(0)} W',
      if (panel.voc != null) 'Voc ${panel.voc!.toStringAsFixed(2)} V',
      if (panel.isc != null) 'Isc ${panel.isc!.toStringAsFixed(2)} A',
      if (panel.lengthMm != null && panel.widthMm != null)
        '${panel.lengthMm!.toStringAsFixed(0)} × ${panel.widthMm!.toStringAsFixed(0)} mm',
      if (panel.purchasePrice != null)
        '\$${panel.purchasePrice!.toStringAsFixed(2)} compra',
    ];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: panel.isActive
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: panel.isActive
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  child: const Icon(Icons.solar_power_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        panel.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details.join(' • '),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(panel.isActive ? 'Activo' : 'Inactivo'),
                          ),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              panel.hasRequiredTechnicalData
                                  ? 'Datos técnicos completos'
                                  : 'Faltan datos técnicos',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: panel.isActive ? 'Desactivar' : 'Activar',
                  onPressed: onToggleActive,
                  icon: Icon(
                    panel.isActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Eliminar',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelFormSheet extends StatefulWidget {
  const _PanelFormSheet({
    required this.onSave,
    this.panel,
  });

  final SolarPanel? panel;
  final Future<void> Function(SaveSolarPanelInput input) onSave;

  @override
  State<_PanelFormSheet> createState() => _PanelFormSheetState();
}

class _PanelFormSheetState extends State<_PanelFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _powerController;
  late final TextEditingController _vocController;
  late final TextEditingController _iscController;
  late final TextEditingController _lengthController;
  late final TextEditingController _widthController;
  late final TextEditingController _thicknessController;
  late final TextEditingController _purchasePriceController;

  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final panel = widget.panel;

    _brandController = TextEditingController(text: panel?.brand ?? '');
    _modelController = TextEditingController(text: panel?.model ?? '');
    _powerController = TextEditingController(
      text: _formatNullableNumber(panel?.powerWatts),
    );
    _vocController = TextEditingController(
      text: _formatNullableNumber(panel?.voc),
    );
    _iscController = TextEditingController(
      text: _formatNullableNumber(panel?.isc),
    );
    _lengthController = TextEditingController(
      text: _formatNullableNumber(panel?.lengthMm),
    );
    _widthController = TextEditingController(
      text: _formatNullableNumber(panel?.widthMm),
    );
    _thicknessController = TextEditingController(
      text: _formatNullableNumber(panel?.thicknessMm),
    );
    _purchasePriceController = TextEditingController(
      text: _formatNullableNumber(panel?.purchasePrice),
    );

    _isActive = panel?.isActive ?? true;
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _powerController.dispose();
    _vocController.dispose();
    _iscController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _thicknessController.dispose();
    _purchasePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    final title = widget.panel == null ? 'Agregar panel' : 'Editar panel';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomPadding + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _brandController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  prefixIcon: Icon(Icons.factory_outlined),
                ),
                validator: (value) => _requiredTextValidator(
                  value,
                  'Captura la marca del panel.',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  prefixIcon: Icon(Icons.view_module_outlined),
                ),
                validator: (value) => _requiredTextValidator(
                  value,
                  'Captura el modelo del panel.',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _powerController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Potencia nominal',
                  suffixText: 'W',
                  prefixIcon: Icon(Icons.bolt_outlined),
                ),
                validator: (value) => _requiredPositiveNumberValidator(
                  value,
                  emptyMessage: 'Captura la potencia del panel.',
                  invalidMessage: 'Captura una potencia válida. Ejemplo: 550',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vocController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Voc',
                        suffixText: 'V',
                      ),
                      validator: (value) => _optionalPositiveNumberValidator(
                        value,
                        'Captura un Voc válido. Ejemplo: 49.90',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _iscController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Isc',
                        suffixText: 'A',
                      ),
                      validator: (value) => _optionalPositiveNumberValidator(
                        value,
                        'Captura un Isc válido. Ejemplo: 14.00',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lengthController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Largo',
                        suffixText: 'mm',
                      ),
                      validator: (value) => _optionalPositiveNumberValidator(
                        value,
                        'Captura un largo válido. Ejemplo: 2278',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _widthController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Ancho',
                        suffixText: 'mm',
                      ),
                      validator: (value) => _optionalPositiveNumberValidator(
                        value,
                        'Captura un ancho válido. Ejemplo: 1134',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _thicknessController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Espesor opcional',
                  suffixText: 'mm',
                  prefixIcon: Icon(Icons.straighten_outlined),
                ),
                validator: (value) => _optionalPositiveNumberValidator(
                  value,
                  'Captura un espesor válido. Ejemplo: 35',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purchasePriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Precio de compra',
                  prefixText: '\$ ',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) => _optionalPositiveNumberValidator(
                  value,
                  'Captura un precio válido. Ejemplo: 2150',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                title: const Text('Panel activo'),
                subtitle: const Text(
                  'Los paneles inactivos se conservan, pero no deberían usarse en nuevas cotizaciones.',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar panel',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final powerWatts = _parseFlexibleDouble(_powerController.text);

    if (powerWatts == null || powerWatts <= 0) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(
        SaveSolarPanelInput(
          brand: _brandController.text,
          model: _modelController.text,
          powerWatts: powerWatts,
          voc: _parseFlexibleDouble(_vocController.text),
          isc: _parseFlexibleDouble(_iscController.text),
          lengthMm: _parseFlexibleDouble(_lengthController.text),
          widthMm: _parseFlexibleDouble(_widthController.text),
          thicknessMm: _parseFlexibleDouble(_thicknessController.text),
          purchasePrice: _parseFlexibleDouble(_purchasePriceController.text),
          isActive: _isActive,
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

  String? _requiredTextValidator(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
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

  String? _optionalPositiveNumberValidator(
    String? value,
    String invalidMessage,
  ) {
    if (value == null || value.trim().isEmpty) {
      return null;
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
