import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../cotizaciones/application/quotation_draft_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Dashboard',
      child: ListView(
        children: [
          SectionCard(
            title: 'Flujo comercial',
            subtitle:
                'Cotización provisional → Recibo CFE → Análisis → Selección técnica → Dimensionamiento → PDF → Aprobación → Cliente/Expediente',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DashboardButton(
                  label: 'Nueva cotización',
                  icon: Icons.request_quote_outlined,
                  onTap: () {
                    ref.read(activeQuotationDraftIdProvider.notifier).state =
                        null;
                    ref.read(quotationDraftProspectProvider.notifier).state =
                        null;
                    context.go(AppRoutes.cotizacionProspectoForm);
                  },
                ),
                _DashboardButton(
                  label: 'Clientes',
                  icon: Icons.people_outline,
                  onTap: () => context.go(AppRoutes.clientes),
                ),
                _DashboardButton(
                  label: 'Expedientes',
                  icon: Icons.folder_outlined,
                  onTap: () => context.go(AppRoutes.expediente),
                ),
                _DashboardButton(
                  label: 'Configuración',
                  icon: Icons.settings_outlined,
                  onTap: () => context.go(AppRoutes.configuracion),
                ),
                _DashboardButton(
                  label: 'MEC',
                  icon: Icons.upload_file_outlined,
                  onTap: () => context.go(AppRoutes.proveedores),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardButton extends StatelessWidget {
  const _DashboardButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 34,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
