import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart' as db;
import '../../../data/local/database/database_provider.dart';
import '../domain/entities/company_profile.dart';

final companySettingsRepositoryProvider =
    Provider<CompanySettingsRepository>((ref) {
  return CompanySettingsRepository(
    database: ref.watch(appDatabaseProvider),
  );
});

class CompanySettingsRepository {
  const CompanySettingsRepository({
    required db.AppDatabase database,
  }) : _database = database;

  final db.AppDatabase _database;

  Future<CompanyProfile?> getCompanyProfile() async {
    final query = _database.select(_database.companySettings)
      ..where((settings) => settings.isDeleted.equals(false))
      ..orderBy([
        (settings) => OrderingTerm.desc(settings.updatedAt),
      ])
      ..limit(1);

    final result = await query.getSingleOrNull();

    if (result == null) {
      return null;
    }

    return _toProfile(result);
  }

  Future<CompanyProfile> saveCompanyProfile(CompanyProfile profile) async {
    final existingProfile = await getCompanyProfile();
    final now = DateTime.now();

    if (existingProfile == null) {
      final inserted =
          await _database.into(_database.companySettings).insertReturning(
                db.CompanySettingsCompanion.insert(
                  companyName: profile.companyName.trim(),
                  rfc: Value(_emptyToNull(profile.rfc)),
                  phone: Value(_emptyToNull(profile.phone)),
                  email: Value(_emptyToNull(profile.email)),
                  address: Value(_emptyToNull(profile.address)),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );

      return _toProfile(inserted);
    }

    await (_database.update(_database.companySettings)
          ..where((settings) => settings.id.equals(existingProfile.id!)))
        .write(
      db.CompanySettingsCompanion(
        companyName: Value(profile.companyName.trim()),
        rfc: Value(_emptyToNull(profile.rfc)),
        phone: Value(_emptyToNull(profile.phone)),
        email: Value(_emptyToNull(profile.email)),
        address: Value(_emptyToNull(profile.address)),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    final updatedProfile = await getCompanyProfile();

    if (updatedProfile == null) {
      throw const CompanySettingsException(
        'No se pudo recuperar la configuración de empresa actualizada.',
      );
    }

    return updatedProfile;
  }

  CompanyProfile _toProfile(db.CompanySetting setting) {
    return CompanyProfile(
      id: setting.id,
      companyName: setting.companyName,
      rfc: setting.rfc ?? '',
      phone: setting.phone ?? '',
      email: setting.email ?? '',
      address: setting.address ?? '',
    );
  }

  String? _emptyToNull(String value) {
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }
}

class CompanySettingsException implements Exception {
  const CompanySettingsException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
