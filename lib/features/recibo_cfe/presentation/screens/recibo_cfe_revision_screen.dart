import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class ReciboCfeRevisionScreen extends StatelessWidget {
  const ReciboCfeRevisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Revisión CFE',
      child: const EmptyState(
        title: 'Revisión de datos detectados',
        message: 'El OCR será borrador; aquí el usuario validará o corregirá antes de guardar.',
        icon: Icons.fact_check_outlined,
      ),
    );
  }
}
