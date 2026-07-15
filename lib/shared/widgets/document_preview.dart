import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Vista previa inline de un documento adjunto: imagen o PDF.
class DocumentPreview extends StatelessWidget {
  const DocumentPreview({
    super.key,
    required this.localPath,
    this.mimeType,
    this.height = 220,
  });

  final String localPath;
  final String? mimeType;
  final double height;

  bool get _isPdf =>
      mimeType == 'application/pdf' ||
      localPath.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(localPath);

    if (!file.existsSync()) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('El archivo ya no está disponible.'),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: _isPdf
            ? PdfPreview(
                build: (format) => file.readAsBytes(),
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                allowPrinting: false,
                allowSharing: false,
                useActions: false,
                scrollViewDecoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
              )
            : Image.file(
                file,
                fit: BoxFit.contain,
                width: double.infinity,
              ),
      ),
    );
  }
}
