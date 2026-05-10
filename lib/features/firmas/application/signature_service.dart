class SignatureService {
  Future<void> saveSignatureImage({
    required List<int> pngBytes,
    required String contractId,
  }) async {
    // Fase posterior: guardar imagen en almacenamiento privado y metadatos en SQLite.
  }
}
