import '../../materiales_catalogo/domain/entities/material_catalog_product.dart';
import 'structure_design_rules.dart';

/// Una línea de material de estructura con su precio de catálogo, o sin
/// precio (`unitPriceMxn == null`) cuando no hay un producto activo y listo
/// para calcular que coincida. La UI debe mostrar "-" en ese caso, nunca 0
/// ni omitir la línea (regla del plan de mejoras, Fase 6.22).
class PricedStructureLine {
  const PricedStructureLine({
    required this.label,
    required this.quantityLabel,
    required this.quantity,
    this.unitPriceMxn,
    this.matchedProduct,
  });

  final String label;
  final String quantityLabel;
  final double quantity;
  final double? unitPriceMxn;
  final MaterialCatalogProduct? matchedProduct;

  bool get hasPrice => unitPriceMxn != null;

  double? get lineTotalMxn => hasPrice ? unitPriceMxn! * quantity : null;
}

/// Convierte el BOM de estructura calculado en `StructureDesignRules` en
/// líneas con precio, buscando el mejor producto activo del catálogo
/// comercial importado (Fase 6.22).
///
/// El emparejamiento primario usa `tipo_elemento_estructura` (columna real
/// del Excel estándar de MacBec, verificada contra
/// `Plantilla_Catalogo_MacBec_ESTRUCTURA_REVISADA.xlsx`: valores como
/// RIEL, PERFIL_PTR, PERFIL_ANGULO_ALUMINIO, CLAMP_INTERMEDIO, CLAMP_FINAL,
/// ANCLAJE_QUIMICO), que es mucho más confiable que buscar palabras clave
/// en la descripción libre (algunos productos reales llegan con nombres
/// como "Mid Clam"/"End Clam", sin la "p" final). Si un producto no trae
/// `tipo_elemento_estructura` (columna opcional), se cae a una búsqueda de
/// palabras clave sobre subcategoría/marca/modelo/descripción.
class StructureMaterialPricer {
  const StructureMaterialPricer._();

  static const _structureCategoryKeywords = ['ESTRUCTURA'];

  static List<PricedStructureLine> price({
    required InclinedFlatRoofResult result,
    required StructureAngleMaterial angleMaterial,
    required StructureFixingType fixingType,
    required List<MaterialCatalogProduct> catalog,
  }) {
    final structureCatalog = catalog
        .where(
          (product) => _structureCategoryKeywords.any(
            (keyword) => product.categoriaApp.toUpperCase().contains(keyword),
          ),
        )
        .toList();

    final railPlan = result.railPlan;
    final anglePlan = result.anglePlan;

    final lines = <PricedStructureLine>[
      _buildLine(
        label: 'Riel nominal 5 m',
        quantity: railPlan.fiveMeterRails.toDouble(),
        quantityLabel: '${railPlan.fiveMeterRails} tramos',
        product: _findByStructureType(
              structureCatalog,
              'RIEL',
              nominalLengthMeters: 5,
            ) ??
            _findBestMatch(
              structureCatalog,
              mustContainAll: const ['RIEL'],
              mustContainAny: const ['5 M', '5M', 'CINCO'],
            ),
      ),
      _buildLine(
        label: 'Riel nominal 6 m',
        quantity: railPlan.sixMeterRails.toDouble(),
        quantityLabel: '${railPlan.sixMeterRails} tramos',
        product: _findByStructureType(
              structureCatalog,
              'RIEL',
              nominalLengthMeters: 6,
            ) ??
            _findBestMatch(
              structureCatalog,
              mustContainAll: const ['RIEL'],
              mustContainAny: const ['6 M', '6M', 'SEIS'],
            ),
      ),
      _buildLine(
        label: 'Material de ángulo (${angleMaterial.label})',
        quantity: anglePlan.sixMeterSections.toDouble(),
        quantityLabel: '${anglePlan.sixMeterSections} tramos de 6 m',
        product: _findByStructureType(
              structureCatalog,
              angleMaterial == StructureAngleMaterial.steelPtr
                  ? 'PERFIL_PTR'
                  : 'PERFIL_ANGULO_ALUMINIO',
            ) ??
            _findBestMatch(
              structureCatalog,
              mustContainAll: const [],
              mustContainAny: angleMaterial == StructureAngleMaterial.steelPtr
                  ? const ['PTR']
                  : const ['ANGULO ALUMINIO', 'ÁNGULO ALUMINIO'],
            ),
      ),
      _buildLine(
        label: 'Mid clamps',
        quantity: result.midClampCount.toDouble(),
        quantityLabel: '${result.midClampCount} piezas',
        product: _findByStructureType(structureCatalog, 'CLAMP_INTERMEDIO') ??
            _findBestMatch(
              structureCatalog,
              mustContainAll: const [],
              mustContainAny: const ['MID CLAM', 'MIDCLAMP', 'CLAMP MEDIO'],
            ),
      ),
      _buildLine(
        label: 'End clamps',
        quantity: result.endClampCount.toDouble(),
        quantityLabel: '${result.endClampCount} piezas',
        product: _findByStructureType(structureCatalog, 'CLAMP_FINAL') ??
            _findBestMatch(
              structureCatalog,
              mustContainAll: const [],
              mustContainAny: const ['END CLAM', 'ENDCLAMP', 'CLAMP FINAL'],
            ),
      ),
      _buildLine(
        label: fixingType.shortLabel,
        quantity: result.fixingPiecesPerTypeCount.toDouble(),
        quantityLabel: '${result.fixingPiecesPerTypeCount} piezas',
        product: _findByStructureType(structureCatalog, 'TUERCA') ??
            _findBestMatch(
              structureCatalog,
              mustContainAll: const [],
              mustContainAny: const ['TUERCA', 'RONDANA', 'FIJACION', 'FIJACIÓN'],
            ),
      ),
    ];

    if (fixingType == StructureFixingType.chemicalAnchor) {
      lines.add(
        _buildLine(
          label: 'Cartuchos de anclaje químico',
          quantity: result.chemicalAnchorCartridgeCount.toDouble(),
          quantityLabel: '${result.chemicalAnchorCartridgeCount} cartuchos',
          product: _findByStructureType(structureCatalog, 'ANCLAJE_QUIMICO') ??
              _findBestMatch(
                structureCatalog,
                mustContainAll: const [],
                mustContainAny: const [
                  'ANCLAJE QUIMICO',
                  'ANCLAJE QUÍMICO',
                  'FESTER',
                ],
              ),
        ),
      );
    }

    return lines;
  }

  static PricedStructureLine _buildLine({
    required String label,
    required double quantity,
    required String quantityLabel,
    required MaterialCatalogProduct? product,
  }) {
    return PricedStructureLine(
      label: label,
      quantity: quantity,
      quantityLabel: quantityLabel,
      unitPriceMxn: product?.effectivePriceMxn,
      matchedProduct: product,
    );
  }

  /// Busca por la columna estructurada `tipo_elemento_estructura` (exacta,
  /// insensible a mayúsculas). Si se pasa [nominalLengthMeters], además
  /// exige que `longitud_nominal_m` coincida dentro de una tolerancia de
  /// 0.05 m, para distinguir p. ej. riel de 5 m vs 6 m sin depender de
  /// texto libre.
  static MaterialCatalogProduct? _findByStructureType(
    List<MaterialCatalogProduct> catalog,
    String tipoElementoEstructura, {
    double? nominalLengthMeters,
  }) {
    for (final product in catalog) {
      final type = product.tipoElementoEstructura?.trim().toUpperCase();
      if (type != tipoElementoEstructura) continue;

      if (nominalLengthMeters != null) {
        final length = product.longitudNominalM;
        if (length == null ||
            (length - nominalLengthMeters).abs() > 0.05) {
          continue;
        }
      }

      return product;
    }

    return null;
  }

  static MaterialCatalogProduct? _findBestMatch(
    List<MaterialCatalogProduct> catalog, {
    required List<String> mustContainAll,
    required List<String> mustContainAny,
  }) {
    for (final product in catalog) {
      final haystack = _searchableText(product);

      final matchesAll =
          mustContainAll.every((keyword) => haystack.contains(keyword));
      final matchesAny = mustContainAny.isEmpty ||
          mustContainAny.any((keyword) => haystack.contains(keyword));

      if (matchesAll && matchesAny) return product;
    }

    return null;
  }

  static String _searchableText(MaterialCatalogProduct product) {
    return [
      product.subcategoria,
      product.marca,
      product.modelo,
      product.descripcion,
    ].where((value) => value != null).join(' ').toUpperCase();
  }
}
