import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_scaffold.dart';
import '../../application/clients_controller.dart';
import '../../domain/entities/client.dart';

class ClienteFormScreen extends ConsumerStatefulWidget {
  const ClienteFormScreen({super.key, this.clientId});

  final String? clientId;

  @override
  ConsumerState<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends ConsumerState<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;

  bool get _isEditing => widget.clientId != null;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditing) {
      return AppScaffold(
        title: 'Nuevo cliente',
        child: _buildForm(context),
      );
    }

    final clientAsync = ref.watch(clientByIdProvider(widget.clientId!));

    return AppScaffold(
      title: 'Editar cliente',
      child: clientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('No se pudo cargar el cliente: $error'),
        ),
        data: (client) {
          if (client == null) {
            return const Center(child: Text('Cliente no encontrado.'));
          }

          _ensureInitialized(client);

          return _buildForm(context);
        },
      ),
    );
  }

  void _ensureInitialized(Client client) {
    if (_initialized) return;
    _initialized = true;

    _fullNameController.text = client.fullName;
    _phoneController.text = client.phone ?? '';
    _emailController.text = client.email ?? '';
    _addressController.text = client.address ?? '';
    _notesController.text = client.notes ?? '';
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El nombre es obligatorio.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Dirección',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notas',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Guardando...' : 'Guardar cliente'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final input = SaveClientInput(
        fullName: _fullNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        address: _addressController.text,
        notes: _notesController.text,
      );

      final repository = ref.read(clientRepositoryProvider);

      if (_isEditing) {
        await repository.update(clientId: widget.clientId!, input: input);
      } else {
        await repository.create(input);
      }

      ref.invalidate(clientsControllerProvider);
      if (_isEditing) {
        ref.invalidate(clientByIdProvider(widget.clientId!));
      }

      if (!mounted) return;

      context.pop();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el cliente: $error')),
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
