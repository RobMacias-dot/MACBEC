import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/local/database/database_provider.dart';
import '../../../data/sync/sync_service.dart';
import '../domain/entities/solar_radiation_record.dart';

const _stateAverageMunicipality = '(promedio estatal)';

final solarRadiationRepositoryProvider =
    Provider<SolarRadiationRepository>((ref) {
  return SolarRadiationRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncServiceProvider),
  );
});

class SolarRadiationRepository {
  SolarRadiationRepository(this._database, this._syncService);

  final AppDatabase _database;
  final SyncService _syncService;

  Future<SolarRadiationRecord?> getStateAverage(String stateName) async {
    final query = _database.select(_database.solarRadiation)
      ..where(
        (table) =>
            table.stateName.equals(stateName) &
            table.municipality.equals(_stateAverageMunicipality) &
            table.isDeleted.equals(false),
      )
      ..limit(1);

    final row = await query.getSingleOrNull();

    if (row == null) return null;

    return _mapRowToEntity(row);
  }

  Future<SolarRadiationRecord> upsertStateAverage({
    required String stateName,
    required double peakSunHours,
    double? latitude,
    double? longitude,
    String source = 'NASA POWER',
  }) async {
    final now = DateTime.now();

    final existing = await (_database.select(_database.solarRadiation)
          ..where(
            (table) =>
                table.stateName.equals(stateName) &
                table.municipality.equals(_stateAverageMunicipality) &
                table.isDeleted.equals(false),
          ))
        .getSingleOrNull();

    String recordId;

    if (existing == null) {
      final inserted = await _database.into(_database.solarRadiation).insertReturning(
            SolarRadiationCompanion.insert(
              stateName: stateName,
              municipality: _stateAverageMunicipality,
              latitude: Value(latitude),
              longitude: Value(longitude),
              peakSunHours: peakSunHours,
              source: Value(source),
              sourceUpdatedAt: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      recordId = inserted.id;
    } else {
      recordId = existing.id;

      await (_database.update(_database.solarRadiation)
            ..where((table) => table.id.equals(existing.id)))
          .write(
        SolarRadiationCompanion(
          latitude: Value(latitude),
          longitude: Value(longitude),
          peakSunHours: Value(peakSunHours),
          source: Value(source),
          sourceUpdatedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }

    await _syncService.enqueue(
      entityType: 'solar_radiation',
      entityId: recordId,
      operation: 'upsert',
      payloadJson: jsonEncode({
        'stateName': stateName,
        'peakSunHours': peakSunHours,
        'source': source,
      }),
    );

    final saved = await getStateAverage(stateName);
    return saved!;
  }

  SolarRadiationRecord _mapRowToEntity(SolarRadiationData row) {
    return SolarRadiationRecord(
      id: row.id,
      stateName: row.stateName,
      municipality: row.municipality,
      latitude: row.latitude,
      longitude: row.longitude,
      peakSunHours: row.peakSunHours,
      source: row.source,
      sourceUpdatedAt: row.sourceUpdatedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
