import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Logo animado de MacBec para splash, pantalla inicial o presentación de marca.
///
/// Usa el logo transparente como capa final y una animación vectorial encima para:
/// - girar las dos medias lunas,
/// - mostrar el sol,
/// - hacer crecer el círculo negro del eclipse,
/// - terminar dejando el logo original alineado.
class MacBecAnimatedLogo extends StatefulWidget {
  const MacBecAnimatedLogo({
    super.key,
    this.logoAsset = 'assets/images/logo/macbec_logo_transparente_limpio.png',
    this.width = 340,
    this.duration = const Duration(milliseconds: 2800),
    this.onFinished,
    this.repeat = false,
    this.playOnStart = true,
  });

  /// Ruta del PNG transparente declarado en pubspec.yaml.
  final String logoAsset;

  /// Ancho visual del logo dentro de la pantalla.
  final double width;

  /// Duración total de la animación.
  final Duration duration;

  /// Acción opcional al terminar, por ejemplo navegar al Home.
  final VoidCallback? onFinished;

  /// Útil para hacer pruebas visuales sin reiniciar la app.
  final bool repeat;

  /// Permite controlar si la animación inicia automáticamente.
  final bool playOnStart;

  @override
  State<MacBecAnimatedLogo> createState() => _MacBecAnimatedLogoState();
}

class _MacBecAnimatedLogoState extends State<MacBecAnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    if (widget.playOnStart) {
      if (widget.repeat) {
        _controller.repeat();
      } else {
        _controller.forward().whenComplete(() {
          if (mounted) widget.onFinished?.call();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant MacBecAnimatedLogo oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.width * 0.4713;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;
            final logoOpacity = _curve(progress, 0.30, 0.72, Curves.easeOut);
            final logoScale = _lerp(
              0.965,
              1.0,
              _curve(progress, 0.34, 0.92, Curves.easeOutBack),
            );
            final overlayOpacity = 1.0 -
                _curve(
                  progress,
                  0.78,
                  1.0,
                  Curves.easeOut,
                );

            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: logoScale,
                  child: Opacity(
                    opacity: logoOpacity,
                    child: Image.asset(
                      widget.logoAsset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                Opacity(
                  opacity: overlayOpacity,
                  child: CustomPaint(
                    painter: _MacBecIntroPainter(progress: progress),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MacBecIntroPainter extends CustomPainter {
  const _MacBecIntroPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSunAndEclipse(canvas, size);
    _drawBottomSwoosh(canvas, size);
    _drawTopSwoosh(canvas, size);
  }

  void _drawTopSwoosh(Canvas canvas, Size size) {
    final t = _curve(progress, 0.05, 0.62, Curves.easeOutCubic);
    final settle = _curve(progress, 0.58, 0.82, Curves.easeOutBack);
    final center = Offset(size.width * 0.755, size.height * 0.245);
    final startOffset = Offset(size.width * 0.38, -size.height * 0.45);
    final currentCenter = center + startOffset * (1.0 - t);
    final angle = (1.0 - t) * math.pi * 2.0;
    final scale = _lerp(0.46, 1.0, t);

    final path = Path()
      ..moveTo(size.width * 0.535, size.height * 0.235)
      ..cubicTo(
        size.width * 0.640,
        size.height * 0.020,
        size.width * 0.850,
        size.height * 0.005,
        size.width * 0.955,
        size.height * 0.115,
      )
      ..cubicTo(
        size.width * 1.020,
        size.height * 0.185,
        size.width * 0.980,
        size.height * 0.335,
        size.width * 0.895,
        size.height * 0.425,
      )
      ..cubicTo(
        size.width * 0.875,
        size.height * 0.270,
        size.width * 0.700,
        size.height * 0.145,
        size.width * 0.535,
        size.height * 0.235,
      )
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF005A9C).withValues(alpha: t),
          const Color(0xFF0D8FD0).withValues(alpha: t),
          const Color(0xFF24C8B7).withValues(alpha: t),
        ],
      ).createShader(path.getBounds())
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(currentCenter.dx, currentCenter.dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(path, paint);

    if (settle > 0) {
      final highlightPaint = Paint()
        ..color = const Color(0xFFE8F4FA).withValues(alpha: 0.72 * settle * t)
        ..strokeWidth = size.width * 0.010
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final highlight = Path()
        ..moveTo(size.width * 0.555, size.height * 0.215)
        ..cubicTo(
          size.width * 0.695,
          size.height * 0.070,
          size.width * 0.855,
          size.height * 0.075,
          size.width * 0.925,
          size.height * 0.260,
        );
      canvas.drawPath(highlight, highlightPaint);
    }

    canvas.restore();
  }

  void _drawBottomSwoosh(Canvas canvas, Size size) {
    final t = _curve(progress, 0.08, 0.66, Curves.easeOutCubic);
    final settle = _curve(progress, 0.60, 0.84, Curves.easeOutBack);
    final center = Offset(size.width * 0.245, size.height * 0.705);
    final startOffset = Offset(-size.width * 0.42, size.height * 0.36);
    final currentCenter = center + startOffset * (1.0 - t);
    final angle = -(1.0 - t) * math.pi * 2.0;
    final scale = _lerp(0.46, 1.0, t);

    final path = Path()
      ..moveTo(size.width * 0.035, size.height * 0.660)
      ..cubicTo(
        size.width * 0.115,
        size.height * 0.505,
        size.width * 0.335,
        size.height * 0.495,
        size.width * 0.475,
        size.height * 0.640,
      )
      ..cubicTo(
        size.width * 0.350,
        size.height * 0.900,
        size.width * 0.085,
        size.height * 0.890,
        size.width * 0.025,
        size.height * 0.705,
      )
      ..cubicTo(
        size.width * 0.010,
        size.height * 0.675,
        size.width * 0.020,
        size.height * 0.665,
        size.width * 0.035,
        size.height * 0.660,
      )
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF23C7B9).withValues(alpha: t),
          const Color(0xFF119ED9).withValues(alpha: t),
          const Color(0xFF005A9C).withValues(alpha: t),
        ],
      ).createShader(path.getBounds())
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(currentCenter.dx, currentCenter.dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(path, paint);

    if (settle > 0) {
      final highlightPaint = Paint()
        ..color = const Color(0xFFE8F4FA).withValues(alpha: 0.62 * settle * t)
        ..strokeWidth = size.width * 0.010
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final highlight = Path()
        ..moveTo(size.width * 0.080, size.height * 0.660)
        ..cubicTo(
          size.width * 0.175,
          size.height * 0.785,
          size.width * 0.350,
          size.height * 0.795,
          size.width * 0.455,
          size.height * 0.670,
        );
      canvas.drawPath(highlight, highlightPaint);
    }

    canvas.restore();
  }

  void _drawSunAndEclipse(Canvas canvas, Size size) {
    final sunT = _curve(progress, 0.00, 0.25, Curves.easeOutBack);
    final eclipseT = _curve(progress, 0.43, 0.78, Curves.easeOutCubic);
    final center = Offset(size.width * 0.188, size.height * 0.305);
    final radius = size.width * 0.033 * sunT;

    if (sunT <= 0) return;

    final rayPaint = Paint()
      ..color = const Color(0xFFEFA51A).withValues(alpha: sunT)
      ..strokeWidth = size.width * 0.0038
      ..strokeCap = StrokeCap.round;

    final rayRotation = progress * math.pi * 0.80;
    for (int i = 0; i < 26; i++) {
      final angle = (i * math.pi * 2 / 26) + rayRotation;
      final p1 =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 1.08;
      final p2 =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 1.58;
      canvas.drawLine(p1, p2, rayPaint);
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFFFFC247).withValues(alpha: sunT),
    );

    final eclipseCenter =
        center + Offset(size.width * 0.020, size.height * 0.005);
    final eclipseRadius = size.width * 0.004 + (size.width * 0.036 * eclipseT);

    canvas.drawCircle(
      eclipseCenter,
      eclipseRadius,
      Paint()..color = Colors.black.withValues(alpha: sunT),
    );
  }

  @override
  bool shouldRepaint(covariant _MacBecIntroPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

double _curve(double value, double start, double end, Curve curve) {
  if (value <= start) return 0;
  if (value >= end) return 1;
  final normalized = (value - start) / (end - start);
  return curve.transform(normalized.clamp(0.0, 1.0));
}

double _lerp(double start, double end, double t) {
  return start + (end - start) * t.clamp(0.0, 1.0);
}
