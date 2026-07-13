class CfeReceiptOcrSuggestion {
  const CfeReceiptOcrSuggestion({
    this.serviceAddress,
    this.rpu,
    this.tariff,
    this.billingPeriod,
    this.currentPeriodKwh,
    this.totalToPay,
  });

  final String? serviceAddress;
  final String? rpu;
  final String? tariff;
  final String? billingPeriod;
  final double? currentPeriodKwh;
  final double? totalToPay;

  bool get isEmpty =>
      serviceAddress == null &&
      rpu == null &&
      tariff == null &&
      billingPeriod == null &&
      currentPeriodKwh == null &&
      totalToPay == null;
}

/// Heurísticas simples para sugerir datos del recibo CFE a partir del texto
/// crudo de OCR. Los recibos varían mucho de formato, así que esto es solo
/// una sugerencia editable: el usuario siempre debe revisar y confirmar cada
/// campo en la pantalla de revisión antes de guardar (regla permanente del
/// proyecto: OCR nunca alimenta cálculos sin validación humana).
class CfeReceiptTextParser {
  const CfeReceiptTextParser._();

  static const _knownTariffs = [
    'PDBT',
    'GDMTH',
    'GDMTO',
    'GDBT',
    'DAC',
    'RAP',
    'APBT',
    'APMT',
    '1F',
    '1E',
    '1D',
    '1C',
    '1B',
    '1A',
  ];

  static CfeReceiptOcrSuggestion parse(String rawText) {
    final normalized = rawText.replaceAll('\r', '');
    final lines = normalized.split('\n').map((line) => line.trim()).toList();

    return CfeReceiptOcrSuggestion(
      serviceAddress: _findAddress(lines),
      rpu: _findRpu(normalized),
      tariff: _findTariff(normalized),
      billingPeriod: _findBillingPeriod(normalized),
      currentPeriodKwh: _findKwh(normalized),
      totalToPay: _findTotalToPay(normalized),
    );
  }

  static String? _findRpu(String text) {
    final labeled = RegExp(
      r'(?:RMU|RPU|No\.?\s*de\s*Servicio|Servicio)\D{0,10}(\d{8,15})',
      caseSensitive: false,
    ).firstMatch(text);

    if (labeled != null) return labeled.group(1);

    final longestDigitRun = RegExp(r'\d{8,15}')
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();

    if (longestDigitRun.isEmpty) return null;

    longestDigitRun.sort((a, b) => b.length.compareTo(a.length));
    return longestDigitRun.first;
  }

  static String? _findTariff(String text) {
    final upperText = text.toUpperCase();

    for (final tariff in _knownTariffs) {
      final match = RegExp(r'\b' + tariff + r'\b').firstMatch(upperText);
      if (match != null) return tariff;
    }

    return null;
  }

  static String? _findBillingPeriod(String text) {
    const months = 'ENE|FEB|MAR|ABR|MAY|JUN|JUL|AGO|SEP|OCT|NOV|DIC';
    const datePattern = r'\d{1,2}\s*(?:' + months + r')\.?\s*\d{2,4}';

    final rangeMatch = RegExp(
      '($datePattern)\\s*(?:al?|-|a)\\s*($datePattern)',
      caseSensitive: false,
    ).firstMatch(text.toUpperCase());

    if (rangeMatch == null) return null;

    return '${rangeMatch.group(1)?.trim()} - ${rangeMatch.group(2)?.trim()}';
  }

  static double? _findKwh(String text) {
    final match = RegExp(
      r'([\d,]+(?:\.\d+)?)\s*k\s*w\s*h',
      caseSensitive: false,
    ).firstMatch(text);

    if (match == null) return null;

    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  static double? _findTotalToPay(String text) {
    final labeled = RegExp(
      r'Total\s*a?\s*Pagar\D{0,10}\$?\s*([\d,]+\.\d{2})',
      caseSensitive: false,
    ).firstMatch(text);

    if (labeled != null) {
      return double.tryParse(labeled.group(1)!.replaceAll(',', ''));
    }

    final amounts = RegExp(r'\$\s*([\d,]+\.\d{2})')
        .allMatches(text)
        .map((match) => double.tryParse(match.group(1)!.replaceAll(',', '')))
        .whereType<double>()
        .toList();

    if (amounts.isEmpty) return null;

    amounts.sort();
    return amounts.last;
  }

  static String? _findAddress(List<String> lines) {
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      if (upperLine.contains('CALLE') ||
          upperLine.contains('AV.') ||
          upperLine.contains('AVENIDA') ||
          upperLine.contains('COL.') ||
          upperLine.contains('COLONIA')) {
        return line.trim().isEmpty ? null : line.trim();
      }
    }

    return null;
  }
}
