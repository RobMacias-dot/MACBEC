import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/local/database/database_provider.dart';
import '../domain/entities/structure_design_selection.dart';

final structureDesignRepositoryProvider =
    Provider<StructureDesignRepository>((ref) {
  return StructureDesignRepository(ref.watch(appDatabaseProvider));
});

final structureDesignSelectionProvider =
    FutureProvider.family<StructureDesignSelection?, String>(
  (ref, quotationDraftId) async {
    return ref
        .watch(structureDesignRepositoryProvider)
        .getDraftSelection(quotationDraftId);
  },
);

class StructureDesignRepository {
  StructureDesignRepository(this._database);

  final AppDatabase _database;

  Future<StructureDesignSelection?> getDraftSelection(
    String quotationDraftId,
  ) async {
    final query = _database.select(_database.quotationDraftStructureDesigns)
      ..where(
        (table) =>
            table.quotationDraftId.equals(quotationDraftId) &
            table.isDeleted.equals(false),
      )
      ..orderBy([
        (table) => OrderingTerm.desc(table.updatedAt),
      ])
      ..limit(1);

    final row = await query.getSingleOrNull();

    if (row == null) return null;

    return _mapRowToEntity(row);
  }

  Future<void> upsertDraftSelection({
    required String quotationDraftId,
    required SaveStructureDesignSelectionInput selection,
  }) async {
    final now = DateTime.now();

    final existing = await (_database.select(
      _database.quotationDraftStructureDesigns,
    )..where(
            (table) =>
                table.quotationDraftId.equals(quotationDraftId) &
                table.isDeleted.equals(false),
          ))
        .getSingleOrNull();

    if (existing == null) {
      await _database.into(_database.quotationDraftStructureDesigns).insert(
            QuotationDraftStructureDesignsCompanion.insert(
              quotationDraftId: quotationDraftId,
              mountType: selection.mountType,
              fixingType: selection.fixingType,
              structuresCount: selection.structuresCount,
              panelsHorizontal: selection.panelsHorizontal,
              panelRows: selection.panelRows,
              inclinationDegrees: selection.inclinationDegrees,
              frontLegCm: selection.frontLegCm,
              angleMaterial: Value(selection.angleMaterial),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      return;
    }

    await (_database.update(_database.quotationDraftStructureDesigns)
          ..where((table) => table.id.equals(existing.id)))
        .write(
      QuotationDraftStructureDesignsCompanion(
        mountType: Value(selection.mountType),
        fixingType: Value(selection.fixingType),
        structuresCount: Value(selection.structuresCount),
        panelsHorizontal: Value(selection.panelsHorizontal),
        panelRows: Value(selection.panelRows),
        inclinationDegrees: Value(selection.inclinationDegrees),
        frontLegCm: Value(selection.frontLegCm),
        angleMaterial: Value(selection.angleMaterial),
        updatedAt: Value(now),
      ),
    );
  }

  StructureDesignSelection _mapRowToEntity(
    QuotationDraftStructureDesign row,
  ) {
    return StructureDesignSelection(
      id: row.id,
      quotationDraftId: row.quotationDraftId,
      mountType: row.mountType,
      fixingType: row.fixingType,
      structuresCount: row.structuresCount,
      panelsHorizontal: row.panelsHorizontal,
      panelRows: row.panelRows,
      inclinationDegrees: row.inclinationDegrees,
      frontLegCm: row.frontLegCm,
      angleMaterial: row.angleMaterial,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
