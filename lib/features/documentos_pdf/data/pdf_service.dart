import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_assets.dart';
import '../../estructura/domain/structure_design_rules.dart';
import '../domain/entities/contract_pdf_data.dart';
import '../domain/entities/pre_invoice_pdf_data.dart';
import '../domain/entities/quotation_pdf_data.dart';
import '../domain/entities/structure_technical_pdf_data.dart';
import '../domain/entities/technical_proposal_pdf_data.dart';

final pdfServiceProvider = Provider<PdfService>((ref) => PdfService());

class PdfService {
  static const _brandColor = PdfColor.fromInt(0xFF005A9C);
  static const _mutedColor = PdfColor.fromInt(0xFF5A6B76);

  Future<Uint8List> generateQuotationPdf(QuotationPdfData data) async {
    final document = pw.Document();
    final logoImage = await _loadLogo();
    final currencyFormatter = _quotationCurrencyFormatter();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          company: data.company,
          documentLabel: 'Cotización ${data.draftCode}',
          generatedAt: data.generatedAt,
          logo: logoImage,
        ),
        footer: (context) => _buildFooter(context, data.company),
        build: (context) => _quotationContent(data, currencyFormatter),
      ),
    );

    return document.save();
  }

  /// Cotización comercial + planos estructurales fusionados en un solo PDF
  /// (ver Fase 6.23): un único [pw.Document] con dos secciones de páginas,
  /// en vez de generar y luego intentar unir dos archivos PDF ya
  /// serializados.
  Future<Uint8List> generateQuotationWithStructuralPdf({
    required QuotationPdfData quotationData,
    required StructureTechnicalPdfData structureData,
  }) async {
    final document = pw.Document();
    final logoImage = await _loadLogo();
    final currencyFormatter = _quotationCurrencyFormatter();
    final font = PdfFont.helvetica(document.document);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          company: quotationData.company,
          documentLabel: 'Cotización ${quotationData.draftCode}',
          generatedAt: quotationData.generatedAt,
          logo: logoImage,
        ),
        footer: (context) => _buildFooter(context, quotationData.company),
        build: (context) => _quotationContent(quotationData, currencyFormatter),
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          company: structureData.company,
          documentLabel: 'Estructura ${structureData.draftCode}',
          generatedAt: structureData.generatedAt,
          logo: logoImage,
        ),
        footer: (context) => _buildFooter(context, structureData.company),
        build: (context) => _structuralContent(structureData, font),
      ),
    );

    return document.save();
  }

  NumberFormat _quotationCurrencyFormatter() {
    return NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 2,
    );
  }

  List<pw.Widget> _quotationContent(
    QuotationPdfData data,
    NumberFormat currencyFormatter,
  ) {
    return [
      _buildTitle('Cotización de sistema fotovoltaico'),
      pw.SizedBox(height: 16),
      _buildClientSection(data.client),
      pw.SizedBox(height: 16),
      _buildSystemSection(data.system),
      pw.SizedBox(height: 16),
      _buildCommercialSection(data, currencyFormatter),
      pw.SizedBox(height: 16),
      _buildNotesSection(data),
    ];
  }

  Future<Uint8List> generateTechnicalProposalPdf(
    TechnicalProposalPdfData data,
  ) async {
    final document = pw.Document();
    final logoImage = await _loadLogo();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          company: data.company,
          documentLabel: 'Propuesta técnica ${data.draftCode}',
          generatedAt: data.generatedAt,
          logo: logoImage,
        ),
        footer: (context) => _buildFooter(context, data.company),
        build: (context) => [
          _buildTitle('Propuesta técnica y memoria de cálculo'),
          pw.SizedBox(height: 16),
          _buildClientSection(data.client),
          pw.SizedBox(height: 16),
          _buildSystemSection(data.system),
          pw.SizedBox(height: 16),
          _buildElectricalSection(data.electrical),
          if (data.structure != null) ...[
            pw.SizedBox(height: 16),
            _buildStructureSection(data.structure!),
          ],
          pw.SizedBox(height: 16),
          _sectionContainer(
            title: 'Garantías',
            child: pw.Text(
              data.warrantyNote,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Documento técnico preliminar. Validar contra normativa aplicable, '
            'condiciones reales del sitio, datasheets completos y criterio '
            'final de ingeniería antes de instalar.',
            style: const pw.TextStyle(fontSize: 8, color: _mutedColor),
          ),
        ],
      ),
    );

    return document.save();
  }

  Future<Uint8List> generateContractPdf(ContractPdfData data) async {
    final document = pw.Document();
    final logoImage = await _loadLogo();

    final paragraphs = data.contractText
        .split('\n')
        .map((line) => line.trimRight())
        .toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          company: data.company,
          documentLabel: 'Contrato ${data.draftCode}',
          generatedAt: data.generatedAt,
          logo: logoImage,
        ),
        footer: (context) => _buildFooter(context, data.company),
        build: (context) => [
          for (final line in paragraphs)
            line.isEmpty
                ? pw.SizedBox(height: 8)
                : pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      line,
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                  ),
          pw.SizedBox(height: 20),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildSignatureBlock(
                  label: 'Firma del cliente',
                  signatureBytes: data.clientSignatureBytes,
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildSignatureBlock(
                  label: 'Firma del proveedor',
                  signatureBytes: data.providerSignatureBytes,
                ),
              ),
            ],
          ),
          if (data.signedAt != null) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Firmado el ${_formatDate(data.signedAt!)}.',
              style: const pw.TextStyle(fontSize: 8, color: _mutedColor),
            ),
          ],
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _buildSignatureBlock({
    required String label,
    Uint8List? signatureBytes,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          height: 70,
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
          ),
          child: signatureBytes == null
              ? pw.Text(
                  'Pendiente',
                  style: const pw.TextStyle(fontSize: 8, color: _mutedColor),
                )
              : pw.Image(pw.MemoryImage(signatureBytes), height: 65),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  Future<Uint8List> generatePreInvoicePdf(PreInvoicePdfData data) async {
    final document = pw.Document();
    final logoImage = await _loadLogo();
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 2,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          company: data.company,
          documentLabel: 'Pre-factura ${data.folio ?? data.draftCode}',
          generatedAt: data.generatedAt,
          logo: logoImage,
        ),
        footer: (context) => _buildFooter(context, data.company),
        build: (context) => [
          _buildTitle('Pre-factura (documento interno)'),
          pw.SizedBox(height: 4),
          pw.Text(
            'Documento interno de referencia. No es un CFDI timbrado ante el '
            'SAT.',
            style: const pw.TextStyle(fontSize: 9, color: _mutedColor),
          ),
          pw.SizedBox(height: 16),
          _sectionContainer(
            title: 'Datos fiscales del cliente',
            child: pw.TableHelper.fromTextArray(
              border: null,
              cellAlignment: pw.Alignment.centerLeft,
              headerCount: 0,
              cellPadding:
                  const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
              cellStyle: const pw.TextStyle(fontSize: 9.5),
              data: [
                ['Cliente', data.clientName],
                if (data.clientLegalName != null)
                  ['Razón social', data.clientLegalName!],
                if (data.clientRfc != null) ['RFC', data.clientRfc!],
                if (data.clientFiscalRegimeLabel != null)
                  ['Régimen fiscal', data.clientFiscalRegimeLabel!],
                if (data.clientFiscalZipCode != null)
                  ['CP fiscal', data.clientFiscalZipCode!],
                if (data.cfdiUseLabel != null)
                  ['Uso CFDI', data.cfdiUseLabel!],
                ['Forma de pago', data.paymentFormLabel],
                ['Método de pago', data.paymentMethodLabel],
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          _sectionContainer(
            title: 'Importes',
            child: pw.TableHelper.fromTextArray(
              border: null,
              cellAlignment: pw.Alignment.centerLeft,
              headerCount: 0,
              cellPadding:
                  const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
              cellStyle: const pw.TextStyle(fontSize: 10),
              data: [
                ['Subtotal', currencyFormatter.format(data.subtotal)],
                ['IVA', currencyFormatter.format(data.ivaAmount)],
                ['Total', currencyFormatter.format(data.total)],
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Preparado para timbrado futuro ante un PAC (Proveedor '
            'Autorizado de Certificación). Este documento no sustituye un '
            'CFDI válido.',
            style: const pw.TextStyle(fontSize: 8, color: _mutedColor),
          ),
        ],
      ),
    );

    return document.save();
  }

  Future<Uint8List> generateStructuralPdf(StructureTechnicalPdfData data) async {
    final document = pw.Document();
    final logoImage = await _loadLogo();
    final font = PdfFont.helvetica(document.document);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          company: data.company,
          documentLabel: 'Estructura ${data.draftCode}',
          generatedAt: data.generatedAt,
          logo: logoImage,
        ),
        footer: (context) => _buildFooter(context, data.company),
        build: (context) => _structuralContent(data, font),
      ),
    );

    return document.save();
  }

  List<pw.Widget> _structuralContent(
    StructureTechnicalPdfData data,
    PdfFont font,
  ) {
    return [
      _buildTitle('Diseño técnico de estructura'),
      pw.SizedBox(height: 4),
      pw.Text(
        data.projectLabel,
        style: const pw.TextStyle(fontSize: 10, color: _mutedColor),
      ),
      pw.SizedBox(height: 16),
      _sectionContainer(
        title: 'Resumen',
        child: pw.TableHelper.fromTextArray(
          border: null,
          cellAlignment: pw.Alignment.centerLeft,
          headerCount: 0,
          cellPadding:
              const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          cellStyle: const pw.TextStyle(fontSize: 9.5),
          data: [
            ['Tipo de montaje', data.mountTypeLabel],
            ['Fijación', data.fixingTypeLabel],
            [
              'Distribución',
              '${data.result.structuresCount} estructura(s) · '
                  '${data.result.panelsHorizontal} × ${data.result.panelRows} módulos',
            ],
            [
              'Área de módulos',
              '${data.result.widthMeters.toStringAsFixed(2)} × '
                  '${data.result.inclinedDepthMeters.toStringAsFixed(2)} m',
            ],
          ],
        ),
      ),
      pw.SizedBox(height: 16),
      _sectionContainer(
        title: 'Área de módulos (planta)',
        child: pw.SizedBox(
          height: 160,
          width: double.infinity,
          child: pw.CustomPaint(
            size: const PdfPoint(500, 160),
            painter: (canvas, size) => _drawAreaPanel(
              canvas,
              size,
              data.result,
              font,
            ),
          ),
        ),
      ),
      pw.SizedBox(height: 16),
      _sectionContainer(
        title: 'Vista lateral',
        child: pw.SizedBox(
          height: 170,
          width: double.infinity,
          child: pw.CustomPaint(
            size: const PdfPoint(500, 170),
            painter: (canvas, size) => _drawSideView(
              canvas,
              size,
              data.result,
              font,
            ),
          ),
        ),
      ),
      pw.SizedBox(height: 16),
      _sectionContainer(
        title: 'Vista frontal',
        child: pw.SizedBox(
          height: 150,
          width: double.infinity,
          child: pw.CustomPaint(
            size: const PdfPoint(500, 150),
            painter: (canvas, size) => _drawFrontView(
              canvas,
              size,
              data.result,
              font,
            ),
          ),
        ),
      ),
      pw.SizedBox(height: 16),
      _sectionContainer(
        title: 'Vista trasera (rompevientos)',
        child: pw.SizedBox(
          height: 150,
          width: double.infinity,
          child: pw.CustomPaint(
            size: const PdfPoint(500, 150),
            painter: (canvas, size) => _drawRearView(
              canvas,
              size,
              data.result,
              font,
            ),
          ),
        ),
      ),
      pw.SizedBox(height: 16),
      _buildStructureMaterialsSection(data.result, data.fixingTypeLabel),
      pw.SizedBox(height: 12),
      pw.Text(
        'Diagramas y cantidades preliminares. Validar en sitio, contra '
        'normativa aplicable y criterio final de ingeniería antes de '
        'fabricar o instalar.',
        style: const pw.TextStyle(fontSize: 8, color: _mutedColor),
      ),
    ];
  }

  void _drawAreaPanel(
    PdfGraphics canvas,
    PdfPoint size,
    InclinedFlatRoofResult result,
    PdfFont font,
  ) {
    const margin = 30.0;
    final drawableWidth = size.x - margin * 2;
    final drawableHeight = size.y - margin * 2;

    final cols = result.panelsHorizontal;
    final rows = result.panelRows;
    if (cols <= 0 || rows <= 0) return;

    final scale = _min(drawableWidth / cols, drawableHeight / rows);
    final gridWidth = cols * scale;
    final gridHeight = rows * scale;
    final left = (size.x - gridWidth) / 2;
    final bottom = (size.y - gridHeight) / 2;

    canvas
      ..setStrokeColor(_brandColor)
      ..setLineWidth(0.8);

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        canvas.drawRect(
          left + col * scale,
          bottom + row * scale,
          scale * 0.94,
          scale * 0.94,
        );
      }
    }
    canvas.strokePath();

    canvas.drawString(
      font,
      8,
      '${result.widthMeters.toStringAsFixed(2)} m',
      left,
      bottom - 12,
    );
    canvas.drawString(
      font,
      8,
      '${result.inclinedDepthMeters.toStringAsFixed(2)} m',
      left + gridWidth + 4,
      bottom + gridHeight / 2,
    );
  }

  void _drawSideView(
    PdfGraphics canvas,
    PdfPoint size,
    InclinedFlatRoofResult result,
    PdfFont font,
  ) {
    const marginLeft = 40.0;
    const marginBottom = 30.0;
    const floorY = marginBottom;
    final availableHeight = size.y - marginBottom - 20;
    final depth =
        result.projectedDepthMeters <= 0 ? 1.0 : result.projectedDepthMeters;
    final rearHeight = _max(result.rearLegMeters, 0.1);
    final horizontalScale = (size.x - marginLeft - 20) / depth;
    final verticalScale = availableHeight / rearHeight;
    final scale = _min(horizontalScale, verticalScale);

    final points = <PdfPoint>[];
    for (var index = 0; index < result.supportRowCount; index++) {
      final progress = result.supportRowCount == 1
          ? 0.0
          : index / (result.supportRowCount - 1);
      final height = result.legHeightsMeters[index];
      points.add(
        PdfPoint(
          marginLeft + (depth * scale * progress),
          floorY + (height * scale),
        ),
      );
    }

    canvas
      ..setStrokeColor(PdfColors.grey600)
      ..setLineWidth(1)
      ..drawLine(marginLeft - 10, floorY, marginLeft + depth * scale + 10, floorY)
      ..strokePath();

    canvas
      ..setStrokeColor(_brandColor)
      ..setLineWidth(1.4);
    for (final point in points) {
      canvas.drawLine(point.x, floorY, point.x, point.y);
    }
    canvas.strokePath();

    if (points.length >= 2) {
      canvas
        ..setStrokeColor(_brandColor)
        ..setLineWidth(1.4)
        ..moveTo(points.first.x, points.first.y);
      for (final point in points.skip(1)) {
        canvas.lineTo(point.x, point.y);
      }
      canvas.strokePath();
    }

    for (var index = 0; index < points.length; index++) {
      final label = index == 0
          ? 'Delantera'
          : index == points.length - 1
              ? 'Trasera'
              : 'Intermedia';
      canvas.drawString(
        font,
        7,
        '$label ${result.legHeightsMeters[index].toStringAsFixed(2)} m',
        points[index].x - 20,
        floorY - 12,
      );
    }

    if (result.structuresCount > 1) {
      final totalArrayDepthMeters =
          result.projectedDepthMeters * result.structuresCount;
      canvas.drawString(
        font,
        7,
        'Distancia entre filas de estructuras: '
        '${result.projectedDepthMeters.toStringAsFixed(2)} m aprox. '
        '(${result.structuresCount} filas) · Largo total del arreglo: '
        '${totalArrayDepthMeters.toStringAsFixed(2)} m',
        marginLeft,
        size.y - 12,
      );
    }
  }

  void _drawFrontView(
    PdfGraphics canvas,
    PdfPoint size,
    InclinedFlatRoofResult result,
    PdfFont font,
  ) {
    const marginLeft = 30.0;
    const marginBottom = 30.0;
    const floorY = marginBottom;
    final width = size.x - marginLeft * 2;
    final legCount =
        result.supportPointsPerRow > 1 ? result.supportPointsPerRow : 1;
    final spacing = legCount > 1 ? width / (legCount - 1) : 0.0;
    final availableHeight = size.y - marginBottom - 20;
    final rearHeight = _max(result.rearLegMeters, 0.1);
    final scale = availableHeight / rearHeight;

    canvas
      ..setStrokeColor(PdfColors.grey600)
      ..setLineWidth(1)
      ..drawLine(marginLeft - 10, floorY, marginLeft + width + 10, floorY)
      ..strokePath();

    canvas
      ..setStrokeColor(_brandColor)
      ..setLineWidth(1.4);
    for (var index = 0; index < legCount; index++) {
      final x = marginLeft + (legCount == 1 ? width / 2 : spacing * index);
      canvas.drawLine(x, floorY, x, floorY + result.rearLegMeters * scale);
    }
    canvas.strokePath();

    canvas.drawString(
      font,
      8,
      'Patas delanteras: $legCount · separación '
      '${result.legSpacingMeters.toStringAsFixed(2)} m aprox.',
      marginLeft,
      size.y - 14,
    );
    canvas.drawString(
      font,
      8,
      'Altura pata trasera: ${result.rearLegMeters.toStringAsFixed(2)} m',
      marginLeft,
      floorY - 14,
    );
  }

  void _drawRearView(
    PdfGraphics canvas,
    PdfPoint size,
    InclinedFlatRoofResult result,
    PdfFont font,
  ) {
    const marginLeft = 30.0;
    const marginBottom = 30.0;
    const floorY = marginBottom;
    final width = size.x - marginLeft * 2;
    final availableHeight = size.y - marginBottom - 20;
    final rearHeight = _max(result.rearLegMeters, 0.1);
    final scale = availableHeight / rearHeight;

    const leftX = marginLeft;
    final rightX = marginLeft + width;
    final topLeft = PdfPoint(leftX, floorY + rearHeight * scale);
    final topRight = PdfPoint(rightX, floorY + rearHeight * scale);
    final middleX = marginLeft + width / 2;
    final middleTop = PdfPoint(middleX, floorY + result.middleLegMeters * scale);
    final middleBase = PdfPoint(middleX, floorY);

    canvas
      ..setStrokeColor(PdfColors.grey600)
      ..setLineWidth(1)
      ..drawLine(leftX - 10, floorY, rightX + 10, floorY)
      ..strokePath();

    canvas
      ..setStrokeColor(_brandColor)
      ..setLineWidth(1.4)
      ..drawLine(leftX, floorY, leftX, topLeft.y)
      ..drawLine(rightX, floorY, rightX, topRight.y)
      ..drawLine(middleX, floorY, middleX, middleTop.y)
      ..strokePath();

    // Rompevientos en "V" alternada: de la parte alta de una pata a la
    // base de la siguiente, y de esa base a la parte alta de la pata
    // posterior (ver Fase 5.21).
    canvas
      ..setStrokeColor(PdfColors.orange700)
      ..setLineWidth(1)
      ..drawLine(topLeft.x, topLeft.y, middleBase.x, middleBase.y)
      ..drawLine(middleBase.x, middleBase.y, topRight.x, topRight.y)
      ..strokePath();

    canvas.drawString(
      font,
      8,
      'Rompevientos: ${result.windBracePiecesCount} piezas de '
      '${result.windBraceLengthMeters.toStringAsFixed(2)} m',
      marginLeft,
      size.y - 14,
    );
    canvas.drawString(
      font,
      7,
      'Patas traseras: ${result.supportPointsPerRow} · separación '
      '${result.legSpacingMeters.toStringAsFixed(2)} m aprox.',
      marginLeft,
      size.y - 26,
    );
    canvas.drawString(
      font,
      8,
      'Altura pata trasera: ${result.rearLegMeters.toStringAsFixed(2)} m',
      marginLeft,
      floorY - 14,
    );
  }

  pw.Widget _buildStructureMaterialsSection(
    InclinedFlatRoofResult result,
    String fixingTypeLabel,
  ) {
    final railPlan = result.railPlan;

    return _sectionContainer(
      title: 'Materiales estimados',
      child: pw.TableHelper.fromTextArray(
        border: null,
        cellAlignment: pw.Alignment.centerLeft,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellPadding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headers: const ['Material', 'Cantidad'],
        data: [
          [
            'Riel 5 m / 6 m',
            '${railPlan.fiveMeterRails} / ${railPlan.sixMeterRails} tramos',
          ],
          ['Mid clamps', '${result.midClampCount} piezas'],
          ['End clamps', '${result.endClampCount} piezas'],
          ['Patas estructurales', '${result.totalLegCount} piezas'],
          ['Largueros', '${result.largueroPiecesCount} piezas'],
          ['Rompevientos', '${result.windBracePiecesCount} piezas'],
          [
            'Material de ángulo',
            '${result.angleSixMeterSections} tramos de 6 m',
          ],
          [fixingTypeLabel, '${result.fixingPiecesPerTypeCount} piezas'],
        ],
      ),
    );
  }

  double _min(double a, double b) => a < b ? a : b;

  double _max(double a, double b) => a > b ? a : b;

  Future<pw.MemoryImage> _loadLogo() async {
    final logoBytes = await rootBundle.load(AppAssets.macbecLogoTransparent);
    return pw.MemoryImage(logoBytes.buffer.asUint8List());
  }

  pw.Widget _buildHeader({
    required QuotationPdfCompanyInfo company,
    required String documentLabel,
    required DateTime generatedAt,
    required pw.MemoryImage logo,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(logo, width: 90),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    company.companyName,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: _brandColor,
                    ),
                  ),
                  pw.Text(
                    [
                      company.phone,
                      company.email,
                    ].where((value) => value.trim().isNotEmpty).join(' · '),
                    style: const pw.TextStyle(fontSize: 9, color: _mutedColor),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  documentLabel,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _formatDate(generatedAt),
                  style: const pw.TextStyle(fontSize: 9, color: _mutedColor),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _brandColor, thickness: 1.2),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context, QuotationPdfCompanyInfo company) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey400, thickness: 0.6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              company.address,
              style: const pw.TextStyle(fontSize: 8, color: _mutedColor),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _mutedColor),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
    );
  }

  pw.Widget _buildClientSection(QuotationPdfClientInfo client) {
    final details = [
      if (client.phone != null && client.phone!.trim().isNotEmpty)
        client.phone!.trim(),
      if (client.email != null && client.email!.trim().isNotEmpty)
        client.email!.trim(),
      if (client.address != null && client.address!.trim().isNotEmpty)
        client.address!.trim(),
    ];

    return _sectionContainer(
      title: 'Cliente',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            client.fullName,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          if (details.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              details.join(' · '),
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildSystemSection(QuotationPdfSystemSummary system) {
    return _sectionContainer(
      title: 'Resumen del sistema',
      child: pw.TableHelper.fromTextArray(
        border: null,
        cellAlignment: pw.Alignment.centerLeft,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9.5),
        headers: const ['Concepto', 'Detalle'],
        data: [
          [
            'Módulos solares',
            '${system.panelQuantity} × ${system.panelDisplayName} '
                '(${system.panelPowerWatts.toStringAsFixed(0)} W c/u)',
          ],
          [
            'Capacidad instalada',
            '${(system.totalPanelPowerWatts / 1000).toStringAsFixed(2)} kWp',
          ],
          [
            'Inversor',
            '${system.inverterQuantity} × ${system.inverterDisplayName}',
          ],
          [
            'Generación estimada diaria',
            '${system.estimatedDailyGenerationKwh.toStringAsFixed(1)} kWh/día',
          ],
          [
            'Generación estimada mensual',
            '${system.estimatedMonthlyGenerationKwh.toStringAsFixed(0)} kWh/mes',
          ],
          [
            'Generación estimada anual',
            '${system.estimatedAnnualGenerationKwh.toStringAsFixed(0)} kWh/año',
          ],
        ],
      ),
    );
  }

  pw.Widget _buildCommercialSection(
    QuotationPdfData data,
    NumberFormat currencyFormatter,
  ) {
    final commercial = data.commercial;

    final rows = <List<String>>[
      if (commercial.structureMaterialsPrice > 0)
        [
          'Estructura y materiales',
          currencyFormatter.format(commercial.structureMaterialsPrice),
        ],
      ['Subtotal', currencyFormatter.format(commercial.subtotal)],
      if (commercial.discountAmount > 0)
        [
          'Descuento',
          '-${currencyFormatter.format(commercial.discountAmount)}',
        ],
      [
        'IVA (${commercial.ivaRatePercent.toStringAsFixed(0)}%)',
        currencyFormatter.format(commercial.ivaAmount),
      ],
      ['Total', currencyFormatter.format(commercial.total)],
      if (commercial.advancePaymentAmount > 0) ...[
        [
          'Anticipo',
          currencyFormatter.format(commercial.advancePaymentAmount),
        ],
        ['Saldo restante', currencyFormatter.format(commercial.balanceDue)],
      ],
    ];

    return _sectionContainer(
      title: 'Inversión',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.TableHelper.fromTextArray(
            border: null,
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding:
                const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            headerCount: 0,
            cellStyle: const pw.TextStyle(fontSize: 10),
            data: rows,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Cotización válida por ${commercial.validityDays} días. '
            'Precios en ${commercial.currency}.',
            style: const pw.TextStyle(fontSize: 8.5, color: _mutedColor),
          ),
          if (commercial.paymentTermsNote != null &&
              commercial.paymentTermsNote!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Esquema de pagos: ${commercial.paymentTermsNote}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
          if (commercial.structureMaterialsHasMissingPrices) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'El monto de estructura y materiales es un estimado parcial: '
              'algunas partidas no tenían precio disponible en el catálogo '
              'al momento de generar esta cotización.',
              style: const pw.TextStyle(fontSize: 8.5, color: _mutedColor),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildNotesSection(QuotationPdfData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionContainer(
          title: 'Garantías',
          child: pw.Text(
            data.warrantyNote,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          data.legalNote,
          style: const pw.TextStyle(fontSize: 8, color: _mutedColor),
        ),
      ],
    );
  }

  pw.Widget _buildElectricalSection(TechnicalProposalElectricalSummary data) {
    final rows = <List<String>>[
      [
        'Voc / Isc del panel',
        '${data.panelVoc?.toStringAsFixed(2) ?? '-'} V / '
            '${data.panelIsc?.toStringAsFixed(2) ?? '-'} A',
      ],
      [
        'Paneles máx. por string',
        data.maxPanelsPerString?.toString() ?? '-',
      ],
      [
        'Paralelos máx. por MPPT',
        data.maxParallelStringsPerMppt?.toString() ?? '-',
      ],
      ['Strings requeridos', data.requiredStrings?.toString() ?? '-'],
      [
        'Uso del inversor',
        '${data.inverterUsagePercent.toStringAsFixed(1)}% '
            '(reserva ${data.reserveCapacityPercent.toStringAsFixed(1)}%)',
      ],
      if (data.dcFuseAmps != null)
        ['Fusible DC', '${data.dcFuseAmps} A'],
      if (data.dcCableAwg != null) ['Cable DC', '${data.dcCableAwg} AWG'],
      if (data.dcConduitSize != null) ['Tubería DC', data.dcConduitSize!],
      if (data.acCableAwg != null) ['Cable AC', '${data.acCableAwg} AWG'],
      if (data.acVoltageDropPercent != null)
        [
          'Caída de tensión AC',
          '${data.acVoltageDropPercent!.toStringAsFixed(2)}%',
        ],
    ];

    return _sectionContainer(
      title: 'Dimensionamiento eléctrico',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.TableHelper.fromTextArray(
            border: null,
            cellAlignment: pw.Alignment.centerLeft,
            headerCount: 0,
            cellPadding:
                const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            data: rows,
          ),
          if (data.warnings.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            for (final warning in data.warnings)
              pw.Text(
                '• $warning',
                style: const pw.TextStyle(fontSize: 8.5, color: _mutedColor),
              ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildStructureSection(TechnicalProposalStructureSummary data) {
    return _sectionContainer(
      title: 'Estructura',
      child: pw.TableHelper.fromTextArray(
        border: null,
        cellAlignment: pw.Alignment.centerLeft,
        headerCount: 0,
        cellPadding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        cellStyle: const pw.TextStyle(fontSize: 9.5),
        data: [
          ['Tipo de montaje', data.mountTypeLabel],
          ['Fijación', data.fixingTypeLabel],
          [
            'Distribución',
            '${data.structuresCount} estructura(s) · '
                '${data.panelsHorizontal} × ${data.panelRows} módulos',
          ],
          ['Patas totales', '${data.totalLegCount} piezas'],
          [
            'Área de módulos',
            '${data.areaMetersSquared.toStringAsFixed(2)} m²',
          ],
          [
            'Material de ángulo estimado',
            '${data.angleMaterialMeters.toStringAsFixed(2)} m',
          ],
        ],
      ),
    );
  }

  pw.Widget _sectionContainer({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _brandColor,
            ),
          ),
          pw.SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
