class PreInvoice {
  const PreInvoice({
    required this.id,
    required this.quotationDraftId,
    required this.paymentForm,
    required this.paymentMethod,
    required this.subtotal,
    required this.ivaAmount,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
    this.clientRfc,
    this.clientLegalName,
    this.clientFiscalRegime,
    this.clientFiscalZipCode,
    this.cfdiUse,
    this.folio,
    this.pdfDocumentId,
    this.generatedAt,
  });

  final String id;
  final String quotationDraftId;
  final String? clientRfc;
  final String? clientLegalName;
  final String? clientFiscalRegime;
  final String? clientFiscalZipCode;
  final String? cfdiUse;
  final String paymentForm;
  final String paymentMethod;
  final double subtotal;
  final double ivaAmount;
  final double total;
  final String? folio;
  final String? pdfDocumentId;
  final DateTime? generatedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasGeneratedPdf => pdfDocumentId != null;
}

class SavePreInvoiceInput {
  const SavePreInvoiceInput({
    required this.paymentForm,
    required this.paymentMethod,
    required this.subtotal,
    required this.ivaAmount,
    required this.total,
    this.clientRfc,
    this.clientLegalName,
    this.clientFiscalRegime,
    this.clientFiscalZipCode,
    this.cfdiUse,
    this.folio,
  });

  final String? clientRfc;
  final String? clientLegalName;
  final String? clientFiscalRegime;
  final String? clientFiscalZipCode;
  final String? cfdiUse;
  final String paymentForm;
  final String paymentMethod;
  final double subtotal;
  final double ivaAmount;
  final double total;
  final String? folio;
}
