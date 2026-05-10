import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class CotizacionScreen extends StatelessWidget {
  const CotizacionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cotización',
      child: const EmptyState(
        title: 'Cotización',
        message: 'Aquí se construirá la cotización con snapshot de precios.',
        icon: Icons.request_quote_outlined,
      ),
    );
  }
}
