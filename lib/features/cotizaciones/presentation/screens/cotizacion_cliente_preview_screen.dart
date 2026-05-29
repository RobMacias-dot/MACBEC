import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';

class CotizacionClientePreviewScreen extends StatelessWidget {
  const CotizacionClientePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Vista cliente',
      child: EmptyState(
        title: 'Vista cliente',
        message: 'Esta vista ocultará costos internos, utilidad y margen.',
        icon: Icons.picture_as_pdf_outlined,
      ),
    );
  }
}
