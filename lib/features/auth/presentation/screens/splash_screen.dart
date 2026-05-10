import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../application/auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _blurAnimation = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        await Future<void>.delayed(const Duration(milliseconds: 550));
        await _redirectAfterSplash();
      }
    });

    _controller.forward();
  }

  Future<void> _redirectAfterSplash() async {
    final destination = await ref
        .read(authControllerProvider.notifier)
        .resolveStartupDestination();

    if (!mounted) return;

    switch (destination) {
      case AuthStartupDestination.dashboard:
        context.go(AppRoutes.dashboard);
        break;
      case AuthStartupDestination.login:
        context.go(AppRoutes.login);
        break;
      case AuthStartupDestination.welcome:
        context.go(AppRoutes.welcome);
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final blur = _blurAnimation.value;

              return Opacity(
                opacity: _opacityAnimation.value,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: blur,
                    sigmaY: blur,
                  ),
                  child: child,
                ),
              );
            },
            child: Image.asset(
              AppAssets.macbecLogoTransparent,
              width: 280,
              fit: BoxFit.contain,
              semanticLabel: AppConstants.companyName,
            ),
          ),
        ),
      ),
    );
  }
}
