import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class CatalogoPanelesScreen extends StatelessWidget {
  const CatalogoPanelesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Catálogo de paneles',
      child: const EmptyState(
        title: 'Paneles solares',
        message: 'Aquí se administrarán paneles con precio manual, proveedor y bloqueo de precio.',
        icon: Icons.solar_power_outlined,
      ),
    );
  }
}
