import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show OrderingTerm;

import '../../../../data/local/database/app_database.dart';
import '../../../engineering_core/data/mec_document_importer.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class AnalisisProductoScreen extends StatefulWidget {
  const AnalisisProductoScreen({super.key});

  @override
  State<AnalisisProductoScreen> createState() => _AnalisisProductoScreenState();
}

class _AnalisisProductoScreenState extends State<AnalisisProductoScreen> {
  final _database = AppDatabase();
  MecImportedProductType _selectedProductType = MecImportedProductType.panel;
  String? _selectedFileName;
  List<TechnicalDocument> _documents = const [];
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'MEC - fichas técnicas',
      child: ListView(
        children: [
          SectionCard(
            title: 'Agregar documento técnico',
            subtitle:
                'El PDF se guarda localmente con una huella SHA-256 y queda listo para su revisión MEC.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<MecImportedProductType>(
                  initialValue: _selectedProductType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de producto',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: MecImportedProductType.panel,
                      child: Text('Panel solar'),
                    ),
                    DropdownMenuItem(
                      value: MecImportedProductType.inverter,
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
                    onPressed: _isImporting ? null : _pickDatasheet,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(_isImporting
                        ? 'Guardando PDF...'
                        : 'Seleccionar datasheet PDF'),
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
            title: 'Revisión y trazabilidad',
            subtitle:
                'Los documentos recién cargados quedan como pendientes de revisión: ningún valor se usa para dimensionar hasta confirmarlo.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedProductType == MecImportedProductType.panel) ...[
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
          const SizedBox(height: 16),
          SectionCard(
            title: 'Documentos cargados',
            subtitle:
                '${_documents.length} ficha(s) técnica(s) registrada(s) en el MEC.',
            child: _documents.isEmpty
                ? const _InfoRow(
                    icon: Icons.folder_open_outlined,
                    text: 'Aún no hay PDFs cargados manualmente.',
                  )
                : Column(
                    children: _documents
                        .take(8)
                        .map((document) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading:
                                  const Icon(Icons.picture_as_pdf_outlined),
                              title: Text(document.fileName),
                              subtitle: Text(document.verificationStatus ==
                                      'confirmed_datasheet'
                                  ? 'Ficha confirmada'
                                  : 'Pendiente de revisión'),
                              trailing: Icon(document.verificationStatus ==
                                      'confirmed_datasheet'
                                  ? Icons.verified_outlined
                                  : Icons.pending_outlined),
                            ))
                        .toList(),
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

    final sourcePath = result.files.single.path;
    if (sourcePath == null) return;

    setState(() => _isImporting = true);
    try {
      final document = await MecDocumentImporter(_database).importPdf(
        sourcePath: sourcePath,
        productType: _selectedProductType,
      );
      if (!mounted) return;
      setState(() => _selectedFileName = document.fileName);
      await _loadDocuments();
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ficha técnica guardada en el MEC. Revísala y vincúlala al producto antes de usarla.',
        ),
      ),
    );
  }

  Future<void> _loadDocuments() async {
    final documents = await (_database.select(_database.technicalDocuments)
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .get();
    if (mounted) setState(() => _documents = documents);
  }
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
