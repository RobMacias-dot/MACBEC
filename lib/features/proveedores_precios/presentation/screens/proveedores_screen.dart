import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class ProveedoresScreen extends StatelessWidget {
  const ProveedoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Proveedores',
      child: const EmptyState(
        title: 'Proveedores y precios',
        message: 'Aquí se gestionarán proveedores y precios sugeridos/manuales.',
        icon: Icons.storefront_outlined,
      ),
    );
  }
}
