class DocumentTypes {
  const DocumentTypes._();

  static const cfeReceipt = 'cfe_receipt';
  static const quotationPdf = 'quotation_pdf';
  static const technicalProposalPdf = 'technical_proposal_pdf';
  static const structuralPdf = 'structural_pdf';
  static const clientSignature = 'client_signature';
  static const providerSignature = 'provider_signature';
  static const contractPdf = 'contract_pdf';
  static const preInvoicePdf = 'pre_invoice_pdf';
  static const photo = 'photo';
  static const other = 'other';

  static String label(String documentType) {
    switch (documentType) {
      case cfeReceipt:
        return 'Recibo CFE';
      case quotationPdf:
        return 'Cotización (PDF)';
      case technicalProposalPdf:
        return 'Propuesta técnica (PDF)';
      case structuralPdf:
        return 'Estructura técnica (PDF)';
      case clientSignature:
        return 'Firma del cliente';
      case providerSignature:
        return 'Firma del proveedor';
      case contractPdf:
        return 'Contrato firmado (PDF)';
      case preInvoicePdf:
        return 'Pre-factura (PDF)';
      case photo:
        return 'Foto';
      default:
        return documentType;
    }
  }
}

class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.documentType,
    required this.localPath,
    required this.fileName,
    required this.createdAt,
    this.quotationDraftId,
    this.mimeType,
    this.sizeBytes,
  });

  final String id;
  final String? quotationDraftId;
  final String documentType;
  final String localPath;
  final String fileName;
  final String? mimeType;
  final int? sizeBytes;
  final DateTime createdAt;

  String get typeLabel => DocumentTypes.label(documentType);
}
