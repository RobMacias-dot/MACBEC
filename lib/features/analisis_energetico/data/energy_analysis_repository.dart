import 'package:drift/drift.dart';

import '../../../data/local/database/app_database.dart';
import '../domain/entities/quotation_draft_consumption.dart'
    as consumption_entity;

class EnergyAnalysisRepository {
  EnergyAnalysisRepository(this._database);

  final AppDatabase _database;

  Future<List<consumption_entity.QuotationDraftConsumption>>
      getDraftConsumptions(
    String quotationDraftId,
  ) async {
    final query = _database.select(_database.quotationDraftConsumptions)
      ..where(
        (table) =>
            table.quotationDraftId.equals(quotationDraftId) &
            table.isDeleted.equals(false),
      )
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
      ]);

    final rows = await query.get();

    return rows.map(_mapConsumptionRowToEntity).toList();
  }

  Future<void> replaceDraftConsumptions({
    required String quotationDraftId,
    required List<consumption_entity.SaveQuotationDraftConsumptionInput>
        consumptions,
  }) async {
    final now = DateTime.now();

    await _database.transaction(() async {
      await (_database.delete(_database.quotationDraftConsumptions)
            ..where(
              (table) => table.quotationDraftId.equals(quotationDraftId),
            ))
          .go();

      for (final consumption in consumptions) {
        if (consumption.kwh <= 0) continue;

        await _database.into(_database.quotationDraftConsumptions).insert(
              QuotationDraftConsumptionsCompanion.insert(
                quotationDraftId: quotationDraftId,
                periodLabel: Value(_cleanNullableText(consumption.periodLabel)),
                kwh: consumption.kwh,
                amount: Value(consumption.amount),
                sortOrder: consumption.sortOrder,
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
    });
  }

  consumption_entity.QuotationDraftConsumption _mapConsumptionRowToEntity(
    QuotationDraftConsumption row,
  ) {
    return consumption_entity.QuotationDraftConsumption(
      id: row.id,
      quotationDraftId: row.quotationDraftId,
      periodLabel: row.periodLabel,
      kwh: row.kwh,
      amount: row.amount,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String? _cleanNullableText(String? value) {
    final cleanValue = value?.trim() ?? '';
    return cleanValue.isEmpty ? null : cleanValue;
  }
}
