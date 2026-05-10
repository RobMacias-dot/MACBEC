import 'package:flutter/material.dart';

import '../widgets/macbec_animated_logo.dart';

/// Pantalla splash opcional para mostrar la animación del logo MacBec.
///
/// Uso rápido:
///   const SplashMacBecScreen(nextRoute: '/home')
///
/// Si todavía no tienes rutas configuradas, puedes dejar nextRoute en null
/// y la animación se reproducirá sin navegar automáticamente.
class SplashMacBecScreen extends StatelessWidget {
  const SplashMacBecScreen({
    super.key,
    this.nextRoute,
    this.backgroundColor = const Color(0xFFF5FAFC),
  });

  final String? nextRoute;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final logoWidth = screenWidth < 480 ? screenWidth * 0.82 : 420.0;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: MacBecAnimatedLogo(
            width: logoWidth,
            onFinished: nextRoute == null
                ? null
                : () {
                    Future.delayed(const Duration(milliseconds: 350), () {
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, nextRoute!);
                    });
                  },
          ),
        ),
      ),
    );
  }
}
