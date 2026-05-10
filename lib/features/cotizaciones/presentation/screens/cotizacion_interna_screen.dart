import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class CotizacionInternaScreen extends StatelessWidget {
  const CotizacionInternaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cotización interna',
      child: const EmptyState(
        title: 'Vista interna',
        message: 'Esta vista sí mostrará costos, utilidad, margen y datos internos.',
        icon: Icons.visibility_outlined,
      ),
    );
  }
}
