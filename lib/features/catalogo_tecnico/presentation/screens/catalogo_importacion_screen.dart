import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart';

import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../application/inverter_catalog_controller.dart';
import '../../application/panel_catalog_controller.dart';
import '../../domain/entities/solar_inverter.dart';
import '../../domain/entities/solar_panel.dart';

enum _CatalogCategoryRole {
  importsNow,
  commercialPending,
  technicalReference,
  unknown,
}

String _normalizeCatalogCategory(String value) {
  final normalized = value.trim().toUpperCase();

  if (normalized.isEmpty) return 'SIN_CATEGORIA';

  if (normalized == 'PANEL_SOLAR' ||
      normalized.contains('PANEL') ||
      normalized.contains('MFV') ||
      normalized.contains('MODULO') ||
      normalized.contains('MÓDULO')) {
    return 'PANEL_SOLAR';
  }

  if (normalized == 'INVERSOR' || normalized.contains('INVERSOR')) {
    return 'INVERSOR';
  }

  if (normalized == 'CABLE_PRODUCTO' ||
      normalized.contains('CABLE PRODUCTO') ||
      normalized.contains('CABLE COMERCIAL') ||
      normalized.contains('CONDUCTOR PRODUCTO')) {
    return 'CABLE_PRODUCTO';
  }

  if (normalized == 'TUBERIA_PRODUCTO' ||
      normalized == 'TUBERÍA_PRODUCTO' ||
      normalized.contains('TUBERIA PRODUCTO') ||
      normalized.contains('TUBERÍA PRODUCTO') ||
      normalized.contains('CONDUIT PRODUCTO')) {
    return 'TUBERIA_PRODUCTO';
  }

  if (normalized == 'REFERENCIA_CABLE_AMPACIDAD' ||
      normalized.contains('AMPACIDAD') ||
      normalized.contains('TABLA CABLE') ||
      normalized.contains('CABLE REFERENCIA')) {
    return 'REFERENCIA_CABLE_AMPACIDAD';
  }

  if (normalized == 'REFERENCIA_TUBERIA_CAPACIDAD' ||
      normalized == 'REFERENCIA_TUBERÍA_CAPACIDAD' ||
      normalized.contains('CAPACIDAD TUBERIA') ||
      normalized.contains('CAPACIDAD TUBERÍA') ||
      normalized.contains('TABLA TUBERIA') ||
      normalized.contains('TABLA TUBERÍA') ||
      normalized.contains('TUBERIA REFERENCIA') ||
      normalized.contains('TUBERÍA REFERENCIA')) {
    return 'REFERENCIA_TUBERIA_CAPACIDAD';
  }

  if (normalized == 'REFERENCIA_RADIACION_SOLAR' ||
      normalized == 'REFERENCIA_RADIACIÓN_SOLAR' ||
      normalized.contains('RADIACION') ||
      normalized.contains('RADIACIÓN') ||
      normalized.contains('HORAS SOLARES')) {
    return 'REFERENCIA_RADIACION_SOLAR';
  }

  if (normalized == 'PROTECCION_FUSIBLE' ||
      normalized == 'PROTECCIÓN_FUSIBLE' ||
      normalized.contains('FUSIBLE')) {
    return 'PROTECCION_FUSIBLE';
  }

  if (normalized == 'PROTECCION_ITM' ||
      normalized == 'PROTECCIÓN_ITM' ||
      normalized.contains('ITM') ||
      normalized.contains('INTERRUPTOR') ||
      normalized.contains('TERMOMAGNETICO') ||
      normalized.contains('TERMOMAGNÉTICO')) {
    return 'PROTECCION_ITM';
  }

  if (normalized == 'ESTRUCTURA_ACCESORIO' ||
      normalized.contains('ESTRUCTURA') ||
      normalized.contains('RIEL') ||
      normalized.contains('CLAMP') ||
      normalized.contains('MIDCLAMP') ||
      normalized.contains('ENDCLAMP') ||
      normalized.contains('ROMPEVIENTO')) {
    return 'ESTRUCTURA_ACCESORIO';
  }

  if (normalized == 'MATERIAL_ELECTRICO' ||
      normalized == 'MATERIAL_ELÉCTRICO' ||
      normalized.contains('MATERIAL ELECTRICO') ||
      normalized.contains('MATERIAL ELÉCTRICO') ||
      normalized.contains('CONECTOR') ||
      normalized.contains('MC4') ||
      normalized.contains('ACCESORIO ELECTRICO') ||
      normalized.contains('ACCESORIO ELÉCTRICO')) {
    return 'MATERIAL_ELECTRICO';
  }

  if (normalized == 'MANO_OBRA_CONCEPTO' ||
      normalized.contains('MANO DE OBRA') ||
      normalized.contains('COMISION') ||
      normalized.contains('COMISIÓN') ||
      normalized.contains('TRAMITE') ||
      normalized.contains('TRÁMITE')) {
    return 'MANO_OBRA_CONCEPTO';
  }

  return normalized;
}

String _catalogCategoryLabel(String category) {
  switch (category) {
    case 'PANEL_SOLAR':
      return 'Paneles solares';
    case 'INVERSOR':
      return 'Inversores';
    case 'CABLE_PRODUCTO':
      return 'Cable comercial';
    case 'TUBERIA_PRODUCTO':
      return 'Tubería comercial';
    case 'PROTECCION_FUSIBLE':
      return 'Fusibles';
    case 'PROTECCION_ITM':
      return 'Interruptores ITM';
    case 'MATERIAL_ELECTRICO':
      return 'Material eléctrico';
    case 'ESTRUCTURA_ACCESORIO':
      return 'Estructura y accesorios';
    case 'MANO_OBRA_CONCEPTO':
      return 'Mano de obra / conceptos';
    case 'REFERENCIA_CABLE_AMPACIDAD':
      return 'Referencia técnica de cables';
    case 'REFERENCIA_TUBERIA_CAPACIDAD':
      return 'Referencia técnica de tuberías';
    case 'REFERENCIA_RADIACION_SOLAR':
      return 'Referencia de radiación solar';
    case 'SIN_CATEGORIA':
      return 'Sin categoría';
    default:
      return category;
  }
}

_CatalogCategoryRole _catalogCategoryRole(String category) {
  switch (category) {
    case 'PANEL_SOLAR':
    case 'INVERSOR':
      return _CatalogCategoryRole.importsNow;

    case 'CABLE_PRODUCTO':
    case 'TUBERIA_PRODUCTO':
    case 'PROTECCION_FUSIBLE':
    case 'PROTECCION_ITM':
    case 'MATERIAL_ELECTRICO':
    case 'ESTRUCTURA_ACCESORIO':
    case 'MANO_OBRA_CONCEPTO':
      return _CatalogCategoryRole.commercialPending;

    case 'REFERENCIA_CABLE_AMPACIDAD':
    case 'REFERENCIA_TUBERIA_CAPACIDAD':
    case 'REFERENCIA_RADIACION_SOLAR':
      return _CatalogCategoryRole.technicalReference;

    default:
      return _CatalogCategoryRole.unknown;
  }
}

bool _isImportEnabledForCategory(String category) {
  return _catalogCategoryRole(category) == _CatalogCategoryRole.importsNow;
}

bool _isTechnicalReferenceCategory(String category) {
  return _catalogCategoryRole(category) ==
      _CatalogCategoryRole.technicalReference;
}

IconData _catalogCategoryIcon(String category) {
  switch (_catalogCategoryRole(category)) {
    case _CatalogCategoryRole.importsNow:
      return Icons.check_circle_outline;
    case _CatalogCategoryRole.commercialPending:
      return Icons.storefront_outlined;
    case _CatalogCategoryRole.technicalReference:
      return Icons.functions_outlined;
    case _CatalogCategoryRole.unknown:
      return Icons.help_outline;
  }
}

String _catalogCategoryStatusText(String category) {
  switch (_catalogCategoryRole(category)) {
    case _CatalogCategoryRole.importsNow:
      return 'Se importa ahora';
    case _CatalogCategoryRole.commercialPending:
      return 'Comercial pendiente';
    case _CatalogCategoryRole.technicalReference:
      return 'Referencia técnica';
    case _CatalogCategoryRole.unknown:
      return 'No clasificada';
  }
}

class CatalogoImportacionScreen extends ConsumerStatefulWidget {
  const CatalogoImportacionScreen({super.key});

  @override
  ConsumerState<CatalogoImportacionScreen> createState() =>
      _CatalogoImportacionScreenState();
}

class _CatalogoImportacionScreenState
    extends ConsumerState<CatalogoImportacionScreen> {
  String? _fileName;
  _CatalogImportPreview? _preview;

  bool _isReading = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Actualizar precios',
      child: ListView(
        children: [
          SectionCard(
            title: 'Importar catálogo estándar',
            subtitle:
                'Carga el Excel estándar de MacBec. La app validará la hoja Catalogo_Productos antes de actualizar el catálogo.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ImportInfoRow(
                  icon: Icons.table_chart_outlined,
                  text:
                      'Por ahora se importan paneles solares e inversores. Cables y tuberías técnicas se mantienen como referencias internas; los precios comerciales se actualizarán después desde Excel de proveedores.',
                ),
                const SizedBox(height: 10),
                const _ImportInfoRow(
                  icon: Icons.verified_outlined,
                  text:
                      'Paneles e inversores se actualizan por marca + modelo. Las demás categorías se detectan, pero no se importan hasta tener su módulo confiable.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isReading ? null : _pickAndReadExcel,
                    icon: _isReading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(
                      _isReading
                          ? 'Leyendo Excel...'
                          : 'Seleccionar Excel estándar',
                    ),
                  ),
                ),
                if (_fileName != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Archivo seleccionado: $_fileName',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (_preview != null) ...[
            const SizedBox(height: 16),
            _ImportPreviewCard(preview: _preview!),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Confirmar importación',
              subtitle:
                  'Revisa el resumen antes de actualizar el catálogo local.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_preview!.panelCandidates.isEmpty &&
                      _preview!.inverterCandidates.isEmpty)
                    const _ImportInfoRow(
                      icon: Icons.info_outline,
                      text:
                          'No se encontraron paneles solares ni inversores válidos para importar.',
                    )
                  else ...[
                    _ImportInfoRow(
                      icon: Icons.inventory_2_outlined,
                      text:
                          'Se importarán ${_preview!.panelCandidates.length} paneles solares y ${_preview!.inverterCandidates.length} inversores. Las demás categorías solo quedarán detectadas para mantener el catálogo confiable.',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isImporting ? null : _importCatalog,
                        icon: _isImporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _isImporting
                              ? 'Importando catálogo...'
                              : 'Importar paneles e inversores',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndReadExcel() async {
    setState(() {
      _isReading = true;
      _preview = null;
      _fileName = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final bytes = await _readPickedFileBytes(file);

      if (bytes == null) {
        _showSnackBar(
          'No se pudo leer el archivo seleccionado.',
        );
        return;
      }

      final preview = _parseCatalogExcel(bytes);

      setState(() {
        _fileName = file.name;
        _preview = preview;
      });
    } catch (error) {
      _showSnackBar('No se pudo procesar el Excel: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isReading = false;
        });
      }
    }
  }

  Future<Uint8List?> _readPickedFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes;
    }

    final path = file.path;

    if (path == null || path.trim().isEmpty) {
      return null;
    }

    return File(path).readAsBytes();
  }

  List<List<String?>> _readCatalogProductsRows(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    final workbookXml = _readXmlFromArchive(
      archive,
      'xl/workbook.xml',
    );

    final sheetElement = _findElementsByLocalName(workbookXml, 'sheet')
        .where(
          (element) =>
              (_getXmlAttribute(element, 'name') ?? '').trim() ==
              'Catalogo_Productos',
        )
        .firstOrNull;

    if (sheetElement == null) {
      final availableSheets = _findElementsByLocalName(workbookXml, 'sheet')
          .map((element) => _getXmlAttribute(element, 'name'))
          .whereType<String>()
          .join(', ');

      throw StateError(
        'El Excel debe tener una hoja llamada Catalogo_Productos. Hojas detectadas: $availableSheets',
      );
    }

    final relationshipId = _getXmlAttribute(sheetElement, 'id');

    if (relationshipId == null || relationshipId.trim().isEmpty) {
      throw StateError(
        'No se pudo localizar la hoja Catalogo_Productos dentro del Excel.',
      );
    }

    final relationshipsXml = _readXmlFromArchive(
      archive,
      'xl/_rels/workbook.xml.rels',
    );

    final relationshipElement =
        _findElementsByLocalName(relationshipsXml, 'Relationship')
            .where(
              (element) => _getXmlAttribute(element, 'Id') == relationshipId,
            )
            .firstOrNull;

    if (relationshipElement == null) {
      throw StateError(
        'No se pudo abrir la hoja Catalogo_Productos dentro del Excel.',
      );
    }

    final target = _getXmlAttribute(relationshipElement, 'Target');

    if (target == null || target.trim().isEmpty) {
      throw StateError(
        'No se encontró la ruta interna de la hoja Catalogo_Productos.',
      );
    }

    final sheetPath = _resolveWorkbookTarget(target);
    final sheetXml = _readXmlFromArchive(archive, sheetPath);
    final sharedStrings = _readSharedStrings(archive);

    return _readSheetRows(sheetXml, sharedStrings);
  }

  XmlDocument _readXmlFromArchive(
    Archive archive,
    String path,
  ) {
    final normalizedPath = path.replaceAll('\\', '/');

    final file = archive.files.where((file) {
      return file.name.replaceAll('\\', '/') == normalizedPath;
    }).firstOrNull;

    if (file == null || !file.isFile) {
      throw StateError(
        'No se encontró el archivo interno $normalizedPath dentro del Excel.',
      );
    }

    final bytes = file.content as List<int>;

    final xmlText = utf8.decode(
      bytes,
      allowMalformed: true,
    );

    return XmlDocument.parse(xmlText);
  }

  String _resolveWorkbookTarget(String target) {
    final normalizedTarget = target.replaceAll('\\', '/');

    if (normalizedTarget.startsWith('/')) {
      return normalizedTarget.substring(1);
    }

    if (normalizedTarget.startsWith('xl/')) {
      return normalizedTarget;
    }

    return 'xl/$normalizedTarget';
  }

  List<String> _readSharedStrings(Archive archive) {
    final sharedStringsFile = archive.files.where((file) {
      return file.name.replaceAll('\\', '/') == 'xl/sharedStrings.xml';
    }).firstOrNull;
    if (sharedStringsFile == null || !sharedStringsFile.isFile) {
      return const [];
    }
    final xmlText = utf8.decode(
      sharedStringsFile.content as List<int>,
      allowMalformed: true,
    );
    final document = XmlDocument.parse(xmlText);
    return _findElementsByLocalName(document, 'si').map((element) {
      return _findElementsByLocalName(element, 't').map((textElement) {
        return textElement.innerText;
      }).join();
    }).toList();
  }

  List<List<String?>> _readSheetRows(
    XmlDocument sheetXml,
    List<String> sharedStrings,
  ) {
    final rows = <List<String?>>[];

    for (final rowElement in _findElementsByLocalName(sheetXml, 'row')) {
      final rowNumber = int.tryParse(
            _getXmlAttribute(rowElement, 'r') ?? '',
          ) ??
          rows.length + 1;

      while (rows.length < rowNumber - 1) {
        rows.add(const []);
      }

      final cells = <int, String?>{};
      var maxColumnIndex = -1;

      for (final cellElement in _findElementsByLocalName(rowElement, 'c')) {
        final cellReference = _getXmlAttribute(cellElement, 'r') ?? '';
        final columnIndex = _columnIndexFromCellReference(cellReference);

        if (columnIndex < 0) continue;

        cells[columnIndex] = _readCellValue(
          cellElement,
          sharedStrings,
        );

        if (columnIndex > maxColumnIndex) {
          maxColumnIndex = columnIndex;
        }
      }

      final row = List<String?>.filled(
        maxColumnIndex + 1,
        null,
      );

      for (final entry in cells.entries) {
        row[entry.key] = entry.value;
      }

      rows.add(row);
    }

    return rows;
  }

  String? _readCellValue(
    XmlElement cellElement,
    List<String> sharedStrings,
  ) {
    final cellType = _getXmlAttribute(cellElement, 't');

    if (cellType == 'inlineStr') {
      final text = _findElementsByLocalName(cellElement, 't').map((element) {
        return element.innerText;
      }).join();

      return text.trim();
    }

    final valueElement =
        _findDirectElementsByLocalName(cellElement, 'v').firstOrNull;

    if (valueElement == null) return null;

    final rawValue = valueElement.innerText.trim();

    if (rawValue.isEmpty) return null;

    if (cellType == 's') {
      final sharedStringIndex = int.tryParse(rawValue);

      if (sharedStringIndex == null ||
          sharedStringIndex < 0 ||
          sharedStringIndex >= sharedStrings.length) {
        return null;
      }

      return sharedStrings[sharedStringIndex].trim();
    }

    if (cellType == 'b') {
      return rawValue == '1' ? 'true' : 'false';
    }

    return rawValue;
  }

  int _columnIndexFromCellReference(String cellReference) {
    final letters =
        RegExp(r'^[A-Z]+').firstMatch(cellReference.toUpperCase())?.group(0);

    if (letters == null || letters.isEmpty) return -1;

    var columnIndex = 0;

    for (int i = 0; i < letters.length; i++) {
      columnIndex *= 26;
      columnIndex += letters.codeUnitAt(i) - 64;
    }

    return columnIndex - 1;
  }

  String? _getXmlAttribute(
    XmlElement element,
    String attributeName,
  ) {
    final normalizedName = attributeName.toLowerCase();

    for (final attribute in element.attributes) {
      if (attribute.name.local.toLowerCase() == normalizedName) {
        return attribute.value;
      }
    }

    return null;
  }

  Iterable<XmlElement> _findElementsByLocalName(
    XmlNode node,
    String localName,
  ) {
    return node.descendants.whereType<XmlElement>().where(
          (element) => element.name.local == localName,
        );
  }

  Iterable<XmlElement> _findDirectElementsByLocalName(
    XmlElement element,
    String localName,
  ) {
    return element.children.whereType<XmlElement>().where(
          (child) => child.name.local == localName,
        );
  }

  _CatalogImportPreview _parseCatalogExcel(Uint8List bytes) {
    final rows = _readCatalogProductsRows(bytes);

    if (rows.isEmpty) {
      throw StateError(
        'La hoja Catalogo_Productos está vacía.',
      );
    }

    final headers = <String, int>{};

    final headerRow = rows.first;

    for (int index = 0; index < headerRow.length; index++) {
      final header = headerRow[index];

      if (header == null || header.trim().isEmpty) continue;

      headers[header.trim().toLowerCase()] = index;
    }

    final requiredColumns = [
      'categoria_app',
      'marca',
      'modelo',
      'precio_compra',
      'precio_mxn',
      'potencia_w',
      'voc_v',
      'isc_a',
      'largo_mm',
      'ancho_mm',
      'espesor_mm',
      'activo',
    ];

    final missingColumns = requiredColumns
        .where((column) => !headers.containsKey(column))
        .toList();

    if (missingColumns.isNotEmpty) {
      throw StateError(
        'Faltan columnas en Catalogo_Productos: ${missingColumns.join(', ')}.',
      );
    }

    final categoryCounts = <String, int>{};
    final panelCandidates = <_PanelImportCandidate>[];
    final inverterCandidates = <_InverterImportCandidate>[];
    final warnings = <String>[];

    for (int rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];

      final category = _getString(row, headers, 'categoria_app') ?? '';

      if (category.trim().isEmpty) continue;

      final normalizedCategory = _normalizeCatalogCategory(category);

      categoryCounts[normalizedCategory] =
          (categoryCounts[normalizedCategory] ?? 0) + 1;

      if (!_isImportEnabledForCategory(normalizedCategory)) {
        if (categoryCounts[normalizedCategory] == 1) {
          warnings.add(
            '${_catalogCategoryLabel(normalizedCategory)} detectado como "${_catalogCategoryStatusText(normalizedCategory)}". No está disponible para importación.',
          );
        }

        continue;
      }

      if (normalizedCategory == 'INVERSOR') {
        final brand = _getString(row, headers, 'marca') ?? '';
        final model = _getString(row, headers, 'modelo') ?? '';

        final nominalPowerWatts = _getDoubleFromFirstAvailable(
              row,
              headers,
              [
                'potencia_nominal_w',
                'potencia_inversor_w',
                'nominal_power_w',
                'potencia_w',
              ],
            ) ??
            _extractPowerWattsFromText('$brand $model');

        if (brand.trim().isEmpty ||
            model.trim().isEmpty ||
            nominalPowerWatts == null ||
            nominalPowerWatts <= 0) {
          warnings.add(
            'Fila ${rowIndex + 1}: inversor omitido por falta de marca, modelo o potencia nominal.',
          );
          continue;
        }

        final isActive = _getBool(row, headers, 'activo') ?? true;

        if (!isActive) {
          warnings.add(
            'Fila ${rowIndex + 1}: inversor inactivo omitido temporalmente.',
          );
          continue;
        }

        final priceMxn = _getDouble(row, headers, 'precio_mxn');
        final purchasePrice =
            priceMxn ?? _getDouble(row, headers, 'precio_compra');

        final input = SaveSolarInverterInput(
          brand: brand,
          model: model,
          nominalPowerWatts: nominalPowerWatts,
          maxPvPowerWatts: _getDoubleFromFirstAvailable(
            row,
            headers,
            [
              'max_potencia_fv_w',
              'potencia_max_fv_w',
              'max_pv_power_w',
              'max_pv_power_watts',
            ],
          ),
          maxDcVoltage: _getDoubleFromFirstAvailable(
            row,
            headers,
            [
              'max_voltaje_cd_v',
              'voltaje_max_cd_v',
              'max_dc_voltage_v',
            ],
          ),
          maxShortCircuitCurrentPerMppt: _getDoubleFromFirstAvailable(
            row,
            headers,
            [
              'corriente_cc_mppt_a',
              'corriente_corto_circuito_mppt_a',
              'max_isc_mppt_a',
              'max_short_circuit_current_per_mppt_a',
            ],
          ),
          maxOutputCurrent: _getDoubleFromFirstAvailable(
            row,
            headers,
            [
              'corriente_salida_a',
              'corriente_max_salida_a',
              'max_output_current_a',
            ],
          ),
          mpptCount: _getIntFromFirstAvailable(
            row,
            headers,
            [
              'mppt_count',
              'mppt',
              'numero_mppt',
              'numero_mppts',
            ],
          ),
          purchasePrice: purchasePrice,
          priceSource: 'Excel estándar',
        );

        inverterCandidates.add(
          _InverterImportCandidate(
            rowNumber: rowIndex + 1,
            input: input,
          ),
        );

        if (!input.hasRequiredTechnicalDataForDimensioning) {
          warnings.add(
            'Fila ${rowIndex + 1}: ${input.brand} ${input.model} se importará con precio, pero aún tiene datos técnicos incompletos para dimensionamiento.',
          );
        }

        continue;
      }

      final brand = _getString(row, headers, 'marca') ?? '';
      final model = _getString(row, headers, 'modelo') ?? '';
      final powerWatts = _getDouble(row, headers, 'potencia_w');

      if (brand.trim().isEmpty ||
          model.trim().isEmpty ||
          powerWatts == null ||
          powerWatts <= 0) {
        warnings.add(
          'Fila ${rowIndex + 1}: panel omitido por falta de marca, modelo o potencia.',
        );
        continue;
      }

      final priceMxn = _getDouble(row, headers, 'precio_mxn');
      final purchasePrice =
          priceMxn ?? _getDouble(row, headers, 'precio_compra');

      final input = SaveSolarPanelInput(
        brand: brand,
        model: model,
        powerWatts: powerWatts,
        voc: _getDouble(row, headers, 'voc_v'),
        isc: _getDouble(row, headers, 'isc_a'),
        lengthMm: _getDouble(row, headers, 'largo_mm'),
        widthMm: _getDouble(row, headers, 'ancho_mm'),
        thicknessMm: _getDouble(row, headers, 'espesor_mm'),
        purchasePrice: purchasePrice,
        isActive: _getBool(row, headers, 'activo') ?? true,
      );

      panelCandidates.add(
        _PanelImportCandidate(
          rowNumber: rowIndex + 1,
          input: input,
        ),
      );

      if (input.voc == null ||
          input.isc == null ||
          input.lengthMm == null ||
          input.widthMm == null) {
        warnings.add(
          'Fila ${rowIndex + 1}: ${input.brand} ${input.model} se importará, pero tiene datos técnicos incompletos.',
        );
      }
    }

    return _CatalogImportPreview(
      totalRows: rows.length - 1,
      categoryCounts: categoryCounts,
      panelCandidates: panelCandidates,
      inverterCandidates: inverterCandidates,
      warnings: warnings,
    );
  }

  Future<void> _importCatalog() async {
    final preview = _preview;

    if (preview == null ||
        (preview.panelCandidates.isEmpty &&
            preview.inverterCandidates.isEmpty)) {
      return;
    }

    setState(() {
      _isImporting = true;
    });

    var panelsCreated = 0;
    var panelsUpdated = 0;
    var invertersCreated = 0;
    var invertersUpdated = 0;

    try {
      final panelRepository = ref.read(panelCatalogRepositoryProvider);
      final inverterRepository = ref.read(inverterCatalogRepositoryProvider);

      for (final candidate in preview.panelCandidates) {
        final wasCreated = await panelRepository.upsertPanelByBrandAndModel(
          candidate.input,
        );

        if (wasCreated) {
          panelsCreated++;
        } else {
          panelsUpdated++;
        }
      }

      for (final candidate in preview.inverterCandidates) {
        final wasCreated =
            await inverterRepository.upsertInverterByBrandAndModel(
          candidate.input,
        );

        if (wasCreated) {
          invertersCreated++;
        } else {
          invertersUpdated++;
        }
      }

      ref.invalidate(panelsCatalogProvider);
      ref.invalidate(invertersCatalogProvider);

      if (!mounted) return;

      _showSnackBar(
        'Importación lista: $panelsCreated paneles creados, $panelsUpdated paneles actualizados, $invertersCreated inversores creados, $invertersUpdated inversores actualizados.',
      );
    } catch (error) {
      _showSnackBar('No se pudo importar el catálogo: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  String? _getString(
    List<String?> row,
    Map<String, int> headers,
    String column,
  ) {
    final index = headers[column];

    if (index == null || index >= row.length) return null;

    final value = row[index];

    if (value == null || value.trim().isEmpty) return null;

    return value.trim();
  }

  double? _getDouble(
    List<String?> row,
    Map<String, int> headers,
    String column,
  ) {
    final value = _getString(row, headers, column);

    if (value == null || value.trim().isEmpty) return null;

    var cleanValue = value.trim();
    cleanValue = cleanValue.replaceAll(RegExp(r'[\$\s]'), '');

    if (cleanValue.contains(',') && cleanValue.contains('.')) {
      cleanValue = cleanValue.replaceAll(',', '');
    } else if (cleanValue.contains(',')) {
      cleanValue = cleanValue.replaceAll(',', '.');
    }

    return double.tryParse(cleanValue);
  }

  double? _getDoubleFromFirstAvailable(
    List<String?> row,
    Map<String, int> headers,
    List<String> columns,
  ) {
    for (final column in columns) {
      if (!headers.containsKey(column)) continue;

      final value = _getDouble(row, headers, column);

      if (value != null) {
        return value;
      }
    }

    return null;
  }

  int? _getIntFromFirstAvailable(
    List<String?> row,
    Map<String, int> headers,
    List<String> columns,
  ) {
    final value = _getDoubleFromFirstAvailable(row, headers, columns);

    if (value == null) return null;

    return value.round();
  }

  double? _extractPowerWattsFromText(String value) {
    final normalizedValue = value.toLowerCase().replaceAll(',', '.');

    final kwMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*k\s*w',
    ).firstMatch(normalizedValue);

    if (kwMatch != null) {
      final kwValue = double.tryParse(kwMatch.group(1) ?? '');

      if (kwValue != null && kwValue > 0) {
        return kwValue * 1000;
      }
    }

    final wattsMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*w',
    ).firstMatch(normalizedValue);

    if (wattsMatch != null) {
      final wattsValue = double.tryParse(wattsMatch.group(1) ?? '');

      if (wattsValue != null && wattsValue > 0) {
        return wattsValue;
      }
    }

    return null;
  }

  bool? _getBool(
    List<String?> row,
    Map<String, int> headers,
    String column,
  ) {
    final value = _getString(row, headers, column);

    if (value == null || value.trim().isEmpty) return null;

    final normalizedValue = value.trim().toLowerCase();

    if (normalizedValue == 'si' ||
        normalizedValue == 'sí' ||
        normalizedValue == 'true' ||
        normalizedValue == '1' ||
        normalizedValue == 'activo') {
      return true;
    }

    if (normalizedValue == 'no' ||
        normalizedValue == 'false' ||
        normalizedValue == '0' ||
        normalizedValue == 'inactivo') {
      return false;
    }

    return null;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}

class _CatalogImportPreview {
  const _CatalogImportPreview({
    required this.totalRows,
    required this.categoryCounts,
    required this.panelCandidates,
    required this.inverterCandidates,
    required this.warnings,
  });

  final int totalRows;
  final Map<String, int> categoryCounts;
  final List<_PanelImportCandidate> panelCandidates;
  final List<_InverterImportCandidate> inverterCandidates;
  final List<String> warnings;
}

class _PanelImportCandidate {
  const _PanelImportCandidate({
    required this.rowNumber,
    required this.input,
  });

  final int rowNumber;
  final SaveSolarPanelInput input;
}

class _InverterImportCandidate {
  const _InverterImportCandidate({
    required this.rowNumber,
    required this.input,
  });

  final int rowNumber;
  final SaveSolarInverterInput input;
}

extension _SaveSolarInverterInputValidation on SaveSolarInverterInput {
  bool get hasRequiredTechnicalDataForDimensioning {
    return nominalPowerWatts > 0 &&
        maxPvPowerWatts != null &&
        maxPvPowerWatts! > 0 &&
        maxDcVoltage != null &&
        maxDcVoltage! > 0 &&
        maxShortCircuitCurrentPerMppt != null &&
        maxShortCircuitCurrentPerMppt! > 0 &&
        maxOutputCurrent != null &&
        maxOutputCurrent! > 0 &&
        mpptCount != null &&
        mpptCount! > 0;
  }
}

class _ImportPreviewCard extends StatelessWidget {
  const _ImportPreviewCard({
    required this.preview,
  });

  final _CatalogImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final sortedCategories = preview.categoryCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final hasCommercialPending = sortedCategories.any(
      (entry) =>
          _catalogCategoryRole(entry.key) ==
          _CatalogCategoryRole.commercialPending,
    );

    final hasTechnicalReferences = sortedCategories.any(
      (entry) => _isTechnicalReferenceCategory(entry.key),
    );

    final hasUnknownCategories = sortedCategories.any(
      (entry) =>
          _catalogCategoryRole(entry.key) == _CatalogCategoryRole.unknown,
    );

    return SectionCard(
      title: 'Vista previa del Excel',
      subtitle:
          'La app detectó ${preview.totalRows} filas de productos en el archivo estándar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ImportInfoRow(
            icon: Icons.inventory_2_outlined,
            text:
                '${preview.panelCandidates.length} paneles solares y ${preview.inverterCandidates.length} inversores listos para importar.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in sortedCategories)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    _catalogCategoryIcon(entry.key),
                  ),
                  label: Text(
                    '${_catalogCategoryLabel(entry.key)}: ${entry.value}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const _ImportInfoRow(
            icon: Icons.check_circle_outline,
            text: 'Importación disponible: paneles solares e inversores.',
          ),
          if (hasCommercialPending) ...[
            const SizedBox(height: 8),
            const _ImportInfoRow(
              icon: Icons.storefront_outlined,
              text:
                  'Las demás categorías se detectan, pero aún no están disponibles para importación.',
            ),
          ],
          if (hasTechnicalReferences) ...[
            const SizedBox(height: 8),
            const _ImportInfoRow(
              icon: Icons.functions_outlined,
              text:
                  'Referencias técnicas: cables, tuberías o radiación deben vivir como tablas internas de cálculo, no como productos de precio.',
            ),
          ],
          if (hasUnknownCategories) ...[
            const SizedBox(height: 8),
            const _ImportInfoRow(
              icon: Icons.help_outline,
              text:
                  'Hay categorías no clasificadas. Conviene revisar el Excel antes de usarlas para cotización.',
            ),
          ],
          if (preview.warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Advertencias',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final warning in preview.warnings.take(8)) ...[
              _ImportInfoRow(
                icon: Icons.warning_amber_outlined,
                text: warning,
              ),
              const SizedBox(height: 6),
            ],
            if (preview.warnings.length > 8)
              Text(
                '+ ${preview.warnings.length - 8} advertencias adicionales.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ],
      ),
    );
  }
}

class _ImportInfoRow extends StatelessWidget {
  const _ImportInfoRow({
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
