import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

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
  /// Páginas máximas de un PDF que se rasterizan para OCR. Los recibos CFE
  /// caben en 1-2 páginas; limitarlo evita costos de tiempo/memoria en PDFs
  /// grandes que no son recibos.
  static const _maxPdfPagesForOcr = 2;

  /// Resolución de rasterizado del PDF. Suficiente para que ML Kit lea
  /// texto pequeño sin generar imágenes desproporcionadamente grandes.
  static const _pdfRasterDpi = 200.0;

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

  /// Rasteriza las primeras páginas de un PDF a imágenes temporales y corre
  /// OCR sobre cada una, devolviendo el texto de cada página por separado
  /// (una entrada por página, en orden). Es lo que permite que los recibos
  /// CFE adjuntados como PDF (la forma más común al bajarlos del portal
  /// CFE) también generen sugerencias automáticas, igual que las fotos, y
  /// que [CfeReceiptTextParser] pueda distinguir el frente (página 1) del
  /// reverso (página 2) igual que con dos fotos.
  Future<List<String>> _extractPageTextsFromPdf(String pdfPath) async {
    final tempDir = await getTemporaryDirectory();
    final tempFiles = <File>[];

    try {
      final documentBytes = await File(pdfPath).readAsBytes();
      final pageTexts = <String>[];
      var pageIndex = 0;

      await for (final page in Printing.raster(
        documentBytes,
        pages: List.generate(_maxPdfPagesForOcr, (i) => i),
        dpi: _pdfRasterDpi,
      )) {
        final pngBytes = await page.toPng();
        final tempFile = File(
          p.join(
            tempDir.path,
            'cfe_ocr_${DateTime.now().microsecondsSinceEpoch}_$pageIndex.png',
          ),
        );
        await tempFile.writeAsBytes(pngBytes);
        tempFiles.add(tempFile);
        pageIndex++;

        final pageText = await extractTextDraft(tempFile.path);
        if (pageText != null && pageText.isNotEmpty) {
          pageTexts.add(pageText);
        }
      }

      return pageTexts;
    } catch (_) {
      return const [];
    } finally {
      for (final tempFile in tempFiles) {
        try {
          await tempFile.delete();
        } catch (_) {
          // Falla silenciosa: son archivos temporales, no afecta al usuario.
        }
      }
    }
  }

  bool _isPdf(String filePath) =>
      p.extension(filePath).toLowerCase() == '.pdf';

  /// Texto OCR de un archivo del recibo, como lista de "páginas": una sola
  /// entrada para una foto, o una entrada por página para un PDF.
  Future<List<String>> _extractPageTexts(String filePath) async {
    if (_isPdf(filePath)) return _extractPageTextsFromPdf(filePath);

    final text = await extractTextDraft(filePath);
    return text == null || text.isEmpty ? const [] : [text];
  }

  /// Corre el OCR sobre uno (o dos, frente/reverso) archivos del recibo CFE
  /// — imagen o PDF — y la pasa por [CfeReceiptTextParser]. Compartido entre
  /// la captura automática (`ReciboCfeScreen`) y el botón manual "Obtener
  /// información" de `ReciboCfeRevisionScreen`, para no duplicar la lógica
  /// de extracción.
  ///
  /// El texto de [imagePath] (y su primera página si es un PDF de varias)
  /// se trata como el frente del recibo; el resto (texto de
  /// [extraImagePath], o páginas siguientes de un PDF) se trata como
  /// reverso. Esta distinción se le pasa a [CfeReceiptTextParser] para que
  /// no confunda datos del reverso (ej. la tabla de consumo histórico, que
  /// siempre va ahí) con los del frente.
  Future<CfeReceiptOcrSuggestion?> extractCfeReceiptSuggestion(
    String imagePath, {
    String? extraImagePath,
  }) async {
    final pageTexts = <String>[...await _extractPageTexts(imagePath)];

    if (extraImagePath != null) {
      pageTexts.addAll(await _extractPageTexts(extraImagePath));
    }

    if (pageTexts.isEmpty) return null;

    final frontText = pageTexts.first;
    final backText =
        pageTexts.length > 1 ? pageTexts.sublist(1).join('\n') : null;

    final suggestion = CfeReceiptTextParser.parseFrontAndBack(
      frontText,
      backText: backText,
    );
    return suggestion.isEmpty ? null : suggestion;
  }
}
