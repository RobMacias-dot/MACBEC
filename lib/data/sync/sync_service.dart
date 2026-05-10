class SyncService {
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required String payloadJson,
  }) async {
    // Fase 0: contrato del servicio.
    // Fase futura: insertar en sync_queue y procesar cuando exista backend.
  }

  Future<void> processPending() async {
    // Sin backend en MVP inicial.
  }
}
