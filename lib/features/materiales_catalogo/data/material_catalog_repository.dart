import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/local/database/database_provider.dart';
import '../domain/entities/material_catalog_product.dart' as material_entity;

final materialCatalogRepositoryProvider =
    Provider<MaterialCatalogRepository>((ref) {
  return MaterialCatalogRepository(ref.watch(appDatabaseProvider));
});

final materialCatalogProductsProvider =
    FutureProvider<List<material_entity.MaterialCatalogProduct>>((ref) async {
  return ref.watch(materialCatalogRepositoryProvider).getAll();
});

class MaterialCatalogRepository {
  MaterialCatalogRepository(this._database);

  final AppDatabase _database;

  Future<List<material_entity.MaterialCatalogProduct>> getAll() async {
    final query = _database.select(_database.materialCatalogProducts)
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([
        (table) => OrderingTerm.asc(table.categoriaApp),
        (table) => OrderingTerm.asc(table.subcategoria),
      ]);

    final rows = await query.get();

    return rows.map(_mapRowToEntity).toList();
  }

  Future<List<material_entity.MaterialCatalogProduct>> getByCategory(
    String categoriaApp,
  ) async {
    final query = _database.select(_database.materialCatalogProducts)
      ..where(
        (table) =>
            table.categoriaApp.equals(categoriaApp) &
            table.isDeleted.equals(false),
      );

    final rows = await query.get();

    return rows.map(_mapRowToEntity).toList();
  }

  /// Inserta o actualiza. Si el producto trae `codigo_interno` (columna
  /// real del Excel estándar, presente en algunas filas de ESTRUCTURA) se
  /// usa como llave única; si no, se usa la combinación categoria_app +
  /// subcategoria + marca + modelo. Devuelve `true` si se creó un producto
  /// nuevo.
  Future<bool> upsertProduct(
    material_entity.SaveMaterialCatalogProductInput input,
  ) async {
    final normalizedCode = input.codigoInterno?.trim().toLowerCase();
    final normalizedCategory = input.categoriaApp.trim().toLowerCase();
    final normalizedSubcategory =
        input.subcategoria?.trim().toLowerCase() ?? '';
    final normalizedBrand = input.marca?.trim().toLowerCase() ?? '';
    final normalizedModel = input.modelo?.trim().toLowerCase() ?? '';

    final rows = await (_database.select(_database.materialCatalogProducts)
          ..where((table) => table.isDeleted.equals(false)))
        .get();

    MaterialCatalogProduct? existingRow;

    for (final row in rows) {
      final matches = (normalizedCode != null && normalizedCode.isNotEmpty)
          ? (row.codigoInterno?.trim().toLowerCase() ?? '') == normalizedCode
          : row.categoriaApp.trim().toLowerCase() == normalizedCategory &&
              (row.subcategoria?.trim().toLowerCase() ?? '') ==
                  normalizedSubcategory &&
              (row.marca?.trim().toLowerCase() ?? '') == normalizedBrand &&
              (row.modelo?.trim().toLowerCase() ?? '') == normalizedModel;

      if (matches) {
        existingRow = row;
        break;
      }
    }

    final now = DateTime.now();

    if (existingRow == null) {
      await _database.into(_database.materialCatalogProducts).insert(
            MaterialCatalogProductsCompanion.insert(
              codigoInterno: Value(_cleanNullableText(input.codigoInterno)),
              categoriaApp: input.categoriaApp.trim(),
              subcategoria: Value(_cleanNullableText(input.subcategoria)),
              marca: Value(_cleanNullableText(input.marca)),
              modelo: Value(_cleanNullableText(input.modelo)),
              descripcion: Value(_cleanNullableText(input.descripcion)),
              unidadCompra: Value(_cleanNullableText(input.unidadCompra)),
              moneda: Value(input.moneda),
              precioCompra: Value(input.precioCompra),
              precioMxn: Value(input.precioMxn),
              activo: Value(input.activo),
              revisarPrecio: Value(input.revisarPrecio),
              estadoParaCalculo:
                  Value(_cleanNullableText(input.estadoParaCalculo)),
              longitudNominalM: Value(input.longitudNominalM),
              longitudUtilCalculoM: Value(input.longitudUtilCalculoM),
              tipoElementoEstructura:
                  Value(_cleanNullableText(input.tipoElementoEstructura)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      return true;
    }

    await (_database.update(_database.materialCatalogProducts)
          ..where((table) => table.id.equals(existingRow!.id)))
        .write(
      MaterialCatalogProductsCompanion(
        codigoInterno: Value(_cleanNullableText(input.codigoInterno)),
        categoriaApp: Value(input.categoriaApp.trim()),
        subcategoria: Value(_cleanNullableText(input.subcategoria)),
        marca: Value(_cleanNullableText(input.marca)),
        modelo: Value(_cleanNullableText(input.modelo)),
        descripcion: Value(_cleanNullableText(input.descripcion)),
        unidadCompra: Value(_cleanNullableText(input.unidadCompra)),
        moneda: Value(input.moneda),
        precioCompra: Value(input.precioCompra),
        precioMxn: Value(input.precioMxn),
        activo: Value(input.activo),
        revisarPrecio: Value(input.revisarPrecio),
        estadoParaCalculo: Value(_cleanNullableText(input.estadoParaCalculo)),
        longitudNominalM: Value(input.longitudNominalM),
        longitudUtilCalculoM: Value(input.longitudUtilCalculoM),
        tipoElementoEstructura:
            Value(_cleanNullableText(input.tipoElementoEstructura)),
        updatedAt: Value(now),
      ),
    );

    return false;
  }

  material_entity.MaterialCatalogProduct _mapRowToEntity(
    MaterialCatalogProduct row,
  ) {
    return material_entity.MaterialCatalogProduct(
      id: row.id,
      codigoInterno: row.codigoInterno,
      categoriaApp: row.categoriaApp,
      subcategoria: row.subcategoria,
      marca: row.marca,
      modelo: row.modelo,
      descripcion: row.descripcion,
      unidadCompra: row.unidadCompra,
      moneda: row.moneda,
      precioCompra: row.precioCompra,
      precioMxn: row.precioMxn,
      activo: row.activo,
      revisarPrecio: row.revisarPrecio,
      estadoParaCalculo: row.estadoParaCalculo,
      longitudNominalM: row.longitudNominalM,
      longitudUtilCalculoM: row.longitudUtilCalculoM,
      tipoElementoEstructura: row.tipoElementoEstructura,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String? _cleanNullableText(String? value) {
    final cleanValue = value?.trim() ?? '';
    return cleanValue.isEmpty ? null : cleanValue;
  }
}
