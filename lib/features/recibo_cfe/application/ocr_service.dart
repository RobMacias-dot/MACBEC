import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/cfe_receipt_text_parser.dart';

final ocrServiceProvider = Provider<OcrService>((ref) => OcrService());

/// Última sugerencia de OCR pendiente de revisión manual. Es estado
/// efímero (no se persiste): una vez que el usuario guarda la revisión con
/// datos ya validados, deja de usarse.
final cfeOcrSuggestionProvider = StateProvider<CfeReceiptOcrSuggestion?>(
  (ref) => null,
);

/// OCR local (ML Kit, en el dispositivo, sin llamadas a la nube).
///
/// Regla permanente: lo detectado por OCR nunca alimenta cálculos ni se
/// guarda directamente; solo se usa como sugerencia editable en la pantalla
/// de revisión del recibo CFE, donde el usuario valida o corrige cada dato.
class OcrService {
  Future<String?> extractTextDraft(String localFilePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFilePath(localFilePath);
      final result = await recognizer.processImage(inputImage);
      final text = result.text.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    } finally {
      await recognizer.close();
    }
  }
}
