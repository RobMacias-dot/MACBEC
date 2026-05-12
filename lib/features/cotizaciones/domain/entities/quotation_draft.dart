class QuotationDraftStatus {
  const QuotationDraftStatus._();

  static const receiptPending = 'receipt_pending';
  static const receiptReceived = 'receipt_received';
  static const inAnalysis = 'in_analysis';
  static const quotationInProgress = 'quotation_in_progress';
  static const quotationSent = 'quotation_sent';
  static const accepted = 'accepted';
  static const cancelled = 'cancelled';
}

class QuotationDraft {
  const QuotationDraft({
    required this.id,
    required this.prospectName,
    required this.status,
    required this.hasCfeReceipt,
    required this.createdAt,
    required this.updatedAt,
    this.draftCode,
    this.phone,
    this.whatsapp,
    this.email,
    this.address,
    this.notes,
    this.cfeReceiptDocumentId,
    this.cfeHolderName,
    this.cfeServiceAddress,
    this.rpu,
    this.cfeTariff,
    this.cfeBillingPeriod,
    this.cfeCurrentPeriodKwh,
    this.cfeTotalToPay,
  });

  final String id;
  final String? draftCode;

  final String prospectName;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? notes;

  final String status;
  final bool hasCfeReceipt;

  final String? cfeReceiptDocumentId;
  final String? cfeHolderName;
  final String? cfeServiceAddress;
  final String? rpu;
  final String? cfeTariff;
  final String? cfeBillingPeriod;
  final double? cfeCurrentPeriodKwh;
  final double? cfeTotalToPay;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isReceiptPending => status == QuotationDraftStatus.receiptPending;

  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;
  bool get hasWhatsapp => whatsapp != null && whatsapp!.trim().isNotEmpty;
  bool get hasEmail => email != null && email!.trim().isNotEmpty;
  bool get hasAddress => address != null && address!.trim().isNotEmpty;
  bool get hasNotes => notes != null && notes!.trim().isNotEmpty;
}
