import 'dart:math';

enum StructureMountType {
  coplanarPitchedRoof,
  inclinedFlatRoof,
  elevatedTable,
  groundMounted,
}

extension StructureMountTypeInfo on StructureMountType {
  String get label {
    switch (this) {
      case StructureMountType.coplanarPitchedRoof:
        return 'Coplanar sobre techo inclinado';
      case StructureMountType.inclinedFlatRoof:
        return 'Inclinado sobre losa plana';
      case StructureMountType.elevatedTable:
        return 'Elevado tipo mesa';
      case StructureMountType.groundMounted:
        return 'Montaje en suelo';
    }
  }

  String get description {
    switch (this) {
      case StructureMountType.coplanarPitchedRoof:
        return 'Módulos paralelos a la pendiente existente.';
      case StructureMountType.inclinedFlatRoof:
        return 'Estructura fija con inclinación configurable.';
      case StructureMountType.elevatedTable:
        return 'Estructura con mayor altura libre inferior.';
      case StructureMountType.groundMounted:
        return 'Estructura independiente sobre terreno.';
    }
  }

  bool get isAvailable => this == StructureMountType.inclinedFlatRoof;
}

enum StructureFixingType {
  chemicalAnchor,
  mechanicalAnchor,
  nonPenetratingBallast,
}

extension StructureFixingTypeInfo on StructureFixingType {
  String get label {
    switch (this) {
      case StructureFixingType.chemicalAnchor:
        return 'Anclaje químico con espárrago';
      case StructureFixingType.mechanicalAnchor:
        return 'Fijación mecánica';
      case StructureFixingType.nonPenetratingBallast:
        return 'Lastre no penetrante';
    }
  }

  String get shortLabel {
    switch (this) {
      case StructureFixingType.chemicalAnchor:
        return 'Anclaje químico';
      case StructureFixingType.mechanicalAnchor:
        return 'Fijación mecánica';
      case StructureFixingType.nonPenetratingBallast:
        return 'Lastre';
    }
  }
}

/// Material del ángulo/estructura: PTR de acero o ángulo de aluminio. Ambos
/// se compran en tramos comerciales de 6 m útiles (el nominal de 6.10 m del
/// ángulo de aluminio es solo la medida de venta) - ver Fase 4.15.
enum StructureAngleMaterial { steelPtr, aluminumAngle }

extension StructureAngleMaterialInfo on StructureAngleMaterial {
  String get label {
    switch (this) {
      case StructureAngleMaterial.steelPtr:
        return 'PTR de acero';
      case StructureAngleMaterial.aluminumAngle:
        return 'Ángulo de aluminio';
    }
  }
}

class InclinedFlatRoofInput {
  const InclinedFlatRoofInput({
    required this.requiredPanels,
    required this.structuresCount,
    required this.panelsHorizontal,
    required this.panelRows,
    required this.panelLengthMm,
    required this.panelWidthMm,
    required this.inclinationDegrees,
    required this.frontLegCm,
    this.panelGapMm = 20,
    this.angleMaterial = StructureAngleMaterial.steelPtr,
  });

  final int requiredPanels;
  final int structuresCount;
  final int panelsHorizontal;
  final int panelRows;
  final double panelLengthMm;
  final double panelWidthMm;
  final double inclinationDegrees;
  final double frontLegCm;
  final double panelGapMm;
  final StructureAngleMaterial angleMaterial;
}

class StructureRailPlan {
  const StructureRailPlan({
    required this.fiveMeterRails,
    required this.sixMeterRails,
    required this.requiredMeters,
    required this.availableMeters,
  });

  final int fiveMeterRails;
  final int sixMeterRails;
  final double requiredMeters;
  final double availableMeters;

  double get wasteMeters => availableMeters - requiredMeters;
}

/// Plan de compra del material de ángulo (PTR o aluminio), con el mismo
/// rigor de desperdicio que [StructureRailPlan]. A diferencia del riel, hoy
/// solo existe una longitud comercial (6 m útiles) para ambos materiales de
/// ángulo, así que no hay una combinación de tramos que optimizar - pero se
/// expone el desperdicio explícitamente igual que en el riel.
class StructureAnglePlan {
  const StructureAnglePlan({
    required this.sixMeterSections,
    required this.requiredMeters,
    required this.availableMeters,
  });

  final int sixMeterSections;
  final double requiredMeters;
  final double availableMeters;

  double get wasteMeters => availableMeters - requiredMeters;
}

class InclinedFlatRoofResult {
  const InclinedFlatRoofResult({
    required this.requiredPanels,
    required this.totalDistributedPanels,
    required this.modulesPerStructure,
    required this.structuresCount,
    required this.panelsHorizontal,
    required this.panelRows,
    required this.supportRowCount,
    required this.supportPointsPerRow,
    required this.totalLegCount,
    required this.legHeightsMeters,
    required this.widthMeters,
    required this.inclinedDepthMeters,
    required this.projectedDepthMeters,
    required this.areaMetersSquared,
    required this.frontLegMeters,
    required this.rearLegMeters,
    required this.railPiecesCount,
    required this.railPieceLengthMeters,
    required this.totalRailMeters,
    required this.railPlan,
    required this.midClampCount,
    required this.endClampCount,
    required this.fixingPiecesPerTypeCount,
    required this.largueroPiecesCount,
    required this.largueroLengthMeters,
    required this.windBracePiecesCount,
    required this.angleMaterialMeters,
    required this.angleSixMeterSections,
    required this.windBraceLengthMeters,
    required this.angleMaterial,
    required this.anglePlan,
    required this.chemicalAnchorCartridgeCount,
  });

  final int requiredPanels;
  final int totalDistributedPanels;
  final int modulesPerStructure;
  final int structuresCount;
  final int panelsHorizontal;
  final int panelRows;
  final int supportRowCount;
  final int supportPointsPerRow;
  final int totalLegCount;
  final List<double> legHeightsMeters;

  final double widthMeters;
  final double inclinedDepthMeters;
  final double projectedDepthMeters;
  final double areaMetersSquared;

  final double frontLegMeters;
  final double rearLegMeters;

  final int railPiecesCount;
  final double railPieceLengthMeters;
  final double totalRailMeters;
  final StructureRailPlan railPlan;
  final int midClampCount;
  final int endClampCount;
  final int fixingPiecesPerTypeCount;
  final int largueroPiecesCount;
  final double largueroLengthMeters;
  final int windBracePiecesCount;

  final double angleMaterialMeters;
  final int angleSixMeterSections;
  final double windBraceLengthMeters;
  final StructureAngleMaterial angleMaterial;
  final StructureAnglePlan anglePlan;
  final int chemicalAnchorCartridgeCount;

  double get middleLegMeters {
    if (legHeightsMeters.length <= 2) {
      return (frontLegMeters + rearLegMeters) / 2;
    }

    return legHeightsMeters[legHeightsMeters.length ~/ 2];
  }

  /// Separación entre patas de una misma fila, según la fórmula del
  /// documento funcional original (pág. 8):
  /// `[(valor_horizontal_total) - 1] / (No._de_paneles - 2)`.
  /// Se calcula en términos de `supportPointsPerRow` (patas por fila) en
  /// vez de `panelsHorizontal` directamente, ya que desde la regla especial
  /// de 1 a 4 paneles horizontales (ver cálculo de `supportPointsPerRow`
  /// en [StructureDesignRules.calculate]) ambos valores ya no coinciden.
  double get legSpacingMeters {
    if (supportPointsPerRow <= 1) return 0;
    return (widthMeters - 1) / (supportPointsPerRow - 1);
  }

  bool get hasExactPanelDistribution {
    return totalDistributedPanels == requiredPanels;
  }

  int get panelDifference => totalDistributedPanels - requiredPanels;
}

class StructureDesignRules {
  const StructureDesignRules._();

  static InclinedFlatRoofResult calculateInclinedFlatRoof(
    InclinedFlatRoofInput input,
  ) {
    final modulesPerStructure =
        input.panelsHorizontal * input.panelRows;
    final totalDistributedPanels = modulesPerStructure * input.structuresCount;

    final horizontalGaps = max(input.panelsHorizontal - 1, 0);
    final verticalGaps = max(input.panelRows - 1, 0);
    final widthMeters =
        ((input.panelsHorizontal * input.panelWidthMm) +
                (horizontalGaps * input.panelGapMm)) /
            1000;
    final inclinedDepthMeters =
        ((input.panelRows * input.panelLengthMm) +
                (verticalGaps * input.panelGapMm)) /
            1000;

    final angleRadians = input.inclinationDegrees * pi / 180;
    final verticalRiseMeters = sin(angleRadians) * inclinedDepthMeters;
    final projectedDepthMeters = cos(angleRadians) * inclinedDepthMeters;
    final frontLegMeters = input.frontLegCm / 100;
    final rearLegMeters = frontLegMeters + verticalRiseMeters;

    final supportRowCount = input.panelRows <= 3
        ? input.panelRows + 1
        : input.panelRows + 2;

    // Patas por fila de apoyo (supportPointsPerRow).
    //
    // Para estructuras pequeñas NO se usa la fórmula `panelesHorizontal - 1`.
    // La regla especial aplica para 1, 2, 3 y 4 paneles horizontales:
    //   panelesHorizontal == 1              -> patasPorFila = 2
    //   panelesHorizontal >= 2 y <= 4        -> patasPorFila = 3
    // A partir de 5 paneles horizontales comienza la regla general:
    //   panelesHorizontal >= 5               -> patasPorFila = panelesHorizontal - 1
    final int supportPointsPerRow;
    if (input.panelsHorizontal == 1) {
      supportPointsPerRow = 2;
    } else if (input.panelsHorizontal <= 4) {
      supportPointsPerRow = 3;
    } else {
      supportPointsPerRow = input.panelsHorizontal - 1;
    }
    final legHeightsMeters = List<double>.generate(supportRowCount, (index) {
      final progress = supportRowCount == 1
          ? 0.0
          : index / (supportRowCount - 1);
      return frontLegMeters + (verticalRiseMeters * progress);
    });
    final totalLegCount =
        supportPointsPerRow * supportRowCount * input.structuresCount;

    final railPiecesPerStructure = input.panelRows * 2;
    final railPiecesCount = railPiecesPerStructure * input.structuresCount;
    final railPieceLengthMeters = widthMeters + 0.20;
    final totalRailMeters = railPiecesCount * railPieceLengthMeters;
    final railPlan = _optimizeRailStock(totalRailMeters);

    final midClampCount = max(input.panelsHorizontal - 1, 0) *
        2 *
        input.panelRows *
        input.structuresCount;
    final endClampCount = 4 * input.structuresCount;

    // Distancia entre patas (cateto adyacente del rompevientos), misma
    // fórmula del documento funcional usada en [legSpacingMeters]:
    // (valor_horizontal_total - 1) / (No. de paneles - 2).
    final legSpacingMeters = supportPointsPerRow <= 1
        ? widthMeters
        : (widthMeters - 1) / (supportPointsPerRow - 1);
    final windBraceLengthMeters =
        sqrt(pow(rearLegMeters, 2) + pow(legSpacingMeters, 2)) + 0.10;
    final windBracePiecesCount = 2 * input.structuresCount;

    final legsMetersPerStructure =
        supportPointsPerRow * legHeightsMeters.fold<double>(0, (a, b) => a + b);
    final largueroPiecesPerStructure = supportRowCount;
    final largueroPiecesCount = largueroPiecesPerStructure * input.structuresCount;
    final largueroLengthMeters = inclinedDepthMeters + 0.10;
    final longitudinalMetersPerStructure =
        largueroLengthMeters * largueroPiecesPerStructure;
    final windBracesMetersPerStructure = windBraceLengthMeters * 2;
    final angleMaterialMeters =
        (legsMetersPerStructure +
                longitudinalMetersPerStructure +
                windBracesMetersPerStructure) *
            input.structuresCount;
    final anglePlan = _optimizeAngleStock(angleMaterialMeters);
    final fixingPiecesPerTypeCount = totalLegCount * 2;
    final chemicalAnchorCartridgeCount =
        chemicalAnchorCartridges(fixingPiecesPerTypeCount);

    return InclinedFlatRoofResult(
      requiredPanels: input.requiredPanels,
      totalDistributedPanels: totalDistributedPanels,
      modulesPerStructure: modulesPerStructure,
      structuresCount: input.structuresCount,
      panelsHorizontal: input.panelsHorizontal,
      panelRows: input.panelRows,
      supportRowCount: supportRowCount,
      supportPointsPerRow: supportPointsPerRow,
      totalLegCount: totalLegCount,
      legHeightsMeters: legHeightsMeters,
      widthMeters: widthMeters,
      inclinedDepthMeters: inclinedDepthMeters,
      projectedDepthMeters: projectedDepthMeters,
      areaMetersSquared: widthMeters * inclinedDepthMeters,
      frontLegMeters: frontLegMeters,
      rearLegMeters: rearLegMeters,
      railPiecesCount: railPiecesCount,
      railPieceLengthMeters: railPieceLengthMeters,
      totalRailMeters: totalRailMeters,
      railPlan: railPlan,
      midClampCount: midClampCount,
      endClampCount: endClampCount,
      fixingPiecesPerTypeCount: fixingPiecesPerTypeCount,
      largueroPiecesCount: largueroPiecesCount,
      largueroLengthMeters: largueroLengthMeters,
      windBracePiecesCount: windBracePiecesCount,
      angleMaterialMeters: angleMaterialMeters,
      angleSixMeterSections: anglePlan.sixMeterSections,
      windBraceLengthMeters: windBraceLengthMeters,
      angleMaterial: input.angleMaterial,
      anglePlan: anglePlan,
      chemicalAnchorCartridgeCount: chemicalAnchorCartridgeCount,
    );
  }

  /// Cartuchos de anclaje químico necesarios (Fester 890, 20 tuercas por
  /// cartucho - ver Fase 4.17). Solo aplica cuando la fijación elegida es
  /// anclaje químico; para otros tipos de fijación el valor no debe usarse.
  static int chemicalAnchorCartridges(int totalNuts) {
    const nutsPerCartridge = 20;
    if (totalNuts <= 0) return 0;
    return (totalNuts / nutsPerCartridge).ceil();
  }

  static StructureAnglePlan _optimizeAngleStock(double requiredMeters) {
    const nominalSixUsefulMeters = 6.00;
    final sections = requiredMeters <= 0
        ? 0
        : (requiredMeters / nominalSixUsefulMeters).ceil();

    return StructureAnglePlan(
      sixMeterSections: sections,
      requiredMeters: requiredMeters,
      availableMeters: sections * nominalSixUsefulMeters,
    );
  }

  static StructureRailPlan _optimizeRailStock(double requiredMeters) {
    const nominalFiveUsefulMeters = 4.90;
    const nominalSixUsefulMeters = 6.00;

    StructureRailPlan? bestPlan;
    final maxFive = (requiredMeters / nominalFiveUsefulMeters).ceil() + 2;
    final maxSix = (requiredMeters / nominalSixUsefulMeters).ceil() + 2;

    for (var fiveCount = 0; fiveCount <= maxFive; fiveCount++) {
      for (var sixCount = 0; sixCount <= maxSix; sixCount++) {
        if (fiveCount == 0 && sixCount == 0) continue;

        final availableMeters =
            (fiveCount * nominalFiveUsefulMeters) +
                (sixCount * nominalSixUsefulMeters);
        if (availableMeters < requiredMeters) continue;

        final candidate = StructureRailPlan(
          fiveMeterRails: fiveCount,
          sixMeterRails: sixCount,
          requiredMeters: requiredMeters,
          availableMeters: availableMeters,
        );

        if (bestPlan == null ||
            candidate.wasteMeters < bestPlan.wasteMeters ||
            (candidate.wasteMeters == bestPlan.wasteMeters &&
                (fiveCount + sixCount) <
                    (bestPlan.fiveMeterRails + bestPlan.sixMeterRails))) {
          bestPlan = candidate;
        }
      }
    }

    return bestPlan ??
        StructureRailPlan(
          fiveMeterRails: 0,
          sixMeterRails: 0,
          requiredMeters: requiredMeters,
          availableMeters: 0,
        );
  }
}
