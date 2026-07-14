import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/files/file_storage_service.dart';

final signatureServiceProvider = Provider<SignatureService>(
  (ref) => SignatureService(ref.watch(fileStorageServiceProvider)),
);

/// Guarda la imagen de una firma capturada en pantalla dentro del
/// almacenamiento privado del borrador. El registro en SQLite (Documents +
/// Contracts) lo hace ContractRepository.attachSignature.
class SignatureService {
  SignatureService(this._fileStorageService);

  final FileStorageService _fileStorageService;

  Future<String> saveSignatureImage({
    required Uint8List pngBytes,
    required String quotationDraftId,
    required String signerLabel,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'firma_${signerLabel}_$timestamp.png';

    final file = await _fileStorageService.saveBytes(
      bytes: pngBytes,
      fileName: fileName,
      subfolder: 'quotation_drafts/$quotationDraftId/firmas',
    );

    return file.path;
  }
}
