import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../shared/components/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class AnalisisProductoScreen extends StatefulWidget {
  const AnalisisProductoScreen({super.key});

  @override
  State<AnalisisProductoScreen> createState() => _AnalisisProductoScreenState();
}

class _AnalisisProductoScreenState extends State<AnalisisProductoScreen> {
  _ProductType _selectedProductType = _ProductType.panel;
  String? _selectedFileName;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Analizar producto',
      child: ListView(
        children: [
          SectionCard(
            title: 'Producto individual',
            subtitle: 'Carga la ficha técnica correspondiente al producto.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<_ProductType>(
                  initialValue: _selectedProductType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de producto',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _ProductType.panel,
                      child: Text('Panel solar'),
                    ),
                    DropdownMenuItem(
                      value: _ProductType.inverter,
                      child: Text('Inversor'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedProductType = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _pickDatasheet,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Seleccionar datasheet PDF'),
                  ),
                ),
                if (_selectedFileName != null) ...[
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.description_outlined,
                    text: 'Archivo seleccionado: $_selectedFileName',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Campos que se analizarán',
            subtitle: 'Selecciona un archivo para asociarlo al producto.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedProductType == _ProductType.panel) ...[
                  const _InfoRow(
                    icon: Icons.solar_power_outlined,
                    text:
                        'Panel: marca, modelo, potencia W, Voc, Isc, largo, ancho, espesor y notas de datasheet.',
                  ),
                ] else ...[
                  const _InfoRow(
                    icon: Icons.electrical_services_outlined,
                    text:
                        'Inversor: marca, modelo, potencia nominal, potencia FV máxima, voltaje CD máximo, MPPT, corriente de cortocircuito por MPPT y corriente de salida.',
                  ),
                ],
                const SizedBox(height: 10),
                const _InfoRow(
                  icon: Icons.info_outline,
                  text:
                      'Verifica que los datos de la ficha técnica sean correctos antes de utilizar el producto en una cotización.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDatasheet() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _selectedFileName = result.files.single.name;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ficha técnica cargada correctamente.',
        ),
      ),
    );
  }
}

enum _ProductType {
  panel,
  inverter,
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
