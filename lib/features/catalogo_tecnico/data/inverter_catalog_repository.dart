import 'package:drift/drift.dart';

import '../../../data/local/database/app_database.dart';
import '../domain/entities/solar_inverter.dart';

class InverterCatalogRepository {
  InverterCatalogRepository(this._database);

  final AppDatabase _database;

  Future<List<SolarInverter>> getAllInverters() async {
    final query = _database.select(_database.inverters)
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([
        (table) => OrderingTerm.asc(table.brand),
        (table) => OrderingTerm.asc(table.model),
      ]);

    final rows = await query.get();

    return rows.map(_mapRowToEntity).toList();
  }

  Future<String> createInverter(SaveSolarInverterInput input) async {
    final now = DateTime.now();

    final row = await _database.into(_database.inverters).insertReturning(
          InvertersCompanion.insert(
            brand: input.brand.trim(),
            model: input.model.trim(),
            nominalPowerWatts: input.nominalPowerWatts,
            maxPvPowerWatts: Value(input.maxPvPowerWatts),
            maxDcVoltage: Value(input.maxDcVoltage),
            maxShortCircuitCurrentPerMppt: Value(
              input.maxShortCircuitCurrentPerMppt,
            ),
            maxOutputCurrent: Value(input.maxOutputCurrent),
            mpptCount: Value(input.mpptCount),
            purchasePrice: Value(input.purchasePrice),
            lastPriceUpdateAt: Value(now),
            priceSource: Value(input.priceSource),
            requiresPriceReview: Value(input.requiresPriceReview),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return row.id;
  }

  Future<void> updateInverter({
    required String inverterId,
    required SaveSolarInverterInput input,
  }) async {
    final now = DateTime.now();

    await (_database.update(_database.inverters)
          ..where((table) => table.id.equals(inverterId)))
        .write(
      InvertersCompanion(
        brand: Value(input.brand.trim()),
        model: Value(input.model.trim()),
        nominalPowerWatts: Value(input.nominalPowerWatts),
        maxPvPowerWatts: Value(input.maxPvPowerWatts),
        maxDcVoltage: Value(input.maxDcVoltage),
        maxShortCircuitCurrentPerMppt: Value(
          input.maxShortCircuitCurrentPerMppt,
        ),
        maxOutputCurrent: Value(input.maxOutputCurrent),
        mpptCount: Value(input.mpptCount),
        purchasePrice: Value(input.purchasePrice),
        lastPriceUpdateAt: Value(now),
        priceSource: Value(input.priceSource),
        requiresPriceReview: Value(input.requiresPriceReview),
        updatedAt: Value(now),
      ),
    );
  }

  Future<bool> upsertInverterByBrandAndModel(
    SaveSolarInverterInput input,
  ) async {
    final normalizedBrand = input.brand.trim().toLowerCase();
    final normalizedModel = input.model.trim().toLowerCase();

    final rows = await (_database.select(_database.inverters)
          ..where((table) => table.isDeleted.equals(false)))
        .get();

    Inverter? existingInverter;

    for (final row in rows) {
      if (row.brand.trim().toLowerCase() == normalizedBrand &&
          row.model.trim().toLowerCase() == normalizedModel) {
        existingInverter = row;
        break;
      }
    }

    if (existingInverter == null) {
      await createInverter(input);
      return true;
    }

    await updateInverter(
      inverterId: existingInverter.id,
      input: input,
    );

    return false;
  }

  Future<void> softDeleteInverter(String inverterId) async {
    final now = DateTime.now();

    await (_database.update(_database.inverters)
          ..where((table) => table.id.equals(inverterId)))
        .write(
      InvertersCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  SolarInverter _mapRowToEntity(Inverter row) {
    return SolarInverter(
      id: row.id,
      brand: row.brand,
      model: row.model,
      nominalPowerWatts: row.nominalPowerWatts,
      maxPvPowerWatts: row.maxPvPowerWatts,
      maxDcVoltage: row.maxDcVoltage,
      maxShortCircuitCurrentPerMppt: row.maxShortCircuitCurrentPerMppt,
      maxOutputCurrent: row.maxOutputCurrent,
      mpptCount: row.mpptCount,
      purchasePrice: row.purchasePrice,
      priceSource: row.priceSource,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
