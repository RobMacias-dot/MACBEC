import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class ClienteFormScreen extends StatelessWidget {
  const ClienteFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Cliente',
      child: EmptyState(
        title: 'Formulario de cliente',
        message: 'Aquí se registrará o editará la información del cliente.',
        icon: Icons.person_add_alt_1_outlined,
      ),
    );
  }
}
