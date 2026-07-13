import 'package:flutter_test/flutter_test.dart';
import 'package:macbec_solar_app/features/recibo_cfe/domain/cfe_receipt_text_parser.dart';

void main() {
  test('detecta RPU, tarifa, periodo, kWh y total de un recibo típico', () {
    const rawText = '''
COMISION FEDERAL DE ELECTRICIDAD
CALLE MIGUEL HIDALGO 123 COL. CENTRO
RMU 123456789012
Tarifa: 1B
Periodo: 13 MAR 25 - 14 MAY 25
Consumo: 385 kWh
Total a pagar \$1,250.50
''';

    final suggestion = CfeReceiptTextParser.parse(rawText);

    expect(suggestion.rpu, equals('123456789012'));
    expect(suggestion.tariff, equals('1B'));
    expect(suggestion.billingPeriod, equals('13 MAR 25 - 14 MAY 25'));
    expect(suggestion.currentPeriodKwh, equals(385));
    expect(suggestion.totalToPay, equals(1250.50));
    expect(suggestion.serviceAddress, contains('CALLE'));
  });

  test('devuelve isEmpty cuando no reconoce ningún dato', () {
    final suggestion = CfeReceiptTextParser.parse('texto sin datos útiles');

    expect(suggestion.isEmpty, isTrue);
  });

  test('reconoce tarifa DAC', () {
    final suggestion = CfeReceiptTextParser.parse('Tarifa aplicable: DAC');

    expect(suggestion.tariff, equals('DAC'));
  });
}
