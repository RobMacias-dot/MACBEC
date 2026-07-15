class QuotationCommercialQuote {
  const QuotationCommercialQuote({
    required this.id,
    required this.quotationDraftId,
    required this.versionNumber,
    required this.isCurrent,
    required this.isAccepted,
    required this.generalUtilityRatePercent,
    required this.ivaRatePercent,
    required this.discountAmount,
    required this.advancePaymentAmount,
    required this.currency,
    required this.panelUnitCost,
    required this.panelUnitPrice,
    required this.panelQuantity,
    required this.inverterUnitCost,
    required this.inverterUnitPrice,
    required this.inverterQuantity,
    required this.subtotal,
    required this.ivaAmount,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
    this.panelUtilityRatePercent,
    this.inverterUtilityRatePercent,
    this.paymentTermsNote,
    this.quotationPdfDocumentId,
    this.pdfGeneratedAt,
    this.structureMaterialsCost = 0,
    this.structureMaterialsPrice = 0,
    this.structureMaterialsHasMissingPrices = false,
  });

  final String id;
  final String quotationDraftId;
  final int versionNumber;
  final bool isCurrent;
  final bool isAccepted;

  final double generalUtilityRatePercent;
  final double? panelUtilityRatePercent;
  final double? inverterUtilityRatePercent;
  final double ivaRatePercent;
  final double discountAmount;
  final double advancePaymentAmount;
  final String currency;
  final String? paymentTermsNote;

  final double panelUnitCost;
  final double panelUnitPrice;
  final int panelQuantity;

  final double inverterUnitCost;
  final double inverterUnitPrice;
  final int inverterQuantity;

  /// Costo y precio (con utilidad aplicada) de los materiales de estructura
  /// tomados del catálogo comercial al momento de guardar esta versión
  /// (Fase 6.22 → conectado al total oficial del cliente). Si
  /// [structureMaterialsHasMissingPrices] es `true`, el monto es un
  /// estimado parcial: algunas partidas del BOM no tenían precio en el
  /// catálogo y no están incluidas.
  final double structureMaterialsCost;
  final double structureMaterialsPrice;
  final bool structureMaterialsHasMissingPrices;

  final double subtotal;
  final double ivaAmount;
  final double total;

  final String? quotationPdfDocumentId;
  final DateTime? pdfGeneratedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  double get balanceDue => total - advancePaymentAmount;

  bool get hasGeneratedPdf => quotationPdfDocumentId != null;
}

class SaveQuotationCommercialQuoteInput {
  const SaveQuotationCommercialQuoteInput({
    required this.generalUtilityRatePercent,
    required this.ivaRatePercent,
    required this.discountAmount,
    required this.advancePaymentAmount,
    required this.currency,
    required this.panelUnitCost,
    required this.panelUnitPrice,
    required this.panelQuantity,
    required this.inverterUnitCost,
    required this.inverterUnitPrice,
    required this.inverterQuantity,
    required this.subtotal,
    required this.ivaAmount,
    required this.total,
    this.panelUtilityRatePercent,
    this.inverterUtilityRatePercent,
    this.paymentTermsNote,
    this.structureMaterialsCost = 0,
    this.structureMaterialsPrice = 0,
    this.structureMaterialsHasMissingPrices = false,
  });

  final double generalUtilityRatePercent;
  final double? panelUtilityRatePercent;
  final double? inverterUtilityRatePercent;
  final double ivaRatePercent;
  final double discountAmount;
  final double advancePaymentAmount;
  final String currency;
  final String? paymentTermsNote;

  final double structureMaterialsCost;
  final double structureMaterialsPrice;
  final bool structureMaterialsHasMissingPrices;

  final double panelUnitCost;
  final double panelUnitPrice;
  final int panelQuantity;

  final double inverterUnitCost;
  final double inverterUnitPrice;
  final int inverterQuantity;

  final double subtotal;
  final double ivaAmount;
  final double total;
}
