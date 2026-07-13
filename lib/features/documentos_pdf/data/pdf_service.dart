import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_assets.dart';
import '../domain/entities/quotation_pdf_data.dart';

final pdfServiceProvider = Provider<PdfService>((ref) => PdfService());

class PdfService {
  static const _brandColor = PdfColor.fromInt(0xFF005A9C);
  static const _mutedColor = PdfColor.fromInt(0xFF5A6B76);

  Future<Uint8List> generateQuotationPdf(QuotationPdfData data) async {
    final document = pw.Document();
    final logoBytes = await rootBundle.load(AppAssets.macbecLogoTransparent);
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 2,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(data, logoImage),
        footer: (context) => _buildFooter(context, data),
        build: (context) => [
          _buildTitle(data),
          pw.SizedBox(height: 16),
          _buildClientSection(data),
          pw.SizedBox(height: 16),
          _buildSystemSection(data),
          pw.SizedBox(height: 16),
          _buildCommercialSection(data, currencyFormatter),
          pw.SizedBox(height: 16),
          _buildNotesSection(data),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _buildHeader(QuotationPdfData data, pw.MemoryImage logo) {
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
                    data.company.companyName,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: _brandColor,
                    ),
                  ),
                  pw.Text(
                    [
                      data.company.phone,
                      data.company.email,
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
                  'Cotización ${data.draftCode}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _formatDate(data.generatedAt),
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

  pw.Widget _buildFooter(pw.Context context, QuotationPdfData data) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey400, thickness: 0.6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              data.company.address,
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

  pw.Widget _buildTitle(QuotationPdfData data) {
    return pw.Text(
      'Cotización de sistema fotovoltaico',
      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
    );
  }

  pw.Widget _buildClientSection(QuotationPdfData data) {
    final client = data.client;

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

  pw.Widget _buildSystemSection(QuotationPdfData data) {
    final system = data.system;

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
