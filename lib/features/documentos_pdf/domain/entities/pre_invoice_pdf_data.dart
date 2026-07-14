import 'quotation_pdf_data.dart';

class PreInvoicePdfData {
  const PreInvoicePdfData({
    required this.draftCode,
    required this.generatedAt,
    required this.company,
    required this.clientName,
    required this.paymentFormLabel,
    required this.paymentMethodLabel,
    required this.currency,
    required this.subtotal,
    required this.ivaAmount,
    required this.total,
    this.clientRfc,
    this.clientLegalName,
    this.clientFiscalRegimeLabel,
    this.clientFiscalZipCode,
    this.cfdiUseLabel,
    this.folio,
  });

  final String draftCode;
  final DateTime generatedAt;
  final QuotationPdfCompanyInfo company;
  final String clientName;
  final String? clientRfc;
  final String? clientLegalName;
  final String? clientFiscalRegimeLabel;
  final String? clientFiscalZipCode;
  final String? cfdiUseLabel;
  final String paymentFormLabel;
  final String paymentMethodLabel;
  final String currency;
  final double subtotal;
  final double ivaAmount;
  final double total;
  final String? folio;
}
