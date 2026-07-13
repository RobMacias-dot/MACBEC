class QuotationCommercialQuote {
  const QuotationCommercialQuote({
    required this.id,
    required this.quotationDraftId,
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
    this.quotationPdfDocumentId,
    this.pdfGeneratedAt,
  });

  final String id;
  final String quotationDraftId;

  final double generalUtilityRatePercent;
  final double ivaRatePercent;
  final double discountAmount;
  final double advancePaymentAmount;
  final String currency;

  final double panelUnitCost;
  final double panelUnitPrice;
  final int panelQuantity;

  final double inverterUnitCost;
  final double inverterUnitPrice;
  final int inverterQuantity;

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
  });

  final double generalUtilityRatePercent;
  final double ivaRatePercent;
  final double discountAmount;
  final double advancePaymentAmount;
  final String currency;

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
