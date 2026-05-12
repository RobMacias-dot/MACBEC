import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/validators/validators.dart';
import '../../../../shared/components/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../application/quotation_draft_controller.dart';
import '../../domain/entities/quotation_draft_prospect.dart';

class CotizacionProspectoFormScreen extends ConsumerStatefulWidget {
  const CotizacionProspectoFormScreen({super.key});

  @override
  ConsumerState<CotizacionProspectoFormScreen> createState() =>
      _CotizacionProspectoFormScreenState();
}

class _CotizacionProspectoFormScreenState
    extends ConsumerState<CotizacionProspectoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final currentProspect = ref.read(quotationDraftProspectProvider);

    if (currentProspect != null) {
      _fullNameController.text = currentProspect.fullName;
      _phoneController.text = currentProspect.phone ?? '';
      _whatsappController.text = currentProspect.whatsapp ?? '';
      _emailController.text = currentProspect.email ?? '';
      _addressController.text = currentProspect.address ?? '';
      _notesController.text = currentProspect.notes ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  void _saveProspect() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final prospect = QuotationDraftProspect(
      fullName: _fullNameController.text.trim(),
      phone: _cleanNullableText(_phoneController.text),
      whatsapp: _cleanNullableText(_whatsappController.text),
      email: _cleanNullableText(_emailController.text),
      address: _cleanNullableText(_addressController.text),
      notes: _cleanNullableText(_notesController.text),
    );

    ref.read(quotationDraftProspectProvider.notifier).state = prospect;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prospecto provisional guardado.'),
      ),
    );

    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.cotizacion);
    }
  }

  String? _cleanNullableText(String value) {
    final cleanValue = value.trim();
    return cleanValue.isEmpty ? null : cleanValue;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Prospecto',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            SectionCard(
              title: 'Datos mínimos del prospecto',
              subtitle:
                  'Estos datos ayudan a identificar la cotización provisional. '
                  'El cliente formal y el expediente se crearán cuando la cotización sea aceptada.',
              child: Column(
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre o razón social',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => Validators.requiredText(
                      value,
                      field: 'Nombre o razón social',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp',
                      prefixIcon: Icon(Icons.chat_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _addressController,
                    textInputAction: TextInputAction.next,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Dirección aproximada',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Notas',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saveProspect,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar prospecto provisional'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.cotizacion);
                }
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Regresar'),
            ),
          ],
        ),
      ),
    );
  }
}
