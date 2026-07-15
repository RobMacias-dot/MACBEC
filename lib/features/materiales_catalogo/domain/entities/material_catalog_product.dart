/// Estados conocidos de la columna `estado_para_calculo` del catálogo. Un
/// producto con estado PENDIENTE_DEFINIR nunca debe alimentar un cálculo de
/// cotización, aunque tenga un precio capturado.
class MaterialCatalogCalculationState {
  const MaterialCatalogCalculationState._();

  static const listo = 'LISTO';
  static const pendienteDefinir = 'PENDIENTE_DEFINIR';
}

class MaterialCatalogProduct {
  const MaterialCatalogProduct({
    required this.id,
    required this.categoriaApp,
    required this.activo,
    required this.revisarPrecio,
    required this.createdAt,
    required this.updatedAt,
    this.codigoInterno,
    this.subcategoria,
    this.marca,
    this.modelo,
    this.descripcion,
    this.unidadCompra,
    this.moneda = 'MXN',
    this.precioCompra,
    this.precioMxn,
    this.estadoParaCalculo,
    this.longitudNominalM,
    this.longitudUtilCalculoM,
    this.tipoElementoEstructura,
  });

  final String id;
  final String? codigoInterno;
  final String categoriaApp;
  final String? subcategoria;
  final String? marca;
  final String? modelo;
  final String? descripcion;
  final String? unidadCompra;
  final String moneda;
  final double? precioCompra;
  final double? precioMxn;
  final bool activo;
  final bool revisarPrecio;
  final String? estadoParaCalculo;
  final double? longitudNominalM;
  final double? longitudUtilCalculoM;
  final String? tipoElementoEstructura;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Precio a usar en cálculos, o `null` si el producto no está listo para
  /// cotizar (inactivo, con precio pendiente de revisión, o con estado
  /// PENDIENTE_DEFINIR). La UI debe mostrar "-" cuando esto es `null`,
  /// nunca 0 ni omitir la línea (regla del plan de mejoras, Fase 6.22).
  double? get effectivePriceMxn {
    if (!activo) return null;
    if (revisarPrecio) return null;
    if (estadoParaCalculo == MaterialCatalogCalculationState.pendienteDefinir) {
      return null;
    }
    return precioMxn;
  }

  String get displayLabel {
    final parts = <String>[
      if (marca != null && marca!.trim().isNotEmpty) marca!.trim(),
      if (modelo != null && modelo!.trim().isNotEmpty) modelo!.trim(),
    ];

    if (parts.isNotEmpty) return parts.join(' ');
    if (descripcion != null && descripcion!.trim().isNotEmpty) {
      return descripcion!.trim();
    }
    return subcategoria ?? categoriaApp;
  }
}

class SaveMaterialCatalogProductInput {
  const SaveMaterialCatalogProductInput({
    required this.categoriaApp,
    this.codigoInterno,
    this.subcategoria,
    this.marca,
    this.modelo,
    this.descripcion,
    this.unidadCompra,
    this.moneda = 'MXN',
    this.precioCompra,
    this.precioMxn,
    this.activo = true,
    this.revisarPrecio = false,
    this.estadoParaCalculo,
    this.longitudNominalM,
    this.longitudUtilCalculoM,
    this.tipoElementoEstructura,
  });

  final String categoriaApp;
  final String? codigoInterno;
  final String? subcategoria;
  final String? marca;
  final String? modelo;
  final String? descripcion;
  final String? unidadCompra;
  final String moneda;
  final double? precioCompra;
  final double? precioMxn;
  final bool activo;
  final bool revisarPrecio;
  final String? estadoParaCalculo;
  final double? longitudNominalM;
  final double? longitudUtilCalculoM;
  final String? tipoElementoEstructura;
}
