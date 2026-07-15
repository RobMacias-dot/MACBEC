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

/// Marca el último módulo del flujo de cotización que el usuario completó
/// para un borrador, de modo que la app pueda reanudarlo directo en la
/// pantalla correcta en vez de que cada pantalla adivine el estado.
class QuotationDraftStep {
  const QuotationDraftStep._();

  static const prospect = 'prospect';
  static const cfeReceipt = 'cfe_receipt';
  static const cfeReview = 'cfe_review';
  static const energyAnalysis = 'energy_analysis';
  static const technicalSelection = 'technical_selection';
  static const electricalDimensioning = 'electrical_dimensioning';
  static const structure = 'structure';
  static const commercialQuote = 'commercial_quote';
  static const clientPreview = 'client_preview';
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
    this.projectId,
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
    this.analysisPeakSunHours,
    this.analysisPanelPowerWatts,
    this.lastCompletedStep,
  });

  final String id;
  final String? draftCode;
  final String? projectId;

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

  final double? analysisPeakSunHours;
  final double? analysisPanelPowerWatts;

  final String? lastCompletedStep;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isReceiptPending => status == QuotationDraftStatus.receiptPending;

  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;
  bool get hasWhatsapp => whatsapp != null && whatsapp!.trim().isNotEmpty;
  bool get hasEmail => email != null && email!.trim().isNotEmpty;
  bool get hasAddress => address != null && address!.trim().isNotEmpty;
  bool get hasNotes => notes != null && notes!.trim().isNotEmpty;

  bool get hasCompleteCfeReview {
    return hasCfeReceipt &&
        cfeReceiptDocumentId != null &&
        cfeHolderName != null &&
        cfeHolderName!.trim().isNotEmpty &&
        cfeServiceAddress != null &&
        cfeServiceAddress!.trim().isNotEmpty &&
        rpu != null &&
        rpu!.trim().isNotEmpty &&
        cfeTariff != null &&
        cfeTariff!.trim().isNotEmpty &&
        cfeBillingPeriod != null &&
        cfeBillingPeriod!.trim().isNotEmpty &&
        cfeCurrentPeriodKwh != null &&
        cfeCurrentPeriodKwh! > 0 &&
        cfeTotalToPay != null &&
        cfeTotalToPay! > 0;
  }

  bool get hasEnergyAnalysisSettings {
    return analysisPeakSunHours != null &&
        analysisPeakSunHours! > 0 &&
        analysisPanelPowerWatts != null &&
        analysisPanelPowerWatts! > 0;
  }
}
