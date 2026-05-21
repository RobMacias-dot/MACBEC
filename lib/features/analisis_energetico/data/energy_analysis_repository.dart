import 'package:drift/drift.dart';

import '../../../data/local/database/app_database.dart';
import '../../cotizaciones/domain/entities/quotation_draft.dart'
    as quotation_entity;
import '../domain/entities/quotation_draft_consumption.dart'
    as consumption_entity;
import '../domain/entities/quotation_draft_pv_calculation.dart' as pv_entity;

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

  Future<pv_entity.QuotationDraftPvCalculation?> getDraftPvCalculation(
    String quotationDraftId,
  ) async {
    final query = _database.select(_database.quotationDraftPvCalculations)
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

    return _mapPvCalculationRowToEntity(row);
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

  Future<void> updateDraftAnalysisSettings({
    required String quotationDraftId,
    required double peakSunHours,
    required double panelPowerWatts,
  }) async {
    final now = DateTime.now();

    final draft = await (_database.select(_database.quotationDrafts)
          ..where(
            (table) =>
                table.id.equals(quotationDraftId) &
                table.isDeleted.equals(false),
          ))
        .getSingleOrNull();

    if (draft == null) {
      throw StateError(
        'No existe un borrador activo válido para guardar el análisis energético.',
      );
    }

    var nextStatus = draft.status;

    if (draft.status == quotation_entity.QuotationDraftStatus.receiptPending ||
        draft.status == quotation_entity.QuotationDraftStatus.receiptReceived) {
      nextStatus = quotation_entity.QuotationDraftStatus.inAnalysis;
    }

    await (_database.update(_database.quotationDrafts)
          ..where((table) => table.id.equals(quotationDraftId)))
        .write(
      QuotationDraftsCompanion(
        status: Value(nextStatus),
        analysisPeakSunHours: Value(peakSunHours),
        analysisPanelPowerWatts: Value(panelPowerWatts),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> upsertDraftPvCalculation({
    required String quotationDraftId,
    required pv_entity.SaveQuotationDraftPvCalculationInput calculation,
  }) async {
    final now = DateTime.now();

    final existing = await (_database.select(
      _database.quotationDraftPvCalculations,
    )..where(
            (table) =>
                table.quotationDraftId.equals(quotationDraftId) &
                table.isDeleted.equals(false),
          ))
        .getSingleOrNull();

    if (existing == null) {
      await _database.into(_database.quotationDraftPvCalculations).insert(
            QuotationDraftPvCalculationsCompanion.insert(
              quotationDraftId: quotationDraftId,
              panelId: Value(_cleanNullableText(calculation.panelId)),
              annualConsumptionKwh: calculation.annualConsumptionKwh,
              dailyConsumptionKwh: calculation.dailyConsumptionKwh,
              peakSunHours: calculation.peakSunHours,
              panelPowerWatts: calculation.panelPowerWatts,
              lossFactor: Value(calculation.lossFactor),
              generationPerPanelKwhDay: calculation.generationPerPanelKwhDay,
              requiredPanels: calculation.requiredPanels,
              calculationSnapshotJson: Value(
                _cleanNullableText(calculation.calculationSnapshotJson),
              ),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      return;
    }

    await (_database.update(_database.quotationDraftPvCalculations)
          ..where((table) => table.id.equals(existing.id)))
        .write(
      QuotationDraftPvCalculationsCompanion(
        panelId: Value(_cleanNullableText(calculation.panelId)),
        annualConsumptionKwh: Value(calculation.annualConsumptionKwh),
        dailyConsumptionKwh: Value(calculation.dailyConsumptionKwh),
        peakSunHours: Value(calculation.peakSunHours),
        panelPowerWatts: Value(calculation.panelPowerWatts),
        lossFactor: Value(calculation.lossFactor),
        generationPerPanelKwhDay: Value(
          calculation.generationPerPanelKwhDay,
        ),
        requiredPanels: Value(calculation.requiredPanels),
        calculationSnapshotJson: Value(
          _cleanNullableText(calculation.calculationSnapshotJson),
        ),
        updatedAt: Value(now),
      ),
    );
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

  pv_entity.QuotationDraftPvCalculation _mapPvCalculationRowToEntity(
    QuotationDraftPvCalculation row,
  ) {
    return pv_entity.QuotationDraftPvCalculation(
      id: row.id,
      quotationDraftId: row.quotationDraftId,
      panelId: row.panelId,
      annualConsumptionKwh: row.annualConsumptionKwh,
      dailyConsumptionKwh: row.dailyConsumptionKwh,
      peakSunHours: row.peakSunHours,
      panelPowerWatts: row.panelPowerWatts,
      lossFactor: row.lossFactor,
      generationPerPanelKwhDay: row.generationPerPanelKwhDay,
      requiredPanels: row.requiredPanels,
      calculationSnapshotJson: row.calculationSnapshotJson,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String? _cleanNullableText(String? value) {
    final cleanValue = value?.trim() ?? '';
    return cleanValue.isEmpty ? null : cleanValue;
  }
}
