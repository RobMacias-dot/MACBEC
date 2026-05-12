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

    return rows
        .map(
          (row) => client_entity.Client(
            id: row.id,
            fullName: row.fullName,
            phone: row.phone,
            email: row.email,
            address: row.address,
            notes: row.notes,
          ),
        )
        .toList();
  }
}
