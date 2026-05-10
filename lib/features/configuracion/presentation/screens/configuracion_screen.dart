import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/commercial_settings_controller.dart';
import '../../application/company_settings_controller.dart';
import '../../domain/entities/commercial_settings.dart';
import '../../domain/entities/company_profile.dart';

class ConfiguracionScreen extends ConsumerStatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  ConsumerState<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends ConsumerState<ConfiguracionScreen> {
  final _companyFormKey = GlobalKey<FormState>();
  final _commercialFormKey = GlobalKey<FormState>();

  final _companyNameController = TextEditingController();
  final _rfcController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  final _ivaRateController = TextEditingController();
  final _utilityRateController = TextEditingController();
  final _currencyController = TextEditingController();
  final _validityDaysController = TextEditingController();
  final _quotationLegalNoteController = TextEditingController();
  final _warrantyNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();

    Future.microtask(_loadInitialSettings);
  }

  Future<void> _loadInitialSettings() async {
    await Future.wait([
      ref.read(companySettingsControllerProvider.notifier).load(),
      ref.read(commercialSettingsControllerProvider.notifier).load(),
    ]);

    if (!mounted) return;

    final companyProfile = ref.read(companySettingsControllerProvider).profile;
    final commercialSettings =
        ref.read(commercialSettingsControllerProvider).settings;

    _syncCompanyProfile(companyProfile);
    _syncCommercialSettings(commercialSettings);
  }

  void _syncCompanyProfile(CompanyProfile profile) {
    _companyNameController.text = profile.companyName;
    _rfcController.text = profile.rfc;
    _phoneController.text = profile.phone;
    _emailController.text = profile.email;
    _addressController.text = profile.address;
  }

  void _syncCommercialSettings(CommercialSettings settings) {
    _ivaRateController.text = _formatNumber(settings.ivaRatePercent);
    _utilityRateController.text = _formatNumber(
      settings.generalUtilityRatePercent,
    );
    _currencyController.text = settings.currency;
    _validityDaysController.text =
        settings.defaultQuotationValidityDays.toString();
    _quotationLegalNoteController.text = settings.quotationLegalNote;
    _warrantyNoteController.text = settings.warrantyNote;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  Future<void> _saveCompanyProfile() async {
    final isValid = _companyFormKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final success =
        await ref.read(companySettingsControllerProvider.notifier).save(
              companyName: _companyNameController.text,
              rfc: _rfcController.text,
              phone: _phoneController.text,
              email: _emailController.text,
              address: _addressController.text,
            );

    if (!mounted) return;

    final state = ref.read(companySettingsControllerProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Datos de empresa guardados correctamente.'
              : state.errorMessage ?? 'No se pudo guardar la empresa.',
        ),
      ),
    );
  }

  Future<void> _saveCommercialSettings() async {
    final isValid = _commercialFormKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final success =
        await ref.read(commercialSettingsControllerProvider.notifier).save(
              ivaRatePercent: _ivaRateController.text,
              generalUtilityRatePercent: _utilityRateController.text,
              currency: _currencyController.text,
              defaultQuotationValidityDays: _validityDaysController.text,
              quotationLegalNote: _quotationLegalNoteController.text,
              warrantyNote: _warrantyNoteController.text,
            );

    if (!mounted) return;

    final state = ref.read(commercialSettingsControllerProvider);

    if (success) {
      _syncCommercialSettings(state.settings);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Parámetros comerciales guardados correctamente.'
              : state.errorMessage ??
                  'No se pudieron guardar los parámetros comerciales.',
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text(
            '¿Deseas cerrar la sesión local actual? Podrás volver a entrar con tu correo y PIN.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) return;

    await ref.read(authControllerProvider.notifier).signOut();

    if (!context.mounted) return;

    context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _rfcController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();

    _ivaRateController.dispose();
    _utilityRateController.dispose();
    _currencyController.dispose();
    _validityDaysController.dispose();
    _quotationLegalNoteController.dispose();
    _warrantyNoteController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final companyState = ref.watch(companySettingsControllerProvider);
    final commercialState = ref.watch(commercialSettingsControllerProvider);
    final user = authState.user;

    return AppScaffold(
      title: 'Configuración',
      actions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: () => _confirmSignOut(context, ref),
          icon: const Icon(Icons.logout),
        ),
      ],
      child: ListView(
        children: [
          Text(
            'Configuración',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajustes locales de seguridad, empresa, respaldos y preferencias de MacBec Solar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          _SessionCard(
            fullName: user?.fullName ?? 'Sin usuario cargado',
            email: user?.email ?? 'Sin correo',
            role: user?.isAdmin == true ? 'Administrador' : 'Usuario',
            status: authState.isAuthenticated
                ? 'Sesión activa'
                : 'Sin sesión activa',
          ),
          const SizedBox(height: 16),
          _CompanySettingsCard(
            formKey: _companyFormKey,
            companyNameController: _companyNameController,
            rfcController: _rfcController,
            phoneController: _phoneController,
            emailController: _emailController,
            addressController: _addressController,
            isLoading: companyState.isLoading,
            isSaving: companyState.isSaving,
            onSave: _saveCompanyProfile,
          ),
          const SizedBox(height: 16),
          _CommercialSettingsCard(
            formKey: _commercialFormKey,
            ivaRateController: _ivaRateController,
            utilityRateController: _utilityRateController,
            currencyController: _currencyController,
            validityDaysController: _validityDaysController,
            quotationLegalNoteController: _quotationLegalNoteController,
            warrantyNoteController: _warrantyNoteController,
            isLoading: commercialState.isLoading,
            isSaving: commercialState.isSaving,
            onSave: _saveCommercialSettings,
          ),
          const SizedBox(height: 16),
          _SecurityCard(
            onSignOut: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: 16),
          const _PendingSettingsCard(),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
  });

  final String fullName;
  final String email;
  final String role;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Sesión local',
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Usuario', value: fullName),
            const SizedBox(height: 8),
            _InfoRow(label: 'Correo', value: email),
            const SizedBox(height: 8),
            _InfoRow(label: 'Rol', value: role),
            const SizedBox(height: 8),
            _InfoRow(label: 'Estado', value: status),
          ],
        ),
      ),
    );
  }
}

class _CompanySettingsCard extends StatelessWidget {
  const _CompanySettingsCard({
    required this.formKey,
    required this.companyNameController,
    required this.rfcController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
    required this.isLoading,
    required this.isSaving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController companyNameController;
  final TextEditingController rfcController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final bool isLoading;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle(
                icon: Icons.business_outlined,
                title: 'Datos de empresa MacBec',
              ),
              const SizedBox(height: 8),
              Text(
                'Estos datos se usarán más adelante para cotizaciones, contratos, documentos PDF y pre-factura offline.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: companyNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre comercial',
                  hintText: 'MacBec Solar',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre comercial es obligatorio';
                  }

                  if (value.trim().length < 3) {
                    return 'Ingresa un nombre comercial válido';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: rfcController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'RFC',
                  hintText: 'Opcional',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  hintText: 'Opcional',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Correo de empresa',
                  hintText: 'Opcional',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';

                  if (email.isEmpty) return null;

                  final isValidEmail =
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

                  if (!isValidEmail) {
                    return 'Ingresa un correo válido';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  hintText: 'Opcional',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isSaving ? null : onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    isSaving ? 'Guardando...' : 'Guardar datos de empresa',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommercialSettingsCard extends StatelessWidget {
  const _CommercialSettingsCard({
    required this.formKey,
    required this.ivaRateController,
    required this.utilityRateController,
    required this.currencyController,
    required this.validityDaysController,
    required this.quotationLegalNoteController,
    required this.warrantyNoteController,
    required this.isLoading,
    required this.isSaving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController ivaRateController;
  final TextEditingController utilityRateController;
  final TextEditingController currencyController;
  final TextEditingController validityDaysController;
  final TextEditingController quotationLegalNoteController;
  final TextEditingController warrantyNoteController;
  final bool isLoading;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle(
                icon: Icons.request_quote_outlined,
                title: 'Parámetros comerciales',
              ),
              const SizedBox(height: 8),
              Text(
                'Estos valores servirán como base para cotizaciones, contratos y documentos comerciales. Podrán ajustarse por cotización cuando sea necesario.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: ivaRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'IVA %',
                        hintText: '16',
                        prefixIcon: Icon(Icons.percent_outlined),
                      ),
                      validator: (value) {
                        final number = _parseDouble(value);

                        if (number == null) {
                          return 'IVA inválido';
                        }

                        if (number < 0 || number > 100) {
                          return 'Debe ser 0 a 100';
                        }

                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: utilityRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Utilidad %',
                        hintText: '30',
                        prefixIcon: Icon(Icons.trending_up_outlined),
                      ),
                      validator: (value) {
                        final number = _parseDouble(value);

                        if (number == null) {
                          return 'Utilidad inválida';
                        }

                        if (number < 0 || number > 300) {
                          return 'Debe ser 0 a 300';
                        }

                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: currencyController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Moneda',
                        hintText: 'MXN',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (value) {
                        final currency = value?.trim().toUpperCase() ?? '';

                        if (currency.isEmpty) {
                          return 'Obligatoria';
                        }

                        if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
                          return 'Ej. MXN';
                        }

                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: validityDaysController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Vigencia días',
                        hintText: '15',
                        prefixIcon: Icon(Icons.event_available_outlined),
                      ),
                      validator: (value) {
                        final days = int.tryParse(value?.trim() ?? '');

                        if (days == null) {
                          return 'Días inválidos';
                        }

                        if (days < 1 || days > 365) {
                          return '1 a 365';
                        }

                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: quotationLegalNoteController,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Texto legal para cotizaciones',
                  hintText: 'Condiciones generales de la cotización',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El texto legal es obligatorio';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: warrantyNoteController,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Texto de garantía / observaciones',
                  hintText: 'Condiciones de garantía del sistema',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El texto de garantía es obligatorio';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isSaving ? null : onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    isSaving
                        ? 'Guardando...'
                        : 'Guardar parámetros comerciales',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double? _parseDouble(String? value) {
    final normalizedValue = value?.trim().replaceAll(',', '.') ?? '';

    if (normalizedValue.isEmpty) {
      return null;
    }

    return double.tryParse(normalizedValue);
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({
    required this.onSignOut,
  });

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seguridad',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'El cierre de sesión elimina únicamente la sesión local guardada. No borra usuarios, clientes, proyectos ni información de la base SQLite.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingSettingsCard extends StatelessWidget {
  const _PendingSettingsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Próximas configuraciones',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            const _PendingItem(
              icon: Icons.backup_outlined,
              text: 'Respaldos locales y exportación',
            ),
            const _PendingItem(
              icon: Icons.lock_outline,
              text: 'Cambio de PIN y seguridad local',
            ),
            const _PendingItem(
              icon: Icons.picture_as_pdf_outlined,
              text: 'Plantillas para cotizaciones, contratos y documentos PDF',
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _PendingItem extends StatelessWidget {
  const _PendingItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
