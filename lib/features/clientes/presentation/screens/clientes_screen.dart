import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class ClientesScreen extends StatelessWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Clientes',
      child: const EmptyState(
        title: 'Clientes',
        message: 'Aquí vivirá el listado y búsqueda de clientes.',
        icon: Icons.people_outline,
      ),
    );
  }
}
