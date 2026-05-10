import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class ExpedienteScreen extends StatelessWidget {
  const ExpedienteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Expediente',
      child: const EmptyState(
        title: 'Expediente del proyecto',
        message: 'Aquí se mostrarán documentos, fotos, PDFs, contratos y comprobantes.',
        icon: Icons.folder_outlined,
      ),
    );
  }
}
