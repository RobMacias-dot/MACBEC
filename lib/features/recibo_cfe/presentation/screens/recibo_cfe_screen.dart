import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/document_preview.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../../cotizaciones/data/quotation_draft_repository.dart';
import '../../../cotizaciones/domain/entities/quotation_draft.dart';
import '../../application/ocr_service.dart';

class ReciboCfeScreen extends ConsumerStatefulWidget {
  const ReciboCfeScreen({super.key});

  @override
  ConsumerState<ReciboCfeScreen> createState() => _ReciboCfeScreenState();
}

class _ReciboCfeScreenState extends ConsumerState<ReciboCfeScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSaving = false;
  bool _isRunningOcr = false;
  String? _lastSavedFileName;
  String? _lastSavedFilePath;
  String? _lastSavedMimeType;

  @override
  Widget build(BuildContext context) {
    final activeDraftId = ref.watch(activeQuotationDraftIdProvider);

    if (activeDraftId == null) {
      return const AppScaffold(
        title: 'Recibo CFE',
        child: EmptyState(
          title: 'No hay cotización activa',
          message:
              'Primero crea o selecciona un prospecto desde la pantalla de Cotización para poder asociar su recibo CFE.',
          icon: Icons.receipt_long_outlined,
        ),
      );
    }

    return AppScaffold(
      title: 'Recibo CFE',
      child: ListView(
        children: [
          SectionCard(
            title: 'Agregar recibo CFE',
            subtitle:
                'Puedes tomar fotos del frente y reverso con la cámara, elegir una imagen desde galería o adjuntar un PDF. El archivo se guardará localmente dentro de la app.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSaving) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                ],
                _ReceiptActionButton(
                  icon: Icons.photo_camera_outlined,
                  label: 'Tomar foto (frente y reverso)',
                  description:
                      'Captura el frente y, si aplica, el reverso del recibo con la cámara.',
                  onPressed: _isSaving ? null : _captureReceiptWithCamera,
                ),
                const SizedBox(height: 12),
                _ReceiptActionButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Elegir desde galería',
                  description: 'Seleccionar una imagen ya guardada.',
                  onPressed: _isSaving ? null : _pickFromGallery,
                ),
                const SizedBox(height: 12),
                _ReceiptActionButton(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Adjuntar PDF',
                  description: 'Seleccionar archivo PDF del recibo CFE.',
                  onPressed: _isSaving ? null : _pickPdf,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Estado del recibo',
            subtitle: _lastSavedFileName == null
                ? 'Aún no has agregado un recibo.'
                : 'Recibo agregado correctamente.',
            child: _lastSavedFileName == null
                ? const Text('Selecciona una opción para continuar.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.check_circle_outline),
                        label: Text('Archivo: $_lastSavedFileName'),
                      ),
                      if (_lastSavedFilePath != null) ...[
                        const SizedBox(height: 12),
                        DocumentPreview(
                          localPath: _lastSavedFilePath!,
                          mimeType: _lastSavedMimeType,
                        ),
                      ],
                      if (_isRunningOcr) ...[
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Detectando datos del recibo...'),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureReceiptWithCamera() async {
    final activeDraftId = ref.read(activeQuotationDraftIdProvider);

    if (activeDraftId == null) {
      _showErrorMessage(
        'Primero selecciona o crea un prospecto para asociar el recibo CFE.',
      );
      return;
    }

    final frontImage = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );

    if (frontImage == null) return;

    if (!mounted) return;

    final captureBackSide = await _confirmCaptureBackSide();

    XFile? backImage;
    if (captureBackSide) {
      backImage = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final frontSaved = await _persistReceiptFile(
        sourceFile: File(frontImage.path),
        originalFileName: 'recibo_cfe_frente${p.extension(frontImage.path)}',
        draftId: activeDraftId,
        forcedMimeType: _guessMimeType(frontImage.path),
      );

      var savedFileNames = frontSaved.fileName;
      _SavedReceiptFile? backSaved;

      if (backImage != null) {
        backSaved = await _persistReceiptFile(
          sourceFile: File(backImage.path),
          originalFileName: 'recibo_cfe_reverso${p.extension(backImage.path)}',
          draftId: activeDraftId,
          forcedMimeType: _guessMimeType(backImage.path),
        );
        savedFileNames = '$savedFileNames, ${backSaved.fileName}';
      }

      await _runOcrSuggestion(
        frontSaved.localPath,
        extraImagePath: backSaved?.localPath,
      );

      await ref.read(quotationDraftRepositoryProvider).updateLastCompletedStep(
            draftId: activeDraftId,
            step: QuotationDraftStep.cfeReceipt,
          );

      ref.invalidate(quotationDraftsControllerProvider);

      if (!mounted) return;

      setState(() {
        _lastSavedFileName = savedFileNames;
        _lastSavedFilePath = frontSaved.localPath;
        _lastSavedMimeType = _guessMimeType(frontSaved.localPath);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recibo CFE guardado correctamente.'),
        ),
      );

      context.push(AppRoutes.reciboCfeRevision);
    } catch (error) {
      if (!mounted) return;
      _showErrorMessage('No se pudo guardar el recibo CFE: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _confirmCaptureBackSide() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Foto del frente capturada'),
        content: const Text(
          '¿Deseas tomar también la foto del reverso del recibo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Omitir reverso'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tomar reverso'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _pickFromGallery() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (pickedImage == null) return;

    final sourceFile = File(pickedImage.path);

    await _saveReceiptFile(
      sourceFile: sourceFile,
      originalFileName: p.basename(pickedImage.path),
      forcedMimeType: _guessMimeType(pickedImage.path),
    );
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final selectedFile = result.files.single;

    if (selectedFile.path == null) {
      _showErrorMessage('No se pudo leer la ruta del archivo seleccionado.');
      return;
    }

    final sourceFile = File(selectedFile.path!);

    await _saveReceiptFile(
      sourceFile: sourceFile,
      originalFileName: selectedFile.name,
      forcedMimeType: 'application/pdf',
      forcedSizeBytes: selectedFile.size,
    );
  }

  Future<void> _saveReceiptFile({
    required File sourceFile,
    required String originalFileName,
    String? forcedMimeType,
    int? forcedSizeBytes,
  }) async {
    final activeDraftId = ref.read(activeQuotationDraftIdProvider);

    if (activeDraftId == null) {
      _showErrorMessage(
        'Primero selecciona o crea un prospecto para asociar el recibo CFE.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final saved = await _persistReceiptFile(
        sourceFile: sourceFile,
        originalFileName: originalFileName,
        draftId: activeDraftId,
        forcedMimeType: forcedMimeType,
        forcedSizeBytes: forcedSizeBytes,
      );

      final mimeType = forcedMimeType ?? _guessMimeType(saved.fileName);

      if (mimeType != null &&
          (mimeType.startsWith('image/') || mimeType == 'application/pdf')) {
        await _runOcrSuggestion(saved.localPath);
      }

      await ref.read(quotationDraftRepositoryProvider).updateLastCompletedStep(
            draftId: activeDraftId,
            step: QuotationDraftStep.cfeReceipt,
          );

      ref.invalidate(quotationDraftsControllerProvider);

      if (!mounted) return;

      setState(() {
        _lastSavedFileName = saved.fileName;
        _lastSavedFilePath = saved.localPath;
        _lastSavedMimeType = mimeType;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recibo CFE guardado correctamente.'),
        ),
      );

      context.push(AppRoutes.reciboCfeRevision);
    } catch (error) {
      if (!mounted) return;
      _showErrorMessage('No se pudo guardar el recibo CFE: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<_SavedReceiptFile> _persistReceiptFile({
    required File sourceFile,
    required String originalFileName,
    required String draftId,
    String? forcedMimeType,
    int? forcedSizeBytes,
  }) async {
    final copiedFile = await _copyFileToPrivateStorage(
      sourceFile: sourceFile,
      originalFileName: originalFileName,
      draftId: draftId,
    );

    final fileName = p.basename(copiedFile.path);
    final sizeBytes = forcedSizeBytes ?? await copiedFile.length();
    final mimeType = forcedMimeType ?? _guessMimeType(fileName);

    await ref.read(quotationDraftRepositoryProvider).attachCfeReceiptDocument(
          AttachCfeReceiptDocumentInput(
            draftId: draftId,
            localPath: copiedFile.path,
            fileName: fileName,
            documentType: 'cfe_receipt',
            mimeType: mimeType,
            sizeBytes: sizeBytes,
          ),
        );

    return _SavedReceiptFile(localPath: copiedFile.path, fileName: fileName);
  }

  Future<void> _runOcrSuggestion(
    String imagePath, {
    String? extraImagePath,
  }) async {
    setState(() {
      _isRunningOcr = true;
    });

    try {
      final suggestion = await ref
          .read(ocrServiceProvider)
          .extractCfeReceiptSuggestion(imagePath, extraImagePath: extraImagePath);

      if (suggestion != null) {
        ref.read(cfeOcrSuggestionProvider.notifier).state = suggestion;
      }
    } catch (_) {
      // El OCR es una ayuda opcional: si falla, se sigue con captura manual.
    } finally {
      if (mounted) {
        setState(() {
          _isRunningOcr = false;
        });
      }
    }
  }

  Future<File> _copyFileToPrivateStorage({
    required File sourceFile,
    required String originalFileName,
    required String draftId,
  }) async {
    final appDirectory = await getApplicationDocumentsDirectory();

    final receiptsDirectory = Directory(
      p.join(
        appDirectory.path,
        'macbec_documents',
        'quotation_drafts',
        draftId,
        'cfe_receipts',
      ),
    );

    if (!receiptsDirectory.existsSync()) {
      await receiptsDirectory.create(recursive: true);
    }

    final extension = p.extension(originalFileName).toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeFileName = 'recibo_cfe_$timestamp$extension';

    final destinationPath = p.join(receiptsDirectory.path, safeFileName);

    return sourceFile.copy(destinationPath);
  }

  String? _guessMimeType(String fileName) {
    final extension = p.extension(fileName).toLowerCase();

    switch (extension) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.heic':
        return 'image/heic';
      case '.webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SavedReceiptFile {
  const _SavedReceiptFile({required this.localPath, required this.fileName});

  final String localPath;
  final String fileName;
}

class _ReceiptActionButton extends StatelessWidget {
  const _ReceiptActionButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(14),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
