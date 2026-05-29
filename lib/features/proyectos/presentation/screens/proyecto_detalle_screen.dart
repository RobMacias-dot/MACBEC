import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class ProyectoDetalleScreen extends StatelessWidget {
  const ProyectoDetalleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Detalle de proyecto',
      child: EmptyState(
        title: 'Detalle de proyecto',
        message:
            'Aquí se controlará el estatus, recibos, análisis, cotizaciones y documentos del proyecto.',
        icon: Icons.home_work_outlined,
      ),
    );
  }
}
