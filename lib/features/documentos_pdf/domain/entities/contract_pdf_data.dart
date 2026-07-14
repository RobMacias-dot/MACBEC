import 'dart:typed_data';

import 'quotation_pdf_data.dart';

class ContractPdfData {
  const ContractPdfData({
    required this.draftCode,
    required this.generatedAt,
    required this.company,
    required this.contractText,
    this.clientSignatureBytes,
    this.providerSignatureBytes,
    this.signedAt,
  });

  final String draftCode;
  final DateTime generatedAt;
  final QuotationPdfCompanyInfo company;
  final String contractText;
  final Uint8List? clientSignatureBytes;
  final Uint8List? providerSignatureBytes;
  final DateTime? signedAt;
}
