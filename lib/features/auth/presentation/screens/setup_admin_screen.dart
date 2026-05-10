import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/auth_controller.dart';

class SetupAdminScreen extends ConsumerStatefulWidget {
  const SetupAdminScreen({super.key});

  @override
  ConsumerState<SetupAdminScreen> createState() => _SetupAdminScreenState();
}

class _SetupAdminScreenState extends ConsumerState<SetupAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final success = await ref.read(authControllerProvider.notifier).createInitialAdmin(
          fullName: _fullNameController.text,
          email: _emailController.text,
          pin: _pinController.text,
        );

    if (!mounted) return;

    if (success) {
      context.go(AppRoutes.dashboard);
      return;
    }

    final message = ref.read(authControllerProvider).errorMessage ??
        'No se pudo guardar el administrador inicial.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar admin')),
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
                    Text(
                      'Administrador inicial',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este usuario será el primer acceso local de MacBec Solar. La app seguirá funcionando sin internet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _fullNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre completo es obligatorio';
                        }
                        if (value.trim().length < 3) {
                          return 'Ingresa un nombre válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
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
                        if (email.isEmpty) return 'El correo es obligatorio';
                        final isValidEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email);
                        if (!isValidEmail) return 'Ingresa un correo válido';
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
                        if (pin.isEmpty) return 'El PIN es obligatorio';
                        if (pin.length < 4) {
                          return 'El PIN debe tener al menos 4 caracteres';
                        }
                        return null;
                      },
                    ),
                    const Spacer(),
                    PrimaryButton(
                      label: authState.isLoading
                          ? 'Guardando...'
                          : 'Guardar admin inicial',
                      icon: Icons.save_outlined,
                      onPressed: authState.isLoading ? null : _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: authState.isLoading
                          ? null
                          : () => context.go(AppRoutes.login),
                      icon: const Icon(Icons.login),
                      label: const Text('Ya tengo admin, iniciar sesión'),
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
