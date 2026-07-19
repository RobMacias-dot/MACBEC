import 'package:flutter_test/flutter_test.dart';
import 'package:macbec_solar_app/features/estructura/domain/structure_design_rules.dart';

void main() {
  // 4 módulos horizontales x 2 niveles, 1 estructura, panel 2.00 x 1.00 m,
  // separación por defecto de 20 mm, inclinación 30°, pata delantera 20 cm.
  final result = StructureDesignRules.calculateInclinedFlatRoof(
    const InclinedFlatRoofInput(
      requiredPanels: 8,
      structuresCount: 1,
      panelsHorizontal: 4,
      panelRows: 2,
      panelLengthMm: 2000,
      panelWidthMm: 1000,
      inclinationDegrees: 30,
      frontLegCm: 20,
    ),
  );

  test('distribuye exactamente los módulos requeridos cuando encajan', () {
    expect(result.modulesPerStructure, equals(8));
    expect(result.totalDistributedPanels, equals(8));
    expect(result.hasExactPanelDistribution, isTrue);
    expect(result.panelDifference, equals(0));
  });

  test('calcula el área de módulos a partir del ancho y fondo inclinado', () {
    // (4*1000 + 3*20) / 1000
    expect(result.widthMeters, closeTo(4.06, 0.001));
    // (2*2000 + 1*20) / 1000
    expect(result.inclinedDepthMeters, closeTo(4.02, 0.001));
    expect(
      result.areaMetersSquared,
      closeTo(result.widthMeters * result.inclinedDepthMeters, 0.001),
    );
  });

  test('la pata trasera crece con el seno del ángulo de inclinación', () {
    // sin(30°) * inclinedDepthMeters + pata delantera (0.20 m)
    final expectedRearLeg = 0.5 * result.inclinedDepthMeters + 0.20;

    expect(result.frontLegMeters, closeTo(0.20, 0.0001));
    expect(result.rearLegMeters, closeTo(expectedRearLeg, 0.001));
    expect(result.rearLegMeters, greaterThan(result.frontLegMeters));
  });

  test('usa 3 filas de patas (delantera, intermedia, trasera) hasta 3 niveles',
      () {
    expect(result.supportRowCount, equals(3));
    expect(result.supportPointsPerRow, equals(3)); // regla especial 2-4 -> 3
    expect(result.totalLegCount, equals(9)); // 3 x 3 x 1 estructura
  });

  test(
      'supportPointsPerRow sigue la tabla especial (1 a 4 paneles '
      'horizontales) y panelesHorizontal - 1 a partir de 5', () {
    const expectedByPanelsHorizontal = {
      1: 2,
      2: 3,
      3: 3,
      4: 3,
      5: 4,
      6: 5,
      7: 6,
      8: 7,
    };

    expectedByPanelsHorizontal.forEach((panelsHorizontal, expectedLegs) {
      final caseResult = StructureDesignRules.calculateInclinedFlatRoof(
        InclinedFlatRoofInput(
          requiredPanels: panelsHorizontal,
          structuresCount: 1,
          panelsHorizontal: panelsHorizontal,
          panelRows: 1,
          panelLengthMm: 2000,
          panelWidthMm: 1000,
          inclinationDegrees: 30,
          frontLegCm: 20,
        ),
      );

      expect(
        caseResult.supportPointsPerRow,
        equals(expectedLegs),
        reason: 'panelesHorizontal=$panelsHorizontal debe dar '
            '$expectedLegs patas por fila',
      );
    });
  });

  test('usa 4 filas de patas cuando hay más de 3 niveles de paneles', () {
    final tallResult = StructureDesignRules.calculateInclinedFlatRoof(
      const InclinedFlatRoofInput(
        requiredPanels: 16,
        structuresCount: 1,
        panelsHorizontal: 4,
        panelRows: 4,
        panelLengthMm: 2000,
        panelWidthMm: 1000,
        inclinationDegrees: 30,
        frontLegCm: 20,
      ),
    );

    expect(tallResult.supportRowCount, equals(6)); // panelRows + 2
  });

  test('calcula piezas de riel, mid/end clamps y material de ángulo', () {
    expect(result.midClampCount, equals(12)); // (4-1)*2*2*1
    expect(result.endClampCount, equals(4)); // 4 esquinas x 1 estructura
    expect(result.railPieceLengthMeters, closeTo(result.widthMeters + 0.20, 0.001));
    expect(result.railPiecesCount, equals(4)); // panelRows*2 * estructuras
    expect(result.angleSixMeterSections, greaterThan(0));
  });

  test('el plan de riel siempre cubre los metros requeridos sin faltante', () {
    expect(result.railPlan.availableMeters, greaterThanOrEqualTo(result.railPlan.requiredMeters));
    expect(result.railPlan.wasteMeters, greaterThanOrEqualTo(0));
  });
}
