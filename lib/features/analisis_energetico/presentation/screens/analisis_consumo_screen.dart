import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class AnalisisConsumoScreen extends StatelessWidget {
  const AnalisisConsumoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Análisis energético',
      child: const EmptyState(
        title: 'Cálculo inicial',
        message: 'Aquí se capturarán consumos bimestrales, radiación, panel y número de paneles.',
        icon: Icons.analytics_outlined,
      ),
    );
  }
}
