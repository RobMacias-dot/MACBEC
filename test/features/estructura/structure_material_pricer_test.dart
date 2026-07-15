import 'package:flutter_test/flutter_test.dart';
import 'package:macbec_solar_app/features/estructura/domain/structure_design_rules.dart';
import 'package:macbec_solar_app/features/estructura/domain/structure_material_pricer.dart';
import 'package:macbec_solar_app/features/materiales_catalogo/domain/entities/material_catalog_product.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  MaterialCatalogProduct product({
    required String categoriaApp,
    String? subcategoria,
    String? modelo,
    double? precioMxn,
    bool activo = true,
    bool revisarPrecio = false,
    String? estadoParaCalculo,
    String? codigoInterno,
    String? tipoElementoEstructura,
    double? longitudNominalM,
  }) {
    return MaterialCatalogProduct(
      id: 'p-${codigoInterno ?? subcategoria ?? modelo}',
      codigoInterno: codigoInterno,
      categoriaApp: categoriaApp,
      subcategoria: subcategoria,
      modelo: modelo,
      activo: activo,
      revisarPrecio: revisarPrecio,
      estadoParaCalculo: estadoParaCalculo,
      precioMxn: precioMxn,
      tipoElementoEstructura: tipoElementoEstructura,
      longitudNominalM: longitudNominalM,
      createdAt: now,
      updatedAt: now,
    );
  }

  InclinedFlatRoofResult buildResult({
    StructureAngleMaterial angleMaterial = StructureAngleMaterial.steelPtr,
  }) {
    return StructureDesignRules.calculateInclinedFlatRoof(
      InclinedFlatRoofInput(
        requiredPanels: 20,
        structuresCount: 1,
        panelsHorizontal: 10,
        panelRows: 2,
        panelLengthMm: 2278,
        panelWidthMm: 1134,
        inclinationDegrees: 20,
        frontLegCm: 20,
        angleMaterial: angleMaterial,
      ),
    );
  }

  test('asigna precio cuando hay un producto activo que coincide', () {
    final result = buildResult();
    final catalog = [
      product(
        categoriaApp: 'ESTRUCTURA_ACCESORIO',
        subcategoria: 'RIEL 6 M',
        precioMxn: 450,
      ),
      product(
        categoriaApp: 'ESTRUCTURA_ACCESORIO',
        subcategoria: 'PERFIL PTR',
        precioMxn: 380,
      ),
    ];

    final lines = StructureMaterialPricer.price(
      result: result,
      angleMaterial: StructureAngleMaterial.steelPtr,
      fixingType: StructureFixingType.mechanicalAnchor,
      catalog: catalog,
    );

    final railSixLine =
        lines.firstWhere((line) => line.label == 'Riel nominal 6 m');
    expect(railSixLine.hasPrice, isTrue);
    expect(railSixLine.unitPriceMxn, equals(450));
    expect(railSixLine.lineTotalMxn, equals(450 * railSixLine.quantity));

    final angleLine = lines
        .firstWhere((line) => line.label.startsWith('Material de ángulo'));
    expect(angleLine.hasPrice, isTrue);
    expect(angleLine.unitPriceMxn, equals(380));
  });

  test('muestra sin precio (null) cuando no hay producto que coincida', () {
    final result = buildResult();
    final lines = StructureMaterialPricer.price(
      result: result,
      angleMaterial: StructureAngleMaterial.steelPtr,
      fixingType: StructureFixingType.mechanicalAnchor,
      catalog: const [],
    );

    for (final line in lines) {
      expect(line.hasPrice, isFalse);
      expect(line.unitPriceMxn, isNull);
      expect(line.lineTotalMxn, isNull);
    }
  });

  test(
      'un producto inactivo, en revision o pendiente de definir no cuenta como precio',
      () {
    final result = buildResult();
    final catalog = [
      product(
        categoriaApp: 'ESTRUCTURA_ACCESORIO',
        subcategoria: 'RIEL 6 M',
        precioMxn: 450,
        activo: false,
      ),
    ];

    final lines = StructureMaterialPricer.price(
      result: result,
      angleMaterial: StructureAngleMaterial.steelPtr,
      fixingType: StructureFixingType.mechanicalAnchor,
      catalog: catalog,
    );

    final railSixLine =
        lines.firstWhere((line) => line.label == 'Riel nominal 6 m');
    expect(railSixLine.hasPrice, isFalse);
  });

  test('solo agrega cartuchos de anclaje quimico cuando aplica la fijacion',
      () {
    final result = buildResult();

    final withChemicalAnchor = StructureMaterialPricer.price(
      result: result,
      angleMaterial: StructureAngleMaterial.steelPtr,
      fixingType: StructureFixingType.chemicalAnchor,
      catalog: const [],
    );
    expect(
      withChemicalAnchor.any(
        (line) => line.label == 'Cartuchos de anclaje químico',
      ),
      isTrue,
    );

    final withMechanicalAnchor = StructureMaterialPricer.price(
      result: result,
      angleMaterial: StructureAngleMaterial.steelPtr,
      fixingType: StructureFixingType.mechanicalAnchor,
      catalog: const [],
    );
    expect(
      withMechanicalAnchor.any(
        (line) => line.label == 'Cartuchos de anclaje químico',
      ),
      isFalse,
    );
  });

  test('el material de angulo de aluminio busca ANGULO/ALUMINIO en vez de PTR',
      () {
    final result = buildResult(
      angleMaterial: StructureAngleMaterial.aluminumAngle,
    );
    final catalog = [
      product(
        categoriaApp: 'ESTRUCTURA_ACCESORIO',
        subcategoria: 'PERFIL ANGULO ALUMINIO',
        precioMxn: 520,
      ),
      product(
        categoriaApp: 'ESTRUCTURA_ACCESORIO',
        subcategoria: 'PERFIL PTR',
        precioMxn: 380,
      ),
    ];

    final lines = StructureMaterialPricer.price(
      result: result,
      angleMaterial: StructureAngleMaterial.aluminumAngle,
      fixingType: StructureFixingType.mechanicalAnchor,
      catalog: catalog,
    );

    final angleLine = lines
        .firstWhere((line) => line.label.startsWith('Material de ángulo'));
    expect(angleLine.unitPriceMxn, equals(520));
  });

  group('contra datos reales de Plantilla_Catalogo_MacBec_ESTRUCTURA_REVISADA.xlsx', () {
    // Filas tomadas tal cual del archivo real (hoja Catalogo_Productos) que
    // el usuario compartió para cotejar la Fase 6.22. Confirman que el
    // emparejamiento por tipo_elemento_estructura funciona con datos reales,
    // incluidos casos donde el texto libre (modelo/descripción) no habría
    // servido para emparejar por palabras clave (p. ej. "Mid Clam" sin la
    // "p" final).
    late List<MaterialCatalogProduct> realCatalog;

    setUp(() {
      realCatalog = [
        product(
          categoriaApp: 'ESTRUCTURA',
          subcategoria: 'Riel',
          modelo: 'Riel aluminio nominal 5 m (real 4.90 m)',
          precioMxn: 472.85,
          tipoElementoEstructura: 'RIEL',
          longitudNominalM: 5,
        ),
        product(
          categoriaApp: 'ESTRUCTURA',
          subcategoria: 'Riel',
          modelo: 'Riel aluminio nominal 6 m (real 6.01 m)',
          precioMxn: 584.79,
          tipoElementoEstructura: 'RIEL',
          longitudNominalM: 6,
        ),
        product(
          categoriaApp: 'ESTRUCTURA',
          subcategoria: 'Riel',
          modelo: 'Riel aluminio 4.6 m',
          precioMxn: 547.93,
          tipoElementoEstructura: 'RIEL',
          longitudNominalM: 4.6,
        ),
        product(
          categoriaApp: 'ESTRUCTURA',
          subcategoria: 'Clamp',
          modelo: 'Mid Clam',
          precioMxn: 25.09,
          tipoElementoEstructura: 'CLAMP_INTERMEDIO',
        ),
        product(
          categoriaApp: 'ESTRUCTURA',
          subcategoria: 'Clamp',
          modelo: 'End Clam',
          precioMxn: 25.09,
          tipoElementoEstructura: 'CLAMP_FINAL',
        ),
        product(
          categoriaApp: 'ESTRUCTURA',
          subcategoria: 'Perfil metálico',
          modelo: 'PTR Gal 2X2 cal 14',
          precioMxn: 570,
          tipoElementoEstructura: 'PERFIL_PTR',
          estadoParaCalculo: 'PENDIENTE_LONGITUD_TRAMO',
        ),
        product(
          categoriaApp: 'ESTRUCTURA',
          subcategoria: 'Perfil metálico',
          modelo: 'Angulo aluminio 3/16 x 1 1/2 6.10 m',
          precioMxn: 733.40,
          tipoElementoEstructura: 'PERFIL_ANGULO_ALUMINIO',
          longitudNominalM: 6.1,
        ),
        product(
          categoriaApp: 'ESTRUCTURA',
          codigoInterno: 'EST-FIJ-ANCLAJE-QUIMICO',
          subcategoria: 'Fijación',
          modelo: 'Cartucho de anclaje químico (definir marca y rendimiento)',
          precioMxn: null,
          activo: false,
          revisarPrecio: true,
          estadoParaCalculo: 'PENDIENTE_DEFINIR',
          tipoElementoEstructura: 'ANCLAJE_QUIMICO',
        ),
      ];
    });

    test('riel 5 m y 6 m se distinguen por longitud_nominal_m, no por texto',
        () {
      final result = buildResult();

      final lines = StructureMaterialPricer.price(
        result: result,
        angleMaterial: StructureAngleMaterial.steelPtr,
        fixingType: StructureFixingType.mechanicalAnchor,
        catalog: realCatalog,
      );

      final rail5 = lines.firstWhere((l) => l.label == 'Riel nominal 5 m');
      final rail6 = lines.firstWhere((l) => l.label == 'Riel nominal 6 m');

      expect(rail5.unitPriceMxn, equals(472.85));
      expect(rail6.unitPriceMxn, equals(584.79));
    });

    test('los clamps reales "Mid Clam"/"End Clam" se emparejan por tipo, '
        'aunque el texto no contenga "clamp" completo', () {
      final result = buildResult();

      final lines = StructureMaterialPricer.price(
        result: result,
        angleMaterial: StructureAngleMaterial.steelPtr,
        fixingType: StructureFixingType.mechanicalAnchor,
        catalog: realCatalog,
      );

      final midClamp = lines.firstWhere((l) => l.label == 'Mid clamps');
      final endClamp = lines.firstWhere((l) => l.label == 'End clamps');

      expect(midClamp.unitPriceMxn, equals(25.09));
      expect(endClamp.unitPriceMxn, equals(25.09));
    });

    test('PTR con estado PENDIENTE_LONGITUD_TRAMO conserva su precio '
        '(solo PENDIENTE_DEFINIR bloquea el precio)', () {
      final result = buildResult();

      final lines = StructureMaterialPricer.price(
        result: result,
        angleMaterial: StructureAngleMaterial.steelPtr,
        fixingType: StructureFixingType.mechanicalAnchor,
        catalog: realCatalog,
      );

      final angleLine = lines
          .firstWhere((l) => l.label.startsWith('Material de ángulo'));
      expect(angleLine.unitPriceMxn, equals(570));
    });

    test(
        'el anclaje químico real sigue PENDIENTE_DEFINIR/inactivo en el '
        'archivo compartido: debe mostrar "-" (null), no un precio inventado',
        () {
      final result = buildResult();

      final lines = StructureMaterialPricer.price(
        result: result,
        angleMaterial: StructureAngleMaterial.steelPtr,
        fixingType: StructureFixingType.chemicalAnchor,
        catalog: realCatalog,
      );

      final cartridgeLine = lines
          .firstWhere((l) => l.label == 'Cartuchos de anclaje químico');
      expect(cartridgeLine.hasPrice, isFalse);
      expect(cartridgeLine.matchedProduct, isNotNull);
      expect(
        cartridgeLine.matchedProduct!.codigoInterno,
        equals('EST-FIJ-ANCLAJE-QUIMICO'),
      );
    });
  });
}
