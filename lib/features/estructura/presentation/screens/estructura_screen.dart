import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/components/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/structure_design_context.dart';
import '../../domain/structure_design_rules.dart';

class EstructuraScreen extends StatefulWidget {
  const EstructuraScreen({
    super.key,
    this.designContext,
  });

  final StructureDesignContext? designContext;

  @override
  State<EstructuraScreen> createState() => _EstructuraScreenState();
}

class _EstructuraScreenState extends State<EstructuraScreen> {
  late final TextEditingController _structuresCountController;
  late final TextEditingController _panelsHorizontalController;
  late final TextEditingController _panelRowsController;
  final _inclinationController = TextEditingController(text: '20');
  final _frontLegController = TextEditingController(text: '20');

  StructureMountType _mountType = StructureMountType.inclinedFlatRoof;
  StructureFixingType _fixingType = StructureFixingType.chemicalAnchor;

  @override
  void initState() {
    super.initState();

    final requiredPanels = widget.designContext?.requiredPanels ?? 1;
    final defaultHorizontal = min(requiredPanels, 11);
    final structures = requiredPanels > 22 ? 2 : 1;
    final rows = (requiredPanels / (defaultHorizontal * structures)).ceil();

    _structuresCountController = TextEditingController(text: '$structures');
    _panelsHorizontalController =
        TextEditingController(text: '$defaultHorizontal');
    _panelRowsController = TextEditingController(text: '${max(rows, 1)}');
  }

  @override
  void dispose() {
    _structuresCountController.dispose();
    _panelsHorizontalController.dispose();
    _panelRowsController.dispose();
    _inclinationController.dispose();
    _frontLegController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final designContext = widget.designContext;

    if (designContext == null) {
      return AppScaffold(
        title: 'Diseño de estructura',
        child: _EmptyStateWithButton(
          title: 'Falta dimensionamiento eléctrico',
          message:
              'Selecciona panel e inversor para comenzar el diseño de estructura.',
          icon: Icons.foundation_outlined,
          buttonLabel: 'Ir a dimensionamiento eléctrico',
          onPressed: () => context.go(AppRoutes.dimensionamientoElectrico),
        ),
      );
    }

    final result = _calculate(designContext);

    return AppScaffold(
      title: 'Diseño de estructura',
      child: ListView(
        children: [
          SectionCard(
            title: 'Sistema fotovoltaico',
            child: _SystemSummary(designContext: designContext),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Tipo de montaje',
            child: Column(
              children: [
                for (final mountType in StructureMountType.values) ...[
                  _MountTypeTile(
                    type: mountType,
                    selected: mountType == _mountType,
                    onTap: () => _selectMountType(mountType),
                  ),
                  if (mountType != StructureMountType.values.last)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          if (_mountType.isAvailable) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Configuración',
              child: _ConfigurationForm(
                structuresCountController: _structuresCountController,
                panelsHorizontalController: _panelsHorizontalController,
                panelRowsController: _panelRowsController,
                inclinationController: _inclinationController,
                frontLegController: _frontLegController,
                fixingType: _fixingType,
                onChanged: () => setState(() {}),
                onFixingChanged: (value) {
                  setState(() {
                    _fixingType = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Distribución de módulos',
              child: result == null
                  ? const _MessageRow(
                      icon: Icons.edit_outlined,
                      text: 'Captura los datos de la estructura para calcular.',
                    )
                  : _DistributionResult(result: result),
            ),
            if (result != null && designContext.hasPanelDimensions) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: 'Plano preliminar',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SideViewDiagram(result: result),
                    const SizedBox(height: 14),
                    _GeometrySummary(result: result),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Materiales estimados',
                trailing: const Chip(label: Text('Por costear')),
                child: _MaterialSummary(
                  result: result,
                  fixingType: _fixingType,
                ),
              ),
            ] else if (result != null) ...[
              const SizedBox(height: 16),
              const SectionCard(
                title: 'Plano preliminar',
                child: _MessageRow(
                  icon: Icons.warning_amber_outlined,
                  text:
                      'El panel seleccionado no tiene dimensiones cargadas en el catálogo.',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _selectMountType(StructureMountType mountType) {
    if (!mountType.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${mountType.label} estará disponible próximamente.'),
        ),
      );
      return;
    }

    setState(() {
      _mountType = mountType;
    });
  }

  InclinedFlatRoofResult? _calculate(StructureDesignContext contextData) {
    if (!contextData.hasPanelDimensions) return null;

    final structuresCount = _parseInt(_structuresCountController.text);
    final panelsHorizontal = _parseInt(_panelsHorizontalController.text);
    final panelRows = _parseInt(_panelRowsController.text);
    final inclination = _parseDouble(_inclinationController.text);
    final frontLeg = _parseDouble(_frontLegController.text);

    if (structuresCount == null ||
        panelsHorizontal == null ||
        panelRows == null ||
        inclination == null ||
        frontLeg == null ||
        structuresCount <= 0 ||
        panelsHorizontal <= 0 ||
        panelRows <= 0 ||
        inclination <= 0 ||
        inclination >= 90 ||
        frontLeg <= 0) {
      return null;
    }

    return StructureDesignRules.calculateInclinedFlatRoof(
      InclinedFlatRoofInput(
        requiredPanels: contextData.requiredPanels,
        structuresCount: structuresCount,
        panelsHorizontal: panelsHorizontal,
        panelRows: panelRows,
        panelLengthMm: contextData.panelLengthMm!,
        panelWidthMm: contextData.panelWidthMm!,
        inclinationDegrees: inclination,
        frontLegCm: frontLeg,
      ),
    );
  }

  int? _parseInt(String value) => int.tryParse(value.trim());

  double? _parseDouble(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }
}

class _SystemSummary extends StatelessWidget {
  const _SystemSummary({required this.designContext});

  final StructureDesignContext designContext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ResultTile(
          icon: Icons.solar_power_outlined,
          title: 'Panel',
          value: designContext.panelName,
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.grid_view_outlined,
          title: 'Módulos requeridos',
          value: '${designContext.requiredPanels}',
          isMainResult: true,
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.bolt_outlined,
          title: 'Potencia total FV',
          value: '${designContext.totalPvPowerWatts.toStringAsFixed(0)} W',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.electrical_services_outlined,
          title: 'Inversor',
          value:
              '${designContext.inverterQuantity} × ${designContext.inverterName}',
        ),
        if (designContext.hasPanelDimensions) ...[
          const SizedBox(height: 10),
          _ResultTile(
            icon: Icons.straighten_outlined,
            title: 'Dimensiones del módulo',
            value:
                '${(designContext.panelLengthMm! / 1000).toStringAsFixed(2)} × ${(designContext.panelWidthMm! / 1000).toStringAsFixed(2)} m',
          ),
        ],
      ],
    );
  }
}

class _MountTypeTile extends StatelessWidget {
  const _MountTypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final StructureMountType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = type.isAvailable;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(type.description, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(enabled ? 'Disponible' : 'Próximamente'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigurationForm extends StatelessWidget {
  const _ConfigurationForm({
    required this.structuresCountController,
    required this.panelsHorizontalController,
    required this.panelRowsController,
    required this.inclinationController,
    required this.frontLegController,
    required this.fixingType,
    required this.onChanged,
    required this.onFixingChanged,
  });

  final TextEditingController structuresCountController;
  final TextEditingController panelsHorizontalController;
  final TextEditingController panelRowsController;
  final TextEditingController inclinationController;
  final TextEditingController frontLegController;
  final StructureFixingType fixingType;
  final VoidCallback onChanged;
  final ValueChanged<StructureFixingType> onFixingChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _NumberField(
                controller: structuresCountController,
                label: 'Estructuras',
                icon: Icons.view_in_ar_outlined,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                controller: inclinationController,
                label: 'Inclinación',
                suffix: '°',
                icon: Icons.show_chart_outlined,
                decimal: true,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                controller: panelsHorizontalController,
                label: 'Horizontales',
                icon: Icons.view_column_outlined,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                controller: panelRowsController,
                label: 'Niveles',
                icon: Icons.view_agenda_outlined,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _NumberField(
          controller: frontLegController,
          label: 'Pata delantera',
          suffix: 'cm',
          icon: Icons.height_outlined,
          decimal: true,
          onChanged: onChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<StructureFixingType>(
          initialValue: fixingType,
          decoration: const InputDecoration(
            labelText: 'Fijación',
            prefixIcon: Icon(Icons.hardware_outlined),
          ),
          items: [
            for (final value in StructureFixingType.values)
              DropdownMenuItem(
                value: value,
                child: Text(value.label),
              ),
          ],
          onChanged: (value) {
            if (value != null) onFixingChanged(value);
          },
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.suffix,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final VoidCallback onChanged;
  final String? suffix;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _DistributionResult extends StatelessWidget {
  const _DistributionResult({required this.result});

  final InclinedFlatRoofResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exact = result.hasExactPanelDistribution;
    final color = exact ? theme.colorScheme.primary : theme.colorScheme.error;
    final difference = result.panelDifference;
    final message = exact
        ? 'La distribución coincide con los módulos requeridos.'
        : difference > 0
            ? 'Sobran $difference módulos en la distribución.'
            : 'Faltan ${difference.abs()} módulos por distribuir.';

    return Column(
      children: [
        _ResultTile(
          icon: Icons.dashboard_outlined,
          title: 'Módulos por estructura',
          value:
              '${result.panelsHorizontal} × ${result.panelRows} = ${result.modulesPerStructure}',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.grid_view_outlined,
          title: 'Total distribuido',
          value:
              '${result.totalDistributedPanels} / ${result.requiredPanels}',
          isMainResult: exact,
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.foundation_outlined,
          title: 'Filas de patas',
          value:
              '${result.supportRowCount} filas · ${result.supportPointsPerRow} patas por fila',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.height_outlined,
          title: 'Patas totales',
          value: '${result.totalLegCount} piezas',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              exact ? Icons.check_circle_outline : Icons.warning_amber_outlined,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GeometrySummary extends StatelessWidget {
  const _GeometrySummary({required this.result});

  final InclinedFlatRoofResult result;

  @override
  Widget build(BuildContext context) {
    final legHeightsText = result.legHeightsMeters
        .map((height) => height.toStringAsFixed(2))
        .join(' / ');

    return Column(
      children: [
        _ResultTile(
          icon: Icons.aspect_ratio_outlined,
          title: 'Área de módulos',
          value:
              '${result.widthMeters.toStringAsFixed(2)} × ${result.inclinedDepthMeters.toStringAsFixed(2)} m',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.height_outlined,
          title: 'Alturas de patas',
          value: '$legHeightsText m',
        ),
        const SizedBox(height: 10),
        _ResultTile(
          icon: Icons.straighten_outlined,
          title: 'Proyección en losa',
          value: '${result.projectedDepthMeters.toStringAsFixed(2)} m',
        ),
      ],
    );
  }
}

class _MaterialSummary extends StatelessWidget {
  const _MaterialSummary({
    required this.result,
    required this.fixingType,
  });

  final InclinedFlatRoofResult result;
  final StructureFixingType fixingType;

  @override
  Widget build(BuildContext context) {
    final railPlan = result.railPlan;

    return Column(
      children: [
        _MaterialTile(
          label: 'Riel nominal 5 m',
          quantity: '${railPlan.fiveMeterRails} tramos',
          detail: '4.90 m útiles por tramo',
        ),
        const SizedBox(height: 10),
        _MaterialTile(
          label: 'Riel nominal 6 m',
          quantity: '${railPlan.sixMeterRails} tramos',
          detail: '6.00 m útiles por tramo',
        ),
        const SizedBox(height: 10),
        _MaterialTile(
          label: 'Desperdicio estimado de riel',
          quantity: '${railPlan.wasteMeters.toStringAsFixed(2)} m',
          detail: '${result.totalRailMeters.toStringAsFixed(2)} m requeridos',
        ),
        const SizedBox(height: 10),
        _MaterialTile(
          label: 'Mid clamps',
          quantity: '${result.midClampCount} piezas',
        ),
        const SizedBox(height: 10),
        _MaterialTile(
          label: 'End clamps',
          quantity: '${result.endClampCount} piezas',
          detail: 'Una pieza por esquina del área de módulos',
        ),
        const SizedBox(height: 10),
        _MaterialTile(
          label: 'Patas estructurales',
          quantity: '${result.totalLegCount} piezas',
          detail:
              '${result.supportRowCount} filas × ${result.supportPointsPerRow} patas por fila',
        ),
        const SizedBox(height: 10),
        _MaterialTile(
          label: 'Largueros',
          quantity: '${result.largueroPiecesCount} piezas',
          detail:
              '${result.largueroLengthMeters.toStringAsFixed(2)} m por pieza',
        ),
        const SizedBox(height: 10),
        _MaterialTile(
          label: 'Rompevientos',
          quantity: '${result.windBracePiecesCount} piezas',
          detail:
              '${result.windBraceLengthMeters.toStringAsFixed(2)} m por pieza',
        ),
        const SizedBox(height: 10),
        _MaterialTile(
          label: 'Material de ángulo',
          quantity: '${result.angleSixMeterSections} tramos de 6 m',
          detail:
              '${result.angleMaterialMeters.toStringAsFixed(2)} m calculados',
        ),
        const SizedBox(height: 10),
        _MaterialTile(
          label: fixingType.shortLabel,
          quantity: '${result.fixingPiecesPerTypeCount} piezas',
          detail: '2 por pata · pendiente de precio y especificación final',
        ),
        const SizedBox(height: 10),
        _MaterialTile(
          label: 'Tuercas',
          quantity: '${result.fixingPiecesPerTypeCount} piezas',
          detail: '2 por pata',
        ),
        const SizedBox(height: 10),
        _MaterialTile(
          label: 'Rondanas planas',
          quantity: '${result.fixingPiecesPerTypeCount} piezas',
          detail: '2 por pata',
        ),
        const SizedBox(height: 10),
        _MaterialTile(
          label: 'Rondanas de presión',
          quantity: '${result.fixingPiecesPerTypeCount} piezas',
          detail: '2 por pata',
        ),
      ],
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({
    required this.label,
    required this.quantity,
    this.detail,
  });

  final String label;
  final String quantity;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                if (detail != null) ...[
                  const SizedBox(height: 3),
                  Text(detail!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            quantity,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideViewDiagram extends StatelessWidget {
  const _SideViewDiagram({required this.result});

  final InclinedFlatRoofResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      height: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(
        painter: _SideViewPainter(
          result: result,
          lineColor: theme.colorScheme.primary,
          textColor: theme.colorScheme.onSurface,
          baseColor: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

class _SideViewPainter extends CustomPainter {
  const _SideViewPainter({
    required this.result,
    required this.lineColor,
    required this.textColor,
    required this.baseColor,
  });

  final InclinedFlatRoofResult result;
  final Color lineColor;
  final Color textColor;
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = baseColor
      ..strokeWidth = 2;
    final structurePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const left = 30.0;
    final right = size.width - 26;
    final floorY = size.height - 38;
    final availableHeight = floorY - 30;
    final depth = result.projectedDepthMeters <= 0
        ? 1.0
        : result.projectedDepthMeters;
    final rearHeight = max(result.rearLegMeters, 0.1);
    final horizontalScale = (right - left) / depth;
    final verticalScale = availableHeight / rearHeight;
    final scale = min(horizontalScale, verticalScale);

    final supportPoints = <Offset>[];
    for (var index = 0; index < result.supportRowCount; index++) {
      final progress = result.supportRowCount == 1
          ? 0.0
          : index / (result.supportRowCount - 1);
      final height = result.legHeightsMeters[index];
      supportPoints.add(
        Offset(
          left + (result.projectedDepthMeters * scale * progress),
          floorY - (height * scale),
        ),
      );
    }

    canvas.drawLine(
      Offset(left - 10, floorY),
      Offset(right + 4, floorY),
      basePaint,
    );

    for (final point in supportPoints) {
      canvas.drawLine(Offset(point.dx, floorY), point, structurePaint);
    }

    if (supportPoints.length >= 2) {
      canvas.drawLine(supportPoints.first, supportPoints.last, structurePaint);
    }

    for (var index = 0; index < supportPoints.length; index++) {
      final point = supportPoints[index];
      final label = _supportLabel(index, supportPoints.length);
      final alignRight = index == 0;
      _drawText(
        canvas,
        '$label\n${result.legHeightsMeters[index].toStringAsFixed(2)} m',
        Offset(point.dx - (alignRight ? 8 : 0), floorY + 5),
        textColor,
        alignRight: alignRight,
      );
    }

    if (supportPoints.length >= 2) {
      final front = supportPoints.first;
      final rear = supportPoints.last;
      _drawText(
        canvas,
        '${result.inclinedDepthMeters.toStringAsFixed(2)} m',
        Offset((front.dx + rear.dx) / 2 - 22, (front.dy + rear.dy) / 2 - 22),
        lineColor,
      );
    }
  }

  String _supportLabel(int index, int total) {
    if (index == 0) return 'Delantera';
    if (index == total - 1) return 'Trasera';
    if (total == 3) return 'Intermedia';
    return 'Int. $index';
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10, color: color),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 72);

    painter.paint(
      canvas,
      Offset(alignRight ? offset.dx - painter.width : offset.dx, offset.dy),
    );
  }

  @override
  bool shouldRepaint(covariant _SideViewPainter oldDelegate) {
    return oldDelegate.result != result ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.baseColor != baseColor;
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
          const SizedBox(width: 8),
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

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
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
            icon: const Icon(Icons.arrow_back_outlined),
            label: Text(buttonLabel),
          ),
        ),
      ],
    );
  }
}
