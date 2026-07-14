import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database/app_database.dart';
import '../local/database/database_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(appDatabaseProvider));
});

/// Registra cambios locales en sync_queue para una futura sincronización
/// con backend. Sin backend en el MVP: processPending() solo reporta
/// cuántas operaciones siguen pendientes, no las envía a ningún lado.
class SyncService {
  SyncService(this._database);

  final AppDatabase _database;

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required String payloadJson,
  }) async {
    final now = DateTime.now();

    await _database.into(_database.syncQueue).insert(
          SyncQueueCompanion.insert(
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payloadJson: payloadJson,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<int> pendingCount() async {
    final query = _database.select(_database.syncQueue)
      ..where(
        (table) =>
            table.status.equals('pending') & table.isDeleted.equals(false),
      );

    final rows = await query.get();

    return rows.length;
  }

  Future<void> processPending() async {
    // Sin backend en el MVP: las operaciones quedan en sync_queue listas
    // para procesarse cuando exista un backend real.
  }
}
