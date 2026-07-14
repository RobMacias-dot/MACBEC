import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/local/database/database_provider.dart';
import '../domain/entities/client_fiscal_profile.dart';

final clientFiscalRepositoryProvider = Provider<ClientFiscalRepository>((ref) {
  return ClientFiscalRepository(ref.watch(appDatabaseProvider));
});

final clientFiscalProfileProvider =
    FutureProvider.family<ClientFiscalProfile?, String>((ref, clientId) async {
  return ref.watch(clientFiscalRepositoryProvider).getByClientId(clientId);
});

class ClientFiscalRepository {
  ClientFiscalRepository(this._database);

  final AppDatabase _database;

  Future<ClientFiscalProfile?> getByClientId(String clientId) async {
    final query = _database.select(_database.clientFiscalData)
      ..where(
        (table) =>
            table.clientId.equals(clientId) & table.isDeleted.equals(false),
      )
      ..limit(1);

    final row = await query.getSingleOrNull();

    if (row == null) return null;

    return _mapRowToEntity(row);
  }

  Future<void> upsert({
    required String clientId,
    required SaveClientFiscalProfileInput input,
  }) async {
    final now = DateTime.now();

    final existing = await (_database.select(_database.clientFiscalData)
          ..where(
            (table) =>
                table.clientId.equals(clientId) &
                table.isDeleted.equals(false),
          ))
        .getSingleOrNull();

    if (existing == null) {
      await _database.into(_database.clientFiscalData).insert(
            ClientFiscalDataCompanion.insert(
              clientId: clientId,
              rfc: Value(_cleanNullableText(input.rfc)),
              legalName: Value(_cleanNullableText(input.legalName)),
              fiscalRegime: Value(_cleanNullableText(input.fiscalRegime)),
              fiscalZipCode: Value(_cleanNullableText(input.fiscalZipCode)),
              cfdiUse: Value(_cleanNullableText(input.cfdiUse)),
              invoiceEmail: Value(_cleanNullableText(input.invoiceEmail)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      return;
    }

    await (_database.update(_database.clientFiscalData)
          ..where((table) => table.id.equals(existing.id)))
        .write(
      ClientFiscalDataCompanion(
        rfc: Value(_cleanNullableText(input.rfc)),
        legalName: Value(_cleanNullableText(input.legalName)),
        fiscalRegime: Value(_cleanNullableText(input.fiscalRegime)),
        fiscalZipCode: Value(_cleanNullableText(input.fiscalZipCode)),
        cfdiUse: Value(_cleanNullableText(input.cfdiUse)),
        invoiceEmail: Value(_cleanNullableText(input.invoiceEmail)),
        updatedAt: Value(now),
      ),
    );
  }

  ClientFiscalProfile _mapRowToEntity(ClientFiscalDataData row) {
    return ClientFiscalProfile(
      clientId: row.clientId,
      rfc: row.rfc,
      legalName: row.legalName,
      fiscalRegime: row.fiscalRegime,
      fiscalZipCode: row.fiscalZipCode,
      cfdiUse: row.cfdiUse,
      invoiceEmail: row.invoiceEmail,
    );
  }

  String? _cleanNullableText(String? value) {
    final cleanValue = value?.trim() ?? '';
    return cleanValue.isEmpty ? null : cleanValue;
  }
}
