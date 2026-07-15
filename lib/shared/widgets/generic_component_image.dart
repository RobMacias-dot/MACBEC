import 'package:flutter/material.dart';

/// Tipo de componente técnico que puede ilustrarse con [GenericComponentImage].
enum GenericComponentType { solarPanel, inverter }

/// Ilustración genérica (no ligada a marca/modelo) de un panel solar o un
/// inversor, usada en Selección técnica y Dimensionamiento eléctrico. No
/// depende de un asset por SKU del catálogo: es la misma imagen para
/// cualquier panel o cualquier inversor (ver Fase 3.12 del plan de mejoras).
class GenericComponentImage extends StatelessWidget {
  const GenericComponentImage({
    super.key,
    required this.type,
    this.height = 120,
  });

  final GenericComponentType type;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: CustomPaint(
        size: Size.infinite,
        painter: type == GenericComponentType.solarPanel
            ? _SolarPanelPainter(colorScheme: theme.colorScheme)
            : _InverterPainter(colorScheme: theme.colorScheme),
      ),
    );
  }
}

class _SolarPanelPainter extends CustomPainter {
  _SolarPanelPainter({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final panelWidth = size.width * 0.72;
    final panelHeight = size.height * 0.82;
    final origin = Offset(
      (size.width - panelWidth) / 2,
      (size.height - panelHeight) / 2,
    );
    final panelRect = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      panelWidth,
      panelHeight,
    );

    final framePaint = Paint()..color = colorScheme.outline;
    final frameRRect = RRect.fromRectAndRadius(
      panelRect,
      const Radius.circular(6),
    );
    canvas.drawRRect(frameRRect, framePaint);

    final innerRect = panelRect.deflate(6);
    final cellPaint = Paint()..color = colorScheme.primary.withValues(alpha: 0.85);
    canvas.drawRect(innerRect, cellPaint);

    final gridPaint = Paint()
      ..color = colorScheme.surface.withValues(alpha: 0.9)
      ..strokeWidth = 2;

    const columns = 4;
    const rows = 6;

    for (var i = 1; i < columns; i++) {
      final x = innerRect.left + innerRect.width * i / columns;
      canvas.drawLine(
        Offset(x, innerRect.top),
        Offset(x, innerRect.bottom),
        gridPaint,
      );
    }

    for (var i = 1; i < rows; i++) {
      final y = innerRect.top + innerRect.height * i / rows;
      canvas.drawLine(
        Offset(innerRect.left, y),
        Offset(innerRect.right, y),
        gridPaint,
      );
    }

    final sheenPaint = Paint()
      ..color = colorScheme.onPrimary.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final sheenPath = Path()
      ..moveTo(innerRect.left, innerRect.bottom)
      ..lineTo(innerRect.left + innerRect.width * 0.35, innerRect.top)
      ..lineTo(innerRect.left + innerRect.width * 0.55, innerRect.top)
      ..lineTo(innerRect.left + innerRect.width * 0.2, innerRect.bottom)
      ..close();
    canvas.drawPath(sheenPath, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant _SolarPanelPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme;
  }
}

class _InverterPainter extends CustomPainter {
  _InverterPainter({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyWidth = size.width * 0.5;
    final bodyHeight = size.height * 0.85;
    final origin = Offset(
      (size.width - bodyWidth) / 2,
      (size.height - bodyHeight) / 2,
    );
    final bodyRect = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      bodyWidth,
      bodyHeight,
    );

    final bodyPaint = Paint()..color = colorScheme.secondaryContainer;
    final bodyRRect = RRect.fromRectAndRadius(
      bodyRect,
      const Radius.circular(10),
    );
    canvas.drawRRect(bodyRRect, bodyPaint);

    final borderPaint = Paint()
      ..color = colorScheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(bodyRRect, borderPaint);

    final displayRect = Rect.fromLTWH(
      bodyRect.left + bodyRect.width * 0.18,
      bodyRect.top + bodyRect.height * 0.12,
      bodyRect.width * 0.64,
      bodyRect.height * 0.22,
    );
    final displayPaint = Paint()..color = colorScheme.onSecondaryContainer.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(displayRect, const Radius.circular(4)),
      displayPaint,
    );

    final ledPaint = Paint()..color = colorScheme.primary;
    canvas.drawCircle(
      Offset(
        bodyRect.left + bodyRect.width * 0.5,
        bodyRect.top + bodyRect.height * 0.46,
      ),
      bodyRect.width * 0.05,
      ledPaint,
    );

    final ventPaint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.7)
      ..strokeWidth = 2;

    const ventCount = 4;
    for (var i = 0; i < ventCount; i++) {
      final y = bodyRect.top +
          bodyRect.height * 0.62 +
          (bodyRect.height * 0.28) * i / (ventCount - 1);
      canvas.drawLine(
        Offset(bodyRect.left + bodyRect.width * 0.18, y),
        Offset(bodyRect.right - bodyRect.width * 0.18, y),
        ventPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InverterPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme;
  }
}
