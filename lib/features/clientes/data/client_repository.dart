import 'package:drift/drift.dart';

import '../../../data/local/database/app_database.dart';
import '../domain/entities/client.dart' as client_entity;

class ClientRepository {
  ClientRepository(this._database);

  final AppDatabase _database;

  Future<List<client_entity.Client>> getAll() async {
    final query = _database.select(_database.clients)
      ..where((client) => client.isDeleted.equals(false))
      ..orderBy([(client) => OrderingTerm.asc(client.fullName)]);

    final rows = await query.get();

    return rows.map(_mapRowToEntity).toList();
  }

  Future<client_entity.Client?> getById(String clientId) async {
    final query = _database.select(_database.clients)
      ..where(
        (client) => client.id.equals(clientId) & client.isDeleted.equals(false),
      );

    final row = await query.getSingleOrNull();

    if (row == null) return null;

    return _mapRowToEntity(row);
  }

  Future<String> create(client_entity.SaveClientInput input) async {
    final now = DateTime.now();

    final row = await _database.into(_database.clients).insertReturning(
          ClientsCompanion.insert(
            fullName: input.fullName.trim(),
            phone: Value(_cleanNullableText(input.phone)),
            email: Value(_cleanNullableText(input.email)),
            address: Value(_cleanNullableText(input.address)),
            notes: Value(_cleanNullableText(input.notes)),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return row.id;
  }

  Future<void> update({
    required String clientId,
    required client_entity.SaveClientInput input,
  }) async {
    final now = DateTime.now();

    await (_database.update(_database.clients)
          ..where((client) => client.id.equals(clientId)))
        .write(
      ClientsCompanion(
        fullName: Value(input.fullName.trim()),
        phone: Value(_cleanNullableText(input.phone)),
        email: Value(_cleanNullableText(input.email)),
        address: Value(_cleanNullableText(input.address)),
        notes: Value(_cleanNullableText(input.notes)),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> delete(String clientId) async {
    final now = DateTime.now();

    await (_database.update(_database.clients)
          ..where((client) => client.id.equals(clientId)))
        .write(
      ClientsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  client_entity.Client _mapRowToEntity(Client row) {
    return client_entity.Client(
      id: row.id,
      fullName: row.fullName,
      phone: row.phone,
      email: row.email,
      address: row.address,
      notes: row.notes,
    );
  }

  String? _cleanNullableText(String? value) {
    final cleanValue = value?.trim() ?? '';
    return cleanValue.isEmpty ? null : cleanValue;
  }
}
