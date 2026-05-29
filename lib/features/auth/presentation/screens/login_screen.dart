import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final success = await ref.read(authControllerProvider.notifier).signInLocal(
          email: _emailController.text,
          pin: _pinController.text,
        );

    if (!mounted) return;

    if (success) {
      context.go(AppRoutes.dashboard);
      return;
    }

    final message = ref.read(authControllerProvider).errorMessage ??
        'No se pudo iniciar sesión.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight -
                  48,
            ),
            child: IntrinsicHeight(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Image.asset(
                        AppAssets.macbecLogo,
                        width: 220,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Bienvenido a MacBec Solar',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Acceso local sin internet. Usa el correo y PIN del administrador configurado.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Ingresa el correo';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!authState.isLoading) _submit();
                      },
                      decoration: const InputDecoration(
                        labelText: 'PIN de acceso',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        final pin = value?.trim() ?? '';
                        if (pin.isEmpty) return 'Ingresa el PIN';
                        return null;
                      },
                    ),
                    const Spacer(),
                    PrimaryButton(
                      label: authState.isLoading ? 'Entrando...' : 'Entrar',
                      icon: Icons.login,
                      onPressed: authState.isLoading ? null : _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: authState.isLoading
                          ? null
                          : () => context.go(AppRoutes.setupAdmin),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Configurar admin inicial'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
