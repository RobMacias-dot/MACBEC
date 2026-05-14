class QuotationDraftConsumption {
  const QuotationDraftConsumption({
    required this.id,
    required this.quotationDraftId,
    required this.kwh,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.periodLabel,
    this.amount,
  });

  final String id;
  final String quotationDraftId;
  final String? periodLabel;
  final double kwh;
  final double? amount;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SaveQuotationDraftConsumptionInput {
  const SaveQuotationDraftConsumptionInput({
    required this.periodLabel,
    required this.kwh,
    required this.sortOrder,
    this.amount,
  });

  final String? periodLabel;
  final double kwh;
  final double? amount;
  final int sortOrder;
}
