import '../../../data/local/database/app_database.dart';
import '../domain/entities/client.dart' as client_entity;

class ClientRepository {
  ClientRepository(this._database);

  final AppDatabase _database;

  Future<List<client_entity.Client>> getAll() async {
    final rows = await _database.select(_database.clients).get();
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
