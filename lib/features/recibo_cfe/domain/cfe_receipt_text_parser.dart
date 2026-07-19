class CfeReceiptOcrSuggestion {
  const CfeReceiptOcrSuggestion({
    this.holderName,
    this.serviceAddress,
    this.rpu,
    this.tariff,
    this.billingPeriod,
    this.currentPeriodKwh,
    this.totalToPay,
    this.historicalPeriods = const [],
  });

  final String? holderName;
  final String? serviceAddress;
  final String? rpu;
  final String? tariff;
  final String? billingPeriod;
  final double? currentPeriodKwh;
  final double? totalToPay;

  /// Periodos de la tabla "Consumo histórico" (reverso del recibo CFE), del
  /// más reciente al más antiguo. Sirve para precargar varios periodos de
  /// consumo reales en el análisis energético en vez de solo el actual.
  final List<CfeHistoricalPeriodSuggestion> historicalPeriods;

  bool get isEmpty =>
      holderName == null &&
      serviceAddress == null &&
      rpu == null &&
      tariff == null &&
      billingPeriod == null &&
      currentPeriodKwh == null &&
      totalToPay == null &&
      historicalPeriods.isEmpty;
}

class CfeHistoricalPeriodSuggestion {
  const CfeHistoricalPeriodSuggestion({
    required this.periodLabel,
    required this.kwh,
  });

  final String periodLabel;
  final double kwh;
}

/// Nombre y dirección reconstruidos a partir del bloque de datos del
/// cliente (las líneas antes de la etiqueta "NO. DE SERVICIO"), para
/// recibos que no traen "Titular:" ni palabras clave de dirección propias.
class _ClientInfoBlock {
  const _ClientInfoBlock({required this.holderName, required this.addressLines});

  final String? holderName;
  final List<String> addressLines;
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
      historicalPeriods: _findHistoricalPeriods(normalized),
    );
  }

  // Confusiones típicas del OCR de ML Kit entre letras y dígitos impresos.
  // Solo se aplica sobre fragmentos ya identificados como numéricos por una
  // regex (RPU, kWh, total), nunca sobre texto libre como nombres.
  static const _digitConfusionMap = {
    'O': '0',
    'o': '0',
    'I': '1',
    'i': '1',
    'L': '1',
    'l': '1',
    'S': '5',
    's': '5',
    'B': '8',
  };

  static String _normalizeOcrDigits(String token) {
    final buffer = StringBuffer();
    for (final rune in token.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_digitConfusionMap[char] ?? char);
    }
    return buffer.toString();
  }

  // Un token capturado con el set de confusión (letras+dígitos) solo se
  // acepta como número real si ya traía al menos un dígito de verdad; si no,
  // es casi seguro una palabra cualquiera que terminó calzando el patrón
  // (ej. la "o" final de "Periodo" antes de un salto de línea).
  static bool _hasRealDigit(String token) => RegExp(r'\d').hasMatch(token);

  static String? _findRpu(String text) {
    final labeled = RegExp(
      r'(?:RMU|RPU|No\.?\s*de\s*Servicio|Servicio)[\s\S]{0,20}?([0-9OoIiLlSsB]{8,15})',
      caseSensitive: false,
    ).firstMatch(text);

    if (labeled != null && _hasRealDigit(labeled.group(1)!)) {
      final normalized = _normalizeOcrDigits(labeled.group(1)!);
      if (RegExp(r'^\d{8,15}$').hasMatch(normalized)) return normalized;
    }

    // Respaldo contextual: dígitos cerca de una palabra de contexto, para
    // cuando la etiqueta y el número no quedaron pegados por el OCR.
    final nearContext = RegExp(
      r'(?:RMU|RPU|SERVICIO|CUENTA)[\s\S]{0,60}?(\d{8,15})',
      caseSensitive: false,
    ).firstMatch(text);

    if (nearContext != null) return nearContext.group(1);

    // Último respaldo, sin contexto: la racha de dígitos más larga dentro
    // del rango típico de un RPU/RMU (10-12 dígitos), para no confundirlo
    // con un código de barras u otro número largo no relacionado.
    final digitRuns = RegExp(r'\d{10,12}')
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();

    if (digitRuns.isEmpty) return null;

    digitRuns.sort((a, b) => b.length.compareTo(a.length));
    return digitRuns.first;
  }

  static String? _findTariff(String text) {
    // La lista fija de abajo no cubre tarifas domésticas simples como "01"
    // o "1" (formato usado en muchos recibos residenciales reales), así que
    // primero se intenta leer directamente lo que sigue a la etiqueta
    // "Tarifa" (con o sin "aplicable" de por medio).
    final labeled = RegExp(
      r'TARIFA\s*(?:APLICABLE)?\s*[:\-]?\s*([A-Z0-9]{1,6})\b',
      caseSensitive: false,
    ).firstMatch(text);

    if (labeled != null) return labeled.group(1)!.toUpperCase();

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

  // Filas de la tabla "Consumo histórico" del reverso del recibo CFE, con
  // forma "del D MES AA al D MES AA | kWh | Importe | Pagos". Se listan del
  // periodo más reciente al más antiguo, que es como CFE las imprime.
  static List<CfeHistoricalPeriodSuggestion> _findHistoricalPeriods(
    String text,
  ) {
    const months = 'ENE|FEB|MAR|ABR|MAY|JUN|JUL|AGO|SEP|OCT|NOV|DIC';
    const datePattern = r'\d{1,2}\s*(?:' + months + r')\.?\s*\d{2,4}';

    final rowPattern = RegExp(
      'del\\s+($datePattern)\\s*al\\.?\\s*($datePattern)'
      r'[\s\S]{0,12}?(\d{1,4})(?:\.\d+)?\b',
      caseSensitive: false,
    );

    final periods = <CfeHistoricalPeriodSuggestion>[];

    for (final match in rowPattern.allMatches(text)) {
      final kwh = double.tryParse(match.group(3)!);
      if (kwh == null || kwh <= 0) continue;

      final from = match.group(1)!.trim().toUpperCase();
      final to = match.group(2)!.trim().toUpperCase();
      periods.add(
        CfeHistoricalPeriodSuggestion(periodLabel: '$from - $to', kwh: kwh),
      );
    }

    return periods;
  }

  static double? _findKwh(String text) {
    // Formato tabular estándar de CFE: la fila "Energía (kWh)" trae, en
    // orden, lectura actual, lectura anterior y consumo del periodo. Esto es
    // más confiable que buscar un número pegado a "kWh": en la tabla el
    // consumo real casi nunca queda junto a esas letras, mientras que sí
    // puede haber un "NNN kWh" suelto en texto informativo o en el consumo
    // histórico de otros periodos que no es el que queremos.
    final energyRow = RegExp(
      r'ENERG[IÍ]A\s*\(?\s*K\s*W\s*H\s*\)?'
      r'[\s\S]{0,20}?(\d{1,6})'
      r'[\s\S]{0,20}?(\d{1,6})'
      r'[\s\S]{0,20}?(\d{1,6})',
      caseSensitive: false,
    ).firstMatch(text);

    if (energyRow != null) {
      final total = double.tryParse(energyRow.group(3)!);
      if (total != null) return total;
    }

    // Anclado a "Consumo" (ej. "Consumo del periodo", "Consumo total"), para
    // no confundir el consumo real con una lectura anterior u otro número
    // seguido de "kWh" en una tabla histórica.
    final anchored = RegExp(
      r'CONSUMO[\s\S]{0,25}?([\d,OoIiLlSsB]+(?:\.\d+)?)\s*k\s*w\s*h',
      caseSensitive: false,
    ).firstMatch(text);

    if (anchored != null && _hasRealDigit(anchored.group(1)!)) {
      final normalized =
          _normalizeOcrDigits(anchored.group(1)!).replaceAll(',', '');
      final value = double.tryParse(normalized);
      if (value != null) return value;
    }

    final match = RegExp(
      r'([\d,]+(?:\.\d+)?)\s*k\s*w\s*h',
      caseSensitive: false,
    ).firstMatch(text);

    if (match == null) return null;

    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  static double? _findTotalToPay(String text) {
    // Prioridad 1: el recuadro "TOTAL A PAGAR" del encabezado del recibo es
    // la etiqueta más específica e inequívoca, así que se prueba primero y a
    // diferencia de las demás acepta montos sin centavos: varios recibos
    // (formato residencial simple) lo imprimen como entero, ej. "$453" en
    // vez de "$453.00".
    final totalAPagar = RegExp(
      r'TOTAL\s*A\s*PAGAR\D{0,10}\$?\s*([\d,OoIiLlSsB]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);

    if (totalAPagar != null && _hasRealDigit(totalAPagar.group(1)!)) {
      final normalized =
          _normalizeOcrDigits(totalAPagar.group(1)!).replaceAll(',', '');
      final value = double.tryParse(normalized);
      if (value != null) return value;
    }

    // "\bTotal\b" (sin más palabras) cubre el formato de tabla "Desglose del
    // importe a pagar" donde la fila simplemente dice "Total" seguido del
    // importe en la siguiente línea. El límite de palabra evita que
    // "Subtotal" (que contiene "total") dispare este mismo patrón. Aquí sí
    // se exigen centavos porque es un patrón más laxo (una sola palabra) y
    // sin eso aumenta el riesgo de enganchar un número que no es el total.
    final labeled = RegExp(
      r'(?:Importe\s*Total|Total\s*del\s*Recibo|A\s*Pagar|\bTotal\b)'
      r'\D{0,10}\$?\s*([\d,OoIiLlSsB]+\.\d{2})',
      caseSensitive: false,
    ).firstMatch(text);

    if (labeled != null && _hasRealDigit(labeled.group(1)!)) {
      final normalized =
          _normalizeOcrDigits(labeled.group(1)!).replaceAll(',', '');
      final value = double.tryParse(normalized);
      if (value != null) return value;
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
    if (index != null) {
      final line = lines[index].trim();
      if (line.isNotEmpty) return line;
    }

    // Respaldo estructural: muchos recibos residenciales imprimen la
    // dirección sin ninguna de las palabras clave de arriba (sin "CALLE",
    // "AV." ni "COL." — solo nombre de fraccionamiento y C.P.), así que se
    // reconstruye a partir del bloque de datos del cliente delimitado por
    // "NO. DE SERVICIO".
    final block = _findClientInfoBlock(lines);
    if (block == null || block.addressLines.isEmpty) return null;
    return block.addressLines.join(', ');
  }

  // "Av. Paseo de la Reforma 164, Col. Juárez" es el domicilio fiscal fijo
  // de CFE que aparece impreso en todos los recibos (encabezado corporativo,
  // no la dirección del cliente); se excluye para no confundirlo con la
  // dirección real del servicio.
  static const _addressBoilerplateExclusions = ['PASEO DE LA REFORMA'];

  static int? _findAddressLineIndex(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final upperLine = lines[i].toUpperCase();

      final isBoilerplate = _addressBoilerplateExclusions
          .any((phrase) => upperLine.contains(phrase));
      if (isBoilerplate) continue;

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

    // Respaldo estructural: la mayoría de los recibos no traen una etiqueta
    // "Titular:" explícita, solo el nombre impreso en su propia línea dentro
    // del bloque de datos del cliente (antes de "NO. DE SERVICIO").
    final block = _findClientInfoBlock(lines);
    if (block?.holderName != null) return block!.holderName;

    // Último respaldo (recibos sin bloque "NO. DE SERVICIO" reconocible
    // pero con una dirección detectada por palabra clave): el nombre suele
    // imprimirse en una línea propia justo antes de la dirección.
    final addressIndex = _findAddressLineIndex(lines);
    if (addressIndex != null) {
      for (var i = addressIndex - 1; i >= 0 && i >= addressIndex - 3; i--) {
        final candidate = lines[i].trim();
        if (_looksLikeName(candidate)) return candidate;
      }
    }

    return null;
  }

  // Frases fijas adicionales (encabezado corporativo y recuadro de pago)
  // que pueden interponerse entre el nombre y la dirección del cliente
  // cuando el OCR intercala el texto de la columna derecha del recibo.
  static const _clientBlockBoilerplateExtra = [
    'PASEO DE LA REFORMA',
    'ALCALDIA',
    'ALCALDÍA',
    'CODIGO POSTAL',
    'CÓDIGO POSTAL',
    'CIUDAD DE MEXICO',
    'CIUDAD DE MÉXICO',
    'RFC',
    'DESCARGA',
    'APP AUTORIZADA',
    'PESOS',
    'M.N.',
  ];

  static bool _isClientBlockBoilerplate(String line) {
    if (line.isEmpty) return true;
    if (line.contains(r'$')) return true;

    final upperLine = line.toUpperCase();
    for (final phrase in _holderNameBoilerplate) {
      if (upperLine.contains(phrase)) return true;
    }
    for (final phrase in _clientBlockBoilerplateExtra) {
      if (upperLine.contains(phrase)) return true;
    }

    return false;
  }

  // Marca el final del bloque de datos del cliente (nombre + dirección):
  // la etiqueta "NO. DE SERVICIO" (o, en su defecto, "RMU"/"CUENTA") es la
  // más consistente entre formatos de recibo CFE, incluso cuando el nombre
  // y la dirección no traen ninguna etiqueta propia.
  static int? _findServiceBlockIndex(List<String> lines) {
    final labelPattern = RegExp(
      r'N[O0o]?\.?\s*DE\s*SERVICIO|^RMU\b|^CUENTA\b',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      if (labelPattern.hasMatch(lines[i])) return i;
    }

    return null;
  }

  static _ClientInfoBlock? _findClientInfoBlock(List<String> lines) {
    final serviceIndex = _findServiceBlockIndex(lines);
    if (serviceIndex == null || serviceIndex == 0) return null;

    final candidates = <String>[];
    for (var i = 0; i < serviceIndex; i++) {
      final line = lines[i].trim();
      if (_isClientBlockBoilerplate(line)) continue;
      candidates.add(line);
    }

    if (candidates.isEmpty) return null;

    String? holderName;
    final addressLines = <String>[];
    for (final candidate in candidates) {
      if (holderName == null && _looksLikeName(candidate)) {
        holderName = candidate;
      } else {
        addressLines.add(candidate);
      }
    }

    return _ClientInfoBlock(holderName: holderName, addressLines: addressLines);
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
