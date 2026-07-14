import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_scaffold.dart';
import '../../../firmas/application/signature_service.dart';
import '../../data/contract_repository.dart';

class FirmaCapturaArgs {
  const FirmaCapturaArgs({
    required this.quotationDraftId,
    required this.role,
  });

  final String quotationDraftId;
  final SignatureRole role;
}

class FirmaCapturaScreen extends ConsumerStatefulWidget {
  const FirmaCapturaScreen({super.key, required this.args});

  final FirmaCapturaArgs args;

  @override
  ConsumerState<FirmaCapturaScreen> createState() =>
      _FirmaCapturaScreenState();
}

class _FirmaCapturaScreenState extends ConsumerState<FirmaCapturaScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  bool _isSaving = false;

  bool get _isClient => widget.args.role == SignatureRole.client;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isClient ? 'Firma del cliente' : 'Firma del proveedor',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dibuja la firma con el dedo o el mouse dentro del recuadro.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RepaintBoundary(
              key: _repaintKey,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _strokes.add([details.localPosition]);
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _strokes.last.add(details.localPosition);
                    });
                  },
                  child: CustomPaint(
                    painter: _SignaturePainter(strokes: _strokes),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _strokes.isEmpty
                      ? null
                      : () => setState(() => _strokes.clear()),
                  icon: const Icon(Icons.clear_outlined),
                  label: const Text('Limpiar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_strokes.isEmpty || _isSaving)
                      ? null
                      : _saveSignature,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_outlined),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar firma'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveSignature() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        throw StateError('No se pudo capturar la firma.');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw StateError('No se pudo generar la imagen de la firma.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final signerLabel = _isClient ? 'cliente' : 'proveedor';

      final localPath = await ref.read(signatureServiceProvider).saveSignatureImage(
            pngBytes: pngBytes,
            quotationDraftId: widget.args.quotationDraftId,
            signerLabel: signerLabel,
          );

      await ref.read(contractRepositoryProvider).attachSignature(
            AttachSignatureInput(
              quotationDraftId: widget.args.quotationDraftId,
              role: widget.args.role,
              localPath: localPath,
              fileName: localPath.split(RegExp(r'[\\/]')).last,
              sizeBytes: pngBytes.length,
            ),
          );

      ref.invalidate(contractByDraftProvider(widget.args.quotationDraftId));

      if (!mounted) return;

      context.pop();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la firma: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
