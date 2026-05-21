import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../application/inverter_catalog_controller.dart';
import '../../domain/entities/solar_inverter.dart';

enum _InverterCatalogFilter {
  all,
  incomplete,
}

class CatalogoInversoresScreen extends ConsumerStatefulWidget {
  const CatalogoInversoresScreen({super.key});

  @override
  ConsumerState<CatalogoInversoresScreen> createState() =>
      _CatalogoInversoresScreenState();
}

class _CatalogoInversoresScreenState
    extends ConsumerState<CatalogoInversoresScreen> {
  final _searchController = TextEditingController();

  _InverterCatalogFilter _filter = _InverterCatalogFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invertersAsync = ref.watch(invertersCatalogProvider);

    return AppScaffold(
      title: 'Catálogo de inversores',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => ref.invalidate(invertersCatalogProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openInverterForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Inversor'),
      ),
      child: invertersAsync.when(
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyState(
                      title: 'Sin inversores registrados',
                      message:
                          'Importa inversores desde el Excel estándar o agrega uno manualmente.',
                      icon: Icons.electrical_services_outlined,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _openInverterForm(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar primer inversor'),
                    ),
                  ],
                ),
              ),
            );
          }

          final filteredInverters = _applyFilters(inverters);
          final incompleteCount = inverters
              .where((inverter) => !inverter.hasRequiredTechnicalData)
              .length;

          return ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              _InverterCatalogToolbar(
                searchController: _searchController,
                filter: _filter,
                totalCount: inverters.length,
                visibleCount: filteredInverters.length,
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
              if (filteredInverters.isEmpty)
                _FilteredEmptyInvertersView(
                  onClearFilters: () {
                    _searchController.clear();
                    setState(() {
                      _filter = _InverterCatalogFilter.all;
                    });
                  },
                )
              else
                for (final inverter in filteredInverters) ...[
                  _InverterCard(
                    inverter: inverter,
                    onEdit: () => _openInverterForm(
                      context,
                      inverter: inverter,
                    ),
                    onDelete: () => _confirmDeleteInverter(
                      context,
                      inverter,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }

  List<SolarInverter> _applyFilters(List<SolarInverter> inverters) {
    final query = _searchController.text.trim().toLowerCase();

    Iterable<SolarInverter> filteredInverters = inverters;

    switch (_filter) {
      case _InverterCatalogFilter.incomplete:
        filteredInverters = filteredInverters.where(
          (inverter) => !inverter.hasRequiredTechnicalData,
        );
        break;
      case _InverterCatalogFilter.all:
        break;
    }

    if (query.isNotEmpty) {
      filteredInverters = filteredInverters.where((inverter) {
        final searchableText = [
          inverter.brand,
          inverter.model,
          inverter.nominalPowerWatts.toStringAsFixed(0),
          inverter.maxPvPowerWatts?.toStringAsFixed(0) ?? '',
          inverter.maxDcVoltage?.toStringAsFixed(0) ?? '',
          inverter.mpptCount?.toString() ?? '',
        ].join(' ').toLowerCase();

        return searchableText.contains(query);
      });
    }

    return filteredInverters.toList();
  }

  void _openInverterForm(
    BuildContext context, {
    SolarInverter? inverter,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _InverterFormSheet(
          inverter: inverter,
          onSave: (input) async {
            final repository = ref.read(inverterCatalogRepositoryProvider);

            if (inverter == null) {
              await repository.createInverter(input);
            } else {
              await repository.updateInverter(
                inverterId: inverter.id,
                input: input,
              );
            }

            ref.invalidate(invertersCatalogProvider);

            if (!context.mounted) return;

            Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  inverter == null
                      ? 'Inversor agregado correctamente.'
                      : 'Inversor actualizado correctamente.',
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteInverter(
    BuildContext context,
    SolarInverter inverter,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar inversor'),
          content: Text(
            '¿Deseas eliminar ${inverter.displayName} del catálogo? Esta acción lo ocultará del catálogo local.',
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

    await ref
        .read(inverterCatalogRepositoryProvider)
        .softDeleteInverter(inverter.id);

    ref.invalidate(invertersCatalogProvider);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Inversor eliminado del catálogo.'),
      ),
    );
  }
}

class _InverterCatalogToolbar extends StatelessWidget {
  const _InverterCatalogToolbar({
    required this.searchController,
    required this.filter,
    required this.totalCount,
    required this.visibleCount,
    required this.incompleteCount,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final _InverterCatalogFilter filter;
  final int totalCount;
  final int visibleCount;
  final int incompleteCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_InverterCatalogFilter> onFilterChanged;

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
                labelText: 'Buscar inversor',
                hintText: 'Marca, modelo, potencia, voltaje o MPPT',
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
                  label: Text('Todos ($totalCount)'),
                  selected: filter == _InverterCatalogFilter.all,
                  onSelected: (_) {
                    onFilterChanged(_InverterCatalogFilter.all);
                  },
                ),
                ChoiceChip(
                  label: Text('Incompletos ($incompleteCount)'),
                  selected: filter == _InverterCatalogFilter.incomplete,
                  onSelected: (_) {
                    onFilterChanged(_InverterCatalogFilter.incomplete);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$visibleCount de $totalCount inversores visibles',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyInvertersView extends StatelessWidget {
  const _FilteredEmptyInvertersView({
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
                'No hay inversores que coincidan con la búsqueda o el filtro seleccionado.',
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

class _InverterCard extends StatelessWidget {
  const _InverterCard({
    required this.inverter,
    required this.onEdit,
    required this.onDelete,
  });

  final SolarInverter inverter;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final details = <String>[
      '${inverter.nominalPowerWatts.toStringAsFixed(0)} W nominal',
      if (inverter.maxPvPowerWatts != null)
        'FV máx. ${inverter.maxPvPowerWatts!.toStringAsFixed(0)} W',
      if (inverter.maxDcVoltage != null)
        'CD máx. ${inverter.maxDcVoltage!.toStringAsFixed(0)} V',
      if (inverter.maxShortCircuitCurrentPerMppt != null)
        'Isc MPPT ${inverter.maxShortCircuitCurrentPerMppt!.toStringAsFixed(2)} A',
      if (inverter.maxOutputCurrent != null)
        'Salida ${inverter.maxOutputCurrent!.toStringAsFixed(2)} A',
      if (inverter.mpptCount != null) '${inverter.mpptCount} MPPT',
      if (inverter.purchasePrice != null)
        '\$${inverter.purchasePrice!.toStringAsFixed(2)} compra',
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
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.electrical_services_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inverter.displayName,
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
                            label: Text(
                              inverter.hasRequiredTechnicalData
                                  ? 'Datos técnicos completos'
                                  : 'Faltan datos técnicos',
                            ),
                          ),
                          if (inverter.priceSource != null)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(inverter.priceSource!),
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

class _InverterFormSheet extends StatefulWidget {
  const _InverterFormSheet({
    required this.onSave,
    this.inverter,
  });

  final SolarInverter? inverter;
  final Future<void> Function(SaveSolarInverterInput input) onSave;

  @override
  State<_InverterFormSheet> createState() => _InverterFormSheetState();
}

class _InverterFormSheetState extends State<_InverterFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _nominalPowerController;
  late final TextEditingController _maxPvPowerController;
  late final TextEditingController _maxDcVoltageController;
  late final TextEditingController _maxShortCircuitCurrentPerMpptController;
  late final TextEditingController _maxOutputCurrentController;
  late final TextEditingController _mpptCountController;
  late final TextEditingController _purchasePriceController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final inverter = widget.inverter;

    _brandController = TextEditingController(text: inverter?.brand ?? '');
    _modelController = TextEditingController(text: inverter?.model ?? '');
    _nominalPowerController = TextEditingController(
      text: _formatNullableNumber(inverter?.nominalPowerWatts),
    );
    _maxPvPowerController = TextEditingController(
      text: _formatNullableNumber(inverter?.maxPvPowerWatts),
    );
    _maxDcVoltageController = TextEditingController(
      text: _formatNullableNumber(inverter?.maxDcVoltage),
    );
    _maxShortCircuitCurrentPerMpptController = TextEditingController(
      text: _formatNullableNumber(
        inverter?.maxShortCircuitCurrentPerMppt,
      ),
    );
    _maxOutputCurrentController = TextEditingController(
      text: _formatNullableNumber(inverter?.maxOutputCurrent),
    );
    _mpptCountController = TextEditingController(
      text: inverter?.mpptCount?.toString() ?? '',
    );
    _purchasePriceController = TextEditingController(
      text: _formatNullableNumber(inverter?.purchasePrice),
    );
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _nominalPowerController.dispose();
    _maxPvPowerController.dispose();
    _maxDcVoltageController.dispose();
    _maxShortCircuitCurrentPerMpptController.dispose();
    _maxOutputCurrentController.dispose();
    _mpptCountController.dispose();
    _purchasePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    final title =
        widget.inverter == null ? 'Agregar inversor' : 'Editar inversor';

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
                  'Captura la marca del inversor.',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  prefixIcon: Icon(Icons.electrical_services_outlined),
                ),
                validator: (value) => _requiredTextValidator(
                  value,
                  'Captura el modelo del inversor.',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nominalPowerController,
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
                  emptyMessage: 'Captura la potencia nominal.',
                  invalidMessage: 'Captura una potencia válida. Ejemplo: 6000',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxPvPowerController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Máxima potencia FV recomendada',
                  suffixText: 'W',
                  prefixIcon: Icon(Icons.solar_power_outlined),
                ),
                validator: (value) => _optionalPositiveNumberValidator(
                  value,
                  'Captura una potencia FV válida. Ejemplo: 9000',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _maxDcVoltageController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Voltaje CD máx.',
                        suffixText: 'V',
                      ),
                      validator: (value) => _optionalPositiveNumberValidator(
                        value,
                        'Captura un voltaje válido. Ejemplo: 500',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _mpptCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'MPPT',
                      ),
                      validator: (value) => _optionalPositiveIntValidator(
                        value,
                        'Captura un número de MPPT válido. Ejemplo: 2',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxShortCircuitCurrentPerMpptController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Corriente máx. corto circuito por MPPT',
                  suffixText: 'A',
                  prefixIcon: Icon(Icons.settings_input_component_outlined),
                ),
                validator: (value) => _optionalPositiveNumberValidator(
                  value,
                  'Captura una corriente válida. Ejemplo: 16',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxOutputCurrentController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Corriente máxima de salida',
                  suffixText: 'A',
                  prefixIcon: Icon(Icons.electric_bolt_outlined),
                ),
                validator: (value) => _optionalPositiveNumberValidator(
                  value,
                  'Captura una corriente válida. Ejemplo: 27.3',
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
                  'Captura un precio válido. Ejemplo: 12500',
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
                    _isSaving ? 'Guardando...' : 'Guardar inversor',
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

    final nominalPowerWatts =
        _parseFlexibleDouble(_nominalPowerController.text);

    if (nominalPowerWatts == null || nominalPowerWatts <= 0) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(
        SaveSolarInverterInput(
          brand: _brandController.text,
          model: _modelController.text,
          nominalPowerWatts: nominalPowerWatts,
          maxPvPowerWatts: _parseFlexibleDouble(_maxPvPowerController.text),
          maxDcVoltage: _parseFlexibleDouble(_maxDcVoltageController.text),
          maxShortCircuitCurrentPerMppt: _parseFlexibleDouble(
            _maxShortCircuitCurrentPerMpptController.text,
          ),
          maxOutputCurrent:
              _parseFlexibleDouble(_maxOutputCurrentController.text),
          mpptCount: _parseFlexibleInt(_mpptCountController.text),
          purchasePrice: _parseFlexibleDouble(_purchasePriceController.text),
          priceSource: widget.inverter?.priceSource ?? 'Captura manual',
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

  String? _optionalPositiveIntValidator(
    String? value,
    String invalidMessage,
  ) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsedValue = _parseFlexibleInt(value);

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

  int? _parseFlexibleInt(String value) {
    final parsedValue = _parseFlexibleDouble(value);

    if (parsedValue == null) return null;

    return parsedValue.round();
  }

  String _formatNullableNumber(double? value) {
    if (value == null) return '';

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}
