class QuotationPdfCompanyInfo {
  const QuotationPdfCompanyInfo({
    required this.companyName,
    required this.phone,
    required this.email,
    required this.address,
  });

  final String companyName;
  final String phone;
  final String email;
  final String address;
}

class QuotationPdfClientInfo {
  const QuotationPdfClientInfo({
    required this.fullName,
    this.phone,
    this.email,
    this.address,
  });

  final String fullName;
  final String? phone;
  final String? email;
  final String? address;
}

class QuotationPdfSystemSummary {
  const QuotationPdfSystemSummary({
    required this.panelDisplayName,
    required this.panelPowerWatts,
    required this.panelQuantity,
    required this.totalPanelPowerWatts,
    required this.inverterDisplayName,
    required this.inverterQuantity,
    required this.estimatedDailyGenerationKwh,
    required this.estimatedMonthlyGenerationKwh,
    required this.estimatedAnnualGenerationKwh,
  });

  final String panelDisplayName;
  final double panelPowerWatts;
  final int panelQuantity;
  final double totalPanelPowerWatts;
  final String inverterDisplayName;
  final int inverterQuantity;
  final double estimatedDailyGenerationKwh;
  final double estimatedMonthlyGenerationKwh;
  final double estimatedAnnualGenerationKwh;
}

class QuotationPdfCommercialSummary {
  const QuotationPdfCommercialSummary({
    required this.currency,
    required this.subtotal,
    required this.ivaRatePercent,
    required this.ivaAmount,
    required this.discountAmount,
    required this.advancePaymentAmount,
    required this.total,
    required this.validityDays,
    this.paymentTermsNote,
    this.structureMaterialsPrice = 0,
    this.structureMaterialsHasMissingPrices = false,
  });

  final String currency;
  final double subtotal;
  final double ivaRatePercent;
  final double ivaAmount;
  final double discountAmount;
  final double advancePaymentAmount;
  final double total;
  final int validityDays;
  final String? paymentTermsNote;

  /// Monto de estructura/materiales ya incluido en [subtotal] (Fase 6.22).
  final double structureMaterialsPrice;

  /// `true` si al guardar la cotización había partidas de estructura sin
  /// precio en el catálogo: el monto de estructura es un estimado parcial.
  final bool structureMaterialsHasMissingPrices;

  double get balanceDue => total - advancePaymentAmount;
}

class QuotationPdfData {
  const QuotationPdfData({
    required this.draftCode,
    required this.generatedAt,
    required this.company,
    required this.client,
    required this.system,
    required this.commercial,
    required this.warrantyNote,
    required this.legalNote,
  });

  final String draftCode;
  final DateTime generatedAt;
  final QuotationPdfCompanyInfo company;
  final QuotationPdfClientInfo client;
  final QuotationPdfSystemSummary system;
  final QuotationPdfCommercialSummary commercial;
  final String warrantyNote;
  final String legalNote;
}
