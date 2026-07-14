class ContractStatus {
  const ContractStatus._();

  static const draft = 'draft';
  static const signed = 'signed';
}

class Contract {
  const Contract({
    required this.id,
    required this.quotationDraftId,
    required this.contractText,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.clientSignatureDocumentId,
    this.providerSignatureDocumentId,
    this.contractPdfDocumentId,
    this.signedAt,
  });

  final String id;
  final String quotationDraftId;
  final String contractText;
  final String status;
  final String? clientSignatureDocumentId;
  final String? providerSignatureDocumentId;
  final String? contractPdfDocumentId;
  final DateTime? signedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasClientSignature => clientSignatureDocumentId != null;
  bool get hasProviderSignature => providerSignatureDocumentId != null;
  bool get hasBothSignatures => hasClientSignature && hasProviderSignature;
  bool get isSigned => status == ContractStatus.signed;
}
