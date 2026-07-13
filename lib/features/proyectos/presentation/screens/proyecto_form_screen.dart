import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_scaffold.dart';
import '../../../clientes/application/clients_controller.dart';
import '../../../clientes/domain/entities/client.dart';
import '../../application/projects_controller.dart';
import '../../domain/entities/project.dart';

class ProyectoFormArgs {
  const ProyectoFormArgs({this.projectId, this.clientId});

  final String? projectId;
  final String? clientId;
}

class ProyectoFormScreen extends ConsumerStatefulWidget {
  const ProyectoFormScreen({super.key, this.formArgs});

  final ProyectoFormArgs? formArgs;

  @override
  ConsumerState<ProyectoFormScreen> createState() =>
      _ProyectoFormScreenState();
}

class _ProyectoFormScreenState extends ConsumerState<ProyectoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _serviceAddressController = TextEditingController();
  final _stateController = TextEditingController();
  final _municipalityController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedClientId;
  String? _selectedInstallationType;
  bool _initialized = false;
  bool _isSaving = false;

  bool get _isEditing => widget.formArgs?.projectId != null;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.formArgs?.clientId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serviceAddressController.dispose();
    _stateController.dispose();
    _municipalityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsControllerProvider);

    if (!_isEditing) {
      return AppScaffold(
        title: 'Nuevo proyecto',
        child: clientsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('Error: $error')),
          data: (clients) => _buildForm(context, clients),
        ),
      );
    }

    final projectAsync =
        ref.watch(projectByIdProvider(widget.formArgs!.projectId!));

    return AppScaffold(
      title: 'Editar proyecto',
      child: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (clients) => projectAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('Error: $error')),
          data: (project) {
            if (project == null) {
              return const Center(child: Text('Proyecto no encontrado.'));
            }

            _ensureInitialized(project);

            return _buildForm(context, clients);
          },
        ),
      ),
    );
  }

  void _ensureInitialized(Project project) {
    if (_initialized) return;
    _initialized = true;

    _nameController.text = project.name;
    _serviceAddressController.text = project.serviceAddress ?? '';
    _stateController.text = project.state ?? '';
    _municipalityController.text = project.municipality ?? '';
    _notesController.text = project.notes ?? '';
    _selectedClientId = project.clientId;
    _selectedInstallationType = project.installationType;
  }

  Widget _buildForm(BuildContext context, List<Client> clients) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedClientId,
            decoration: const InputDecoration(
              labelText: 'Cliente',
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: [
              for (final client in clients)
                DropdownMenuItem(
                  value: client.id,
                  child: Text(
                    client.fullName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedClientId = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Selecciona un cliente.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre del proyecto',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El nombre es obligatorio.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedInstallationType,
            decoration: const InputDecoration(
              labelText: 'Tipo de instalación',
              prefixIcon: Icon(Icons.solar_power_outlined),
            ),
            items: [
              for (final type in InstallationType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(InstallationType.label(type)),
                ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedInstallationType = value;
              });
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _serviceAddressController,
            decoration: const InputDecoration(
              labelText: 'Dirección del servicio',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _municipalityController,
                  decoration: const InputDecoration(labelText: 'Municipio'),
                ),
              ),
            ],
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
              label: Text(_isSaving ? 'Guardando...' : 'Guardar proyecto'),
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
      final input = SaveProjectInput(
        clientId: _selectedClientId!,
        name: _nameController.text,
        installationType: _selectedInstallationType,
        serviceAddress: _serviceAddressController.text,
        state: _stateController.text,
        municipality: _municipalityController.text,
        notes: _notesController.text,
      );

      final repository = ref.read(projectRepositoryProvider);
      String projectId;

      if (_isEditing) {
        projectId = widget.formArgs!.projectId!;
        await repository.update(projectId: projectId, input: input);
      } else {
        projectId = await repository.create(input);
      }

      ref.invalidate(projectsControllerProvider);
      ref.invalidate(projectsByClientProvider(input.clientId));
      if (_isEditing) {
        ref.invalidate(projectByIdProvider(projectId));
      }

      if (!mounted) return;

      context.pop();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el proyecto: $error')),
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
