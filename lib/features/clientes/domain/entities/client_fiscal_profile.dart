class ClientFiscalProfile {
  const ClientFiscalProfile({
    required this.clientId,
    this.rfc,
    this.legalName,
    this.fiscalRegime,
    this.fiscalZipCode,
    this.cfdiUse,
    this.invoiceEmail,
  });

  final String clientId;
  final String? rfc;
  final String? legalName;
  final String? fiscalRegime;
  final String? fiscalZipCode;
  final String? cfdiUse;
  final String? invoiceEmail;

  bool get hasData =>
      (rfc != null && rfc!.trim().isNotEmpty) ||
      (legalName != null && legalName!.trim().isNotEmpty);

  bool get isComplete =>
      _hasText(rfc) &&
      _hasText(legalName) &&
      _hasText(fiscalRegime) &&
      _hasText(fiscalZipCode) &&
      _hasText(cfdiUse);

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}

class SaveClientFiscalProfileInput {
  const SaveClientFiscalProfileInput({
    this.rfc,
    this.legalName,
    this.fiscalRegime,
    this.fiscalZipCode,
    this.cfdiUse,
    this.invoiceEmail,
  });

  final String? rfc;
  final String? legalName;
  final String? fiscalRegime;
  final String? fiscalZipCode;
  final String? cfdiUse;
  final String? invoiceEmail;
}
