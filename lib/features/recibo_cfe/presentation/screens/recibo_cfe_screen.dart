import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';
import '../../../cotizaciones/data/quotation_draft_repository.dart';

class ReciboCfeScreen extends ConsumerStatefulWidget {
  const ReciboCfeScreen({super.key});

  @override
  ConsumerState<ReciboCfeScreen> createState() => _ReciboCfeScreenState();
}

class _ReciboCfeScreenState extends ConsumerState<ReciboCfeScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSaving = false;
  String? _lastSavedFileName;

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
                'Puedes tomar una foto, elegir una imagen desde galería o adjuntar un PDF. El archivo se guardará localmente dentro de la app.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSaving) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                ],
                _ReceiptActionButton(
                  icon: Icons.photo_camera_outlined,
                  label: 'Tomar foto',
                  description: 'Usar la cámara del dispositivo.',
                  onPressed: _isSaving ? null : _pickFromCamera,
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
                : Chip(
                    avatar: const Icon(Icons.check_circle_outline),
                    label: Text('Archivo: $_lastSavedFileName'),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (pickedImage == null) return;

    final sourceFile = File(pickedImage.path);

    await _saveReceiptFile(
      sourceFile: sourceFile,
      originalFileName: p.basename(pickedImage.path),
      forcedMimeType: _guessMimeType(pickedImage.path),
    );
  }

  Future<void> _pickFromGallery() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
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
      final copiedFile = await _copyFileToPrivateStorage(
        sourceFile: sourceFile,
        originalFileName: originalFileName,
        draftId: activeDraftId,
      );

      final fileName = p.basename(copiedFile.path);
      final sizeBytes = forcedSizeBytes ?? await copiedFile.length();

      await ref.read(quotationDraftRepositoryProvider).attachCfeReceiptDocument(
            AttachCfeReceiptDocumentInput(
              draftId: activeDraftId,
              localPath: copiedFile.path,
              fileName: fileName,
              documentType: 'cfe_receipt',
              mimeType: forcedMimeType ?? _guessMimeType(fileName),
              sizeBytes: sizeBytes,
            ),
          );

      ref.invalidate(quotationDraftsControllerProvider);

      if (!mounted) return;

      setState(() {
        _lastSavedFileName = fileName;
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
