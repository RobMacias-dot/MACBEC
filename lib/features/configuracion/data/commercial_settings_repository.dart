import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart' as db;
import '../../../data/local/database/database_provider.dart';
import '../domain/entities/commercial_settings.dart';

final commercialSettingsRepositoryProvider =
    Provider<CommercialSettingsRepository>((ref) {
  return CommercialSettingsRepository(
    database: ref.watch(appDatabaseProvider),
  );
});

class CommercialSettingsRepository {
  const CommercialSettingsRepository({
    required db.AppDatabase database,
  }) : _database = database;

  final db.AppDatabase _database;

  static const _ivaRatePercentKey = 'commercial.iva_rate_percent';
  static const _generalUtilityRatePercentKey =
      'commercial.general_utility_rate_percent';
  static const _currencyKey = 'commercial.currency';
  static const _defaultQuotationValidityDaysKey =
      'commercial.default_quotation_validity_days';
  static const _quotationLegalNoteKey = 'commercial.quotation_legal_note';
  static const _warrantyNoteKey = 'commercial.warranty_note';

  Future<CommercialSettings> getCommercialSettings() async {
    const defaults = CommercialSettings.defaults();

    final ivaRatePercent = await _getDouble(
          _ivaRatePercentKey,
        ) ??
        defaults.ivaRatePercent;

    final generalUtilityRatePercent = await _getDouble(
          _generalUtilityRatePercentKey,
        ) ??
        defaults.generalUtilityRatePercent;

    final currency = await _getString(_currencyKey) ?? defaults.currency;

    final defaultQuotationValidityDays = await _getInt(
          _defaultQuotationValidityDaysKey,
        ) ??
        defaults.defaultQuotationValidityDays;

    final quotationLegalNote = await _getString(
          _quotationLegalNoteKey,
        ) ??
        defaults.quotationLegalNote;

    final warrantyNote = await _getString(
          _warrantyNoteKey,
        ) ??
        defaults.warrantyNote;

    return CommercialSettings(
      ivaRatePercent: ivaRatePercent,
      generalUtilityRatePercent: generalUtilityRatePercent,
      currency: currency,
      defaultQuotationValidityDays: defaultQuotationValidityDays,
      quotationLegalNote: quotationLegalNote,
      warrantyNote: warrantyNote,
    );
  }

  Future<CommercialSettings> saveCommercialSettings(
    CommercialSettings settings,
  ) async {
    await _database.transaction(() async {
      await _setString(
        key: _ivaRatePercentKey,
        value: _formatDouble(settings.ivaRatePercent),
      );

      await _setString(
        key: _generalUtilityRatePercentKey,
        value: _formatDouble(settings.generalUtilityRatePercent),
      );

      await _setString(
        key: _currencyKey,
        value: settings.currency.trim().toUpperCase(),
      );

      await _setString(
        key: _defaultQuotationValidityDaysKey,
        value: settings.defaultQuotationValidityDays.toString(),
      );

      await _setString(
        key: _quotationLegalNoteKey,
        value: settings.quotationLegalNote.trim(),
      );

      await _setString(
        key: _warrantyNoteKey,
        value: settings.warrantyNote.trim(),
      );
    });

    return getCommercialSettings();
  }

  Future<String?> _getString(String key) async {
    final query = _database.select(_database.appSettings)
      ..where(
        (settings) =>
            settings.key.equals(key) & settings.isDeleted.equals(false),
      )
      ..orderBy([
        (settings) => OrderingTerm.desc(settings.updatedAt),
      ])
      ..limit(1);

    final result = await query.getSingleOrNull();
    final value = result?.value?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  Future<double?> _getDouble(String key) async {
    final value = await _getString(key);

    if (value == null) {
      return null;
    }

    return double.tryParse(value.replaceAll(',', '.'));
  }

  Future<int?> _getInt(String key) async {
    final value = await _getString(key);

    if (value == null) {
      return null;
    }

    return int.tryParse(value);
  }

  Future<void> _setString({
    required String key,
    required String value,
  }) async {
    final now = DateTime.now();

    final updatedRows = await (_database.update(_database.appSettings)
          ..where(
            (settings) =>
                settings.key.equals(key) & settings.isDeleted.equals(false),
          ))
        .write(
      db.AppSettingsCompanion(
        value: Value(value),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    if (updatedRows > 0) {
      return;
    }

    await _database.into(_database.appSettings).insert(
          db.AppSettingsCompanion.insert(
            key: key,
            value: Value(value),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  String _formatDouble(double value) {
    return value.toStringAsFixed(4);
  }
}
