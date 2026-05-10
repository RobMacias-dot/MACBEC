import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class ClienteDetalleScreen extends StatelessWidget {
  const ClienteDetalleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detalle de cliente',
      child: const EmptyState(
        title: 'Detalle de cliente',
        message: 'Aquí se verá el cliente, sus proyectos, datos fiscales y expediente.',
        icon: Icons.person_outline,
      ),
    );
  }
}
