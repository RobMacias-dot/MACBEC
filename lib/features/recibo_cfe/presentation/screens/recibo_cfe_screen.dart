import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class ReciboCfeScreen extends StatelessWidget {
  const ReciboCfeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Recibo CFE',
      child: const EmptyState(
        title: 'Captura de recibo CFE',
        message: 'Aquí se cargará foto/PDF y captura manual del recibo.',
        icon: Icons.receipt_long_outlined,
      ),
    );
  }
}
