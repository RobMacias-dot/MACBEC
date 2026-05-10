class CommercialSettings {
  const CommercialSettings({
    required this.ivaRatePercent,
    required this.generalUtilityRatePercent,
    required this.currency,
    required this.defaultQuotationValidityDays,
    required this.quotationLegalNote,
    required this.warrantyNote,
  });

  const CommercialSettings.defaults()
      : ivaRatePercent = 16,
        generalUtilityRatePercent = 30,
        currency = 'MXN',
        defaultQuotationValidityDays = 15,
        quotationLegalNote =
            'La presente cotización está sujeta a revisión técnica, disponibilidad de equipos y condiciones del sitio.',
        warrantyNote =
            'Garantías sujetas a las condiciones del fabricante y a la correcta instalación del sistema.';

  final double ivaRatePercent;
  final double generalUtilityRatePercent;
  final String currency;
  final int defaultQuotationValidityDays;
  final String quotationLegalNote;
  final String warrantyNote;

  CommercialSettings copyWith({
    double? ivaRatePercent,
    double? generalUtilityRatePercent,
    String? currency,
    int? defaultQuotationValidityDays,
    String? quotationLegalNote,
    String? warrantyNote,
  }) {
    return CommercialSettings(
      ivaRatePercent: ivaRatePercent ?? this.ivaRatePercent,
      generalUtilityRatePercent:
          generalUtilityRatePercent ?? this.generalUtilityRatePercent,
      currency: currency ?? this.currency,
      defaultQuotationValidityDays:
          defaultQuotationValidityDays ?? this.defaultQuotationValidityDays,
      quotationLegalNote: quotationLegalNote ?? this.quotationLegalNote,
      warrantyNote: warrantyNote ?? this.warrantyNote,
    );
  }
}
