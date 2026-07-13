import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/local/database/database_provider.dart';
import '../domain/entities/electrical_selection.dart';

final electricalSelectionRepositoryProvider =
    Provider<ElectricalSelectionRepository>((ref) {
  return ElectricalSelectionRepository(ref.watch(appDatabaseProvider));
});

final electricalSelectionProvider =
    FutureProvider.family<ElectricalSelection?, String>(
  (ref, quotationDraftId) async {
    return ref
        .watch(electricalSelectionRepositoryProvider)
        .getDraftSelection(quotationDraftId);
  },
);

class ElectricalSelectionRepository {
  ElectricalSelectionRepository(this._database);

  final AppDatabase _database;

  Future<ElectricalSelection?> getDraftSelection(
    String quotationDraftId,
  ) async {
    final query =
        _database.select(_database.quotationDraftElectricalSelections)
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
    required SaveElectricalSelectionInput selection,
  }) async {
    final now = DateTime.now();

    final existing = await (_database.select(
      _database.quotationDraftElectricalSelections,
    )..where(
            (table) =>
                table.quotationDraftId.equals(quotationDraftId) &
                table.isDeleted.equals(false),
          ))
        .getSingleOrNull();

    if (existing == null) {
      await _database.into(_database.quotationDraftElectricalSelections).insert(
            QuotationDraftElectricalSelectionsCompanion.insert(
              quotationDraftId: quotationDraftId,
              inverterId: selection.inverterId,
              acDistanceMeters: Value(selection.acDistanceMeters),
              acVoltage: Value(selection.acVoltage),
              acMaterial: Value(selection.acMaterial),
              acPhaseType: Value(selection.acPhaseType),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      return;
    }

    await (_database.update(_database.quotationDraftElectricalSelections)
          ..where((table) => table.id.equals(existing.id)))
        .write(
      QuotationDraftElectricalSelectionsCompanion(
        inverterId: Value(selection.inverterId),
        acDistanceMeters: Value(selection.acDistanceMeters),
        acVoltage: Value(selection.acVoltage),
        acMaterial: Value(selection.acMaterial),
        acPhaseType: Value(selection.acPhaseType),
        updatedAt: Value(now),
      ),
    );
  }

  ElectricalSelection _mapRowToEntity(QuotationDraftElectricalSelection row) {
    return ElectricalSelection(
      id: row.id,
      quotationDraftId: row.quotationDraftId,
      inverterId: row.inverterId,
      acDistanceMeters: row.acDistanceMeters,
      acVoltage: row.acVoltage,
      acMaterial: row.acMaterial,
      acPhaseType: row.acPhaseType,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
