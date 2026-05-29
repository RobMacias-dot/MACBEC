import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/primary_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Center(
                child: Image.asset(
                  AppAssets.macbecLogoTransparent,
                  width: 260,
                  fit: BoxFit.contain,
                  semanticLabel: AppConstants.companyName,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                AppConstants.appName,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gestión de clientes, proyectos solares, cotizaciones y expedientes.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Entrar',
                icon: Icons.arrow_forward,
                onPressed: () => context.go(AppRoutes.login),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Configurar admin inicial',
                icon: Icons.admin_panel_settings_outlined,
                onPressed: () => context.go(AppRoutes.setupAdmin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
