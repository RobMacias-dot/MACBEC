import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class CatalogoInversoresScreen extends StatelessWidget {
  const CatalogoInversoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Catálogo de inversores',
      child: const EmptyState(
        title: 'Inversores',
        message: 'Aquí se administrarán inversores, datos eléctricos y precios por proveedor.',
        icon: Icons.electrical_services_outlined,
      ),
    );
  }
}
