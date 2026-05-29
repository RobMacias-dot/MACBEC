import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class ProyectoFormScreen extends StatelessWidget {
  const ProyectoFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Proyecto',
      child: EmptyState(
        title: 'Formulario de proyecto',
        message:
            'Aquí se creará o editará un proyecto solar asociado a un cliente.',
        icon: Icons.add_home_work_outlined,
      ),
    );
  }
}
