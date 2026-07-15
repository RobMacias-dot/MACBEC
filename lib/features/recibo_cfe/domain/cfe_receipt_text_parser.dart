class CfeReceiptOcrSuggestion {
  const CfeReceiptOcrSuggestion({
    this.holderName,
    this.serviceAddress,
    this.rpu,
    this.tariff,
    this.billingPeriod,
    this.currentPeriodKwh,
    this.totalToPay,
  });

  final String? holderName;
  final String? serviceAddress;
  final String? rpu;
  final String? tariff;
  final String? billingPeriod;
  final double? currentPeriodKwh;
  final double? totalToPay;

  bool get isEmpty =>
      holderName == null &&
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
      holderName: _findHolderName(lines),
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
    final index = _findAddressLineIndex(lines);
    if (index == null) return null;

    final line = lines[index].trim();
    return line.isEmpty ? null : line;
  }

  static int? _findAddressLineIndex(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final upperLine = lines[i].toUpperCase();
      if (upperLine.contains('CALLE') ||
          upperLine.contains('AV.') ||
          upperLine.contains('AVENIDA') ||
          upperLine.contains('COL.') ||
          upperLine.contains('COLONIA')) {
        return i;
      }
    }

    return null;
  }

  // Etiquetas y texto fijo típico de los recibos CFE que nunca son el
  // nombre del titular, para descartarlos de la búsqueda heurística.
  static const _holderNameBoilerplate = [
    'COMISION FEDERAL',
    'COMISIÓN FEDERAL',
    'CFE',
    'SUMINISTRADOR',
    'RECIBO',
    'RPU',
    'RMU',
    'TARIFA',
    'PERIODO',
    'PERÍODO',
    'TOTAL',
    'FACTURA',
    'SERVICIO',
    'CUENTA',
    'MEDIDOR',
    'AVISO',
    'FECHA',
    'LECTURA',
    'KWH',
    'CONSUMO',
  ];

  static String? _findHolderName(List<String> lines) {
    final labeled = RegExp(
      r'(?:Nombre\s*(?:del)?\s*(?:Titular|Usuario|Cliente)?|Titular\s*(?:del)?\s*(?:Servicio)?)\s*[:\-]\s*(.+)',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = labeled.firstMatch(line);
      final candidate = match?.group(1)?.trim();

      if (candidate != null &&
          candidate.isNotEmpty &&
          _looksLikeName(candidate)) {
        return candidate;
      }
    }

    // Sin una etiqueta explícita, el nombre suele imprimirse en una línea
    // propia justo antes de la dirección del servicio.
    final addressIndex = _findAddressLineIndex(lines);
    if (addressIndex != null) {
      for (var i = addressIndex - 1; i >= 0 && i >= addressIndex - 3; i--) {
        final candidate = lines[i].trim();
        if (_looksLikeName(candidate)) return candidate;
      }
    }

    return null;
  }

  static bool _looksLikeName(String candidate) {
    if (candidate.isEmpty || candidate.length < 4 || candidate.length > 80) {
      return false;
    }

    // Un nombre no debe contener dígitos ni símbolos de monto/etiqueta.
    if (RegExp(r'[\d\$%]').hasMatch(candidate)) return false;

    final upperCandidate = candidate.toUpperCase();
    for (final boilerplate in _holderNameBoilerplate) {
      if (upperCandidate.contains(boilerplate)) return false;
    }

    // Debe verse como al menos dos palabras (nombre + apellido).
    final words = candidate
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();

    return words.length >= 2;
  }
}
