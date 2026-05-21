import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/components/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class ProveedoresScreen extends StatelessWidget {
  const ProveedoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Actualizar precios',
      child: ListView(
        children: [
          SectionCard(
            title: '¿Cómo quieres actualizar?',
            subtitle:
                'Puedes cargar el Excel estándar completo o preparar el análisis de un producto individual desde su datasheet.',
            child: Column(
              children: [
                _UpdateOptionCard(
                  icon: Icons.table_chart_outlined,
                  title: 'Cargar Excel estándar',
                  description:
                      'Actualiza el catálogo comercial usando la plantilla de importación. Actualmente importa paneles e inversores.',
                  buttonLabel: 'Seleccionar Excel',
                  onTap: () => context.go(AppRoutes.importacionCatalogo),
                ),
                const SizedBox(height: 12),
                _UpdateOptionCard(
                  icon: Icons.description_outlined,
                  title: 'Por producto / datasheet',
                  description:
                      'Prepara el análisis individual de un panel o inversor desde su ficha técnica. Esta base servirá para extracción automática de datos técnicos.',
                  buttonLabel: 'Analizar producto',
                  onTap: () => context.go(AppRoutes.analisisProductoCatalogo),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionCard(
            title: 'Criterio de catálogo',
            subtitle:
                'La app separa productos comerciales de referencias técnicas para evitar cálculos incorrectos.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProviderInfoRow(
                  icon: Icons.storefront_outlined,
                  text:
                      'Productos comerciales: paneles, inversores, protecciones, material eléctrico, estructura y mano de obra.',
                ),
                SizedBox(height: 8),
                _ProviderInfoRow(
                  icon: Icons.functions_outlined,
                  text:
                      'Referencias técnicas: ampacidad de cables, capacidad de tuberías y radiación solar.',
                ),
                SizedBox(height: 8),
                _ProviderInfoRow(
                  icon: Icons.verified_outlined,
                  text:
                      'Cables.xlsx y Tuberias.xlsx se conservan como referencias técnicas, no como listas comerciales de precio.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateOptionCard extends StatelessWidget {
  const _UpdateOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_outlined),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderInfoRow extends StatelessWidget {
  const _ProviderInfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 22,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
