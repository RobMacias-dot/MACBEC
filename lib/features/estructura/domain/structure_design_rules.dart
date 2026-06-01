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

class InclinedFlatRoofResult {
  const InclinedFlatRoofResult({
    required this.requiredPanels,
    required this.totalDistributedPanels,
    required this.modulesPerStructure,
    required this.structuresCount,
    required this.panelsHorizontal,
    required this.panelRows,
    required this.widthMeters,
    required this.inclinedDepthMeters,
    required this.projectedDepthMeters,
    required this.areaMetersSquared,
    required this.frontLegMeters,
    required this.middleLegMeters,
    required this.rearLegMeters,
    required this.railPiecesCount,
    required this.railPieceLengthMeters,
    required this.totalRailMeters,
    required this.railPlan,
    required this.midClampCount,
    required this.endClampCount,
    required this.fixingPointCount,
    required this.angleMaterialMeters,
    required this.angleSixMeterSections,
    required this.windBraceLengthMeters,
  });

  final int requiredPanels;
  final int totalDistributedPanels;
  final int modulesPerStructure;
  final int structuresCount;
  final int panelsHorizontal;
  final int panelRows;

  final double widthMeters;
  final double inclinedDepthMeters;
  final double projectedDepthMeters;
  final double areaMetersSquared;

  final double frontLegMeters;
  final double middleLegMeters;
  final double rearLegMeters;

  final int railPiecesCount;
  final double railPieceLengthMeters;
  final double totalRailMeters;
  final StructureRailPlan railPlan;
  final int midClampCount;
  final int endClampCount;
  final int fixingPointCount;

  final double angleMaterialMeters;
  final int angleSixMeterSections;
  final double windBraceLengthMeters;

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
    final modulesPerStructure = input.panelsHorizontal * input.panelRows;
    final totalDistributedPanels = modulesPerStructure * input.structuresCount;

    final horizontalGaps = max(input.panelsHorizontal - 1, 0);
    final verticalGaps = max(input.panelRows - 1, 0);
    final widthMeters = ((input.panelsHorizontal * input.panelWidthMm) +
            (horizontalGaps * input.panelGapMm)) /
        1000;
    final inclinedDepthMeters = ((input.panelRows * input.panelLengthMm) +
            (verticalGaps * input.panelGapMm)) /
        1000;

    final angleRadians = input.inclinationDegrees * pi / 180;
    final verticalRiseMeters = sin(angleRadians) * inclinedDepthMeters;
    final projectedDepthMeters = cos(angleRadians) * inclinedDepthMeters;
    final frontLegMeters = input.frontLegCm / 100;
    final middleLegMeters = frontLegMeters + (verticalRiseMeters / 2);
    final rearLegMeters = frontLegMeters + verticalRiseMeters;

    final railPiecesPerStructure = input.panelRows * 2;
    final railPiecesCount = railPiecesPerStructure * input.structuresCount;
    final railPieceLengthMeters = widthMeters + 0.20;
    final totalRailMeters = railPiecesCount * railPieceLengthMeters;
    final railPlan = _optimizeRailStock(totalRailMeters);

    final midClampCount = max(input.panelsHorizontal - 1, 0) *
        2 *
        input.panelRows *
        input.structuresCount;
    final endClampCount = 4 * input.panelRows * input.structuresCount;

    final supportPointsPerLine = max(input.panelsHorizontal - 1, 1);
    final fixingPointCount = supportPointsPerLine * 3 * input.structuresCount;
    final spacingBetweenSupports = input.panelsHorizontal > 1
        ? widthMeters / (input.panelsHorizontal - 1)
        : widthMeters;
    final windBraceLengthMeters =
        sqrt(pow(rearLegMeters, 2) + pow(spacingBetweenSupports, 2)) + 0.10;

    final legsMetersPerStructure = supportPointsPerLine *
        (frontLegMeters + middleLegMeters + rearLegMeters);
    final longitudinalMetersPerStructure = (inclinedDepthMeters + 0.10) * 3;
    final windBracesMetersPerStructure = windBraceLengthMeters * 2;
    final angleMaterialMeters = (legsMetersPerStructure +
            longitudinalMetersPerStructure +
            windBracesMetersPerStructure) *
        input.structuresCount;

    return InclinedFlatRoofResult(
      requiredPanels: input.requiredPanels,
      totalDistributedPanels: totalDistributedPanels,
      modulesPerStructure: modulesPerStructure,
      structuresCount: input.structuresCount,
      panelsHorizontal: input.panelsHorizontal,
      panelRows: input.panelRows,
      widthMeters: widthMeters,
      inclinedDepthMeters: inclinedDepthMeters,
      projectedDepthMeters: projectedDepthMeters,
      areaMetersSquared: widthMeters * inclinedDepthMeters,
      frontLegMeters: frontLegMeters,
      middleLegMeters: middleLegMeters,
      rearLegMeters: rearLegMeters,
      railPiecesCount: railPiecesCount,
      railPieceLengthMeters: railPieceLengthMeters,
      totalRailMeters: totalRailMeters,
      railPlan: railPlan,
      midClampCount: midClampCount,
      endClampCount: endClampCount,
      fixingPointCount: fixingPointCount,
      angleMaterialMeters: angleMaterialMeters,
      angleSixMeterSections: (angleMaterialMeters / 6).ceil(),
      windBraceLengthMeters: windBraceLengthMeters,
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

        final availableMeters = (fiveCount * nominalFiveUsefulMeters) +
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
