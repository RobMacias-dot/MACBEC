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

  test(
      'extrae el kWh del "Consumo del periodo" y no una lectura anterior '
      'con kWh que aparece antes en el texto', () {
    const rawText = '''
Lectura anterior 120 kWh
Consumo del periodo: 385 kWh
''';

    final suggestion = CfeReceiptTextParser.parse(rawText);

    expect(suggestion.currentPeriodKwh, equals(385));
  });

  test(
      'extrae el RPU correcto cuando hay también un número de teléfono '
      'de 10 dígitos en el recibo', () {
    const rawText = '''
Tel. de contacto 5512345678
RPU 987654321098
''';

    final suggestion = CfeReceiptTextParser.parse(rawText);

    expect(suggestion.rpu, equals('987654321098'));
  });

  test('extrae el total con la etiqueta "Importe Total" además de "Total a Pagar"', () {
    final suggestion =
        CfeReceiptTextParser.parse('Importe Total \$980.75');

    expect(suggestion.totalToPay, equals(980.75));
  });

  test(
      'corrige confusiones típicas de OCR (letra por dígito) dentro del '
      'RPU y el total detectados', () {
    final suggestion = CfeReceiptTextParser.parse(
      'RMU 12345678O012\nTotal a pagar \$1,25O.50',
    );

    expect(suggestion.rpu, equals('123456780012'));
    expect(suggestion.totalToPay, equals(1250.50));
  });

  test(
      'recibo con layout de tabla real (tarifa "01", fila "Energía (kWh)" '
      'y tabla de "Consumo histórico" con datos señuelo) extrae los datos '
      'correctos, no los señuelos', () {
    const rawText = '''
Comisión Federal de Electricidad
Av. Paseo de la Reforma 164, Col. Juárez,
NO. DE SERVICIO : 096990551259
TARIFA: 01
PERIODO FACTURADO: 12 ENE 26 - 11 MAR 26
Concepto
Lectura actual
Lectura anterior
Total
periodo
Energía (kWh)
17013
16748
265
Subtotal
(MXN)
Desglose del importe a pagar
Concepto
Importe (MXN)
Energía
322.55
Total
\$404.98
CONSUMO HISTÓRICO
Periodo
kWh
Importe
del 10 NOV 25 al 12 ENE 26
285
\$453.00
Su consumo está dentro del rango INTERMEDIO, mayor a 150 y menor a 280 kWh.
''';

    final suggestion = CfeReceiptTextParser.parse(rawText);

    // La tarifa "01" (formato doméstico simple) no está en la lista fija.
    expect(suggestion.tariff, equals('01'));

    // 265 es el consumo real de la fila "Energía (kWh)"; 285 (tabla
    // histórica) y 280 (texto informativo) son señuelos con "kWh" más
    // cerca en el texto plano.
    expect(suggestion.currentPeriodKwh, equals(265));

    // 404.98 es el total real ("Total" solo, no "Subtotal"); 453.00 es un
    // importe más grande pero de un periodo histórico anterior.
    expect(suggestion.totalToPay, equals(404.98));

    // La dirección corporativa fija de CFE nunca debe tomarse como la
    // dirección del servicio del cliente.
    expect(suggestion.serviceAddress, isNot(contains('PASEO DE LA REFORMA')));

    expect(suggestion.historicalPeriods, hasLength(1));
    expect(
      suggestion.historicalPeriods.single.periodLabel,
      equals('10 NOV 25 - 12 ENE 26'),
    );
    expect(suggestion.historicalPeriods.single.kwh, equals(285));
  });

  test(
      'extrae varios periodos de la tabla "Consumo histórico" en orden, '
      'del más reciente al más antiguo', () {
    const rawText = '''
CONSUMO HISTÓRICO
Periodo
kWh
Importe
del 10 NOV 25 al 12 ENE 26
285
\$453.00
del 10 SEP 25 al 10 NOV 25
268
\$404.00
del 14 JUL 25 al 10 SEP 25
270
\$405.00
''';

    final suggestion = CfeReceiptTextParser.parse(rawText);

    expect(suggestion.historicalPeriods, hasLength(3));
    expect(suggestion.historicalPeriods[0].kwh, equals(285));
    expect(suggestion.historicalPeriods[1].kwh, equals(268));
    expect(suggestion.historicalPeriods[2].kwh, equals(270));
    expect(
      suggestion.historicalPeriods[0].periodLabel,
      equals('10 NOV 25 - 12 ENE 26'),
    );
  });

  test(
      'recibo residencial real: sin etiqueta "Titular:", dirección sin '
      'palabras clave (CALLE/AV/COL) y total sin centavos en el recuadro '
      '"TOTAL A PAGAR"', () {
    const rawText = '''
Comisión Federal de Electricidad
Av. Paseo de la Reforma 164, Col. Juárez,
Alcaldía Cuauhtémoc, Código Postal: 06600,
Ciudad de México, RFC: CFE370814QI0
MACIAS GARCIA ROBERTO
TOTAL A PAGAR:
\$453
BUGAMBILIAS 114 JB
NVO 2DO ANILLO Y Y COST LATERAL INEGI
JARDINES DE BUGAMBILIAS. C.P. 20276
AGUASCALIENTES, Ags7F
(CUATROCIENTOS CINCUENTA Y TRES PESOS M.N.)
DESCARGA NUESTRA APP AUTORIZADA
NO. DE SERVICIO : 096990551259
RMU : 20276 99-05-11 XAXX-010101 001 CFE
CUENTA : 17DP52A011720390
TARIFA: 01
PERIODO FACTURADO: 10 NOV 25 - 12 ENE 26
Energía (kWh)
16748
16463
285
''';

    final suggestion = CfeReceiptTextParser.parse(rawText);

    expect(suggestion.holderName, equals('MACIAS GARCIA ROBERTO'));
    expect(suggestion.serviceAddress, isNotNull);
    expect(suggestion.serviceAddress, contains('BUGAMBILIAS 114'));
    expect(
      suggestion.serviceAddress,
      isNot(contains('PASEO DE LA REFORMA')),
    );
    expect(suggestion.rpu, equals('096990551259'));
    expect(suggestion.tariff, equals('01'));
    expect(
      suggestion.billingPeriod,
      equals('10 NOV 25 - 12 ENE 26'),
    );
    expect(suggestion.currentPeriodKwh, equals(285));

    // El recuadro "TOTAL A PAGAR" de este recibo imprime el monto como
    // entero (sin ".00"); antes del fix se perdía por exigir centavos.
    expect(suggestion.totalToPay, equals(453));
  });

  test(
      'parseFrontAndBack: no confunde datos del reverso (otra dirección, '
      'periodos históricos, montos) con los del frente', () {
    const frontText = '''
Comisión Federal de Electricidad
Av. Paseo de la Reforma 164, Col. Juárez,
Alcaldía Cuauhtémoc, Código Postal: 06600,
Ciudad de México, RFC: CFE370814QI0
MACIAS GARCIA ROBERTO
TOTAL A PAGAR:
\$453
BUGAMBILIAS 114 JB
NVO 2DO ANILLO Y Y COST LATERAL INEGI
JARDINES DE BUGAMBILIAS. C.P. 20276
AGUASCALIENTES, Ags7F
(CUATROCIENTOS CINCUENTA Y TRES PESOS M.N.)
DESCARGA NUESTRA APP AUTORIZADA
NO. DE SERVICIO : 096990551259
RMU : 20276 99-05-11 XAXX-010101 001 CFE
CUENTA : 17DP52A011720390
TARIFA: 01
PERIODO FACTURADO: 10 NOV 25 - 12 ENE 26
Total
periodo
Energía (kWh)
16748
16463
285
''';

    // El reverso trae, a propósito, una dirección distinta (ej. un módulo
    // de atención) y periodos/montos que NO son los del frente, para
    // confirmar que no se cruzan.
    const backText = '''
Módulo de atención más cercano
44:30 hrs. Av de los maestros No 1610 Colonia El Dorado Agu
CONSUMO HISTÓRICO
Periodo
kWh
Importe
del 10 SEP 25 al 10 NOV 25
268
\$404.00
del 14 JUL 25 al 10 SEP 25
270
\$405.00
del 13 MAY 25 al 14 JUL 25
280
\$419.00
''';

    final suggestion = CfeReceiptTextParser.parseFrontAndBack(
      frontText,
      backText: backText,
    );

    expect(suggestion.holderName, equals('MACIAS GARCIA ROBERTO'));

    // La dirección del módulo de atención del reverso no debe imponerse a
    // la dirección real del cliente en el frente.
    expect(suggestion.serviceAddress, contains('BUGAMBILIAS 114'));
    expect(suggestion.serviceAddress, isNot(contains('maestros')));

    // El periodo facturado es el del frente, no una fila de la tabla
    // histórica del reverso.
    expect(suggestion.billingPeriod, equals('10 NOV 25 - 12 ENE 26'));

    // El consumo del periodo es el de la tabla "Energía (kWh)" del frente
    // (285), no confundido con "Total periodo" (su propio encabezado) ni
    // con un kWh histórico del reverso (268, 270, 280).
    expect(suggestion.currentPeriodKwh, equals(285));

    // El total a pagar es el del recuadro del frente (453), no un importe
    // histórico del reverso (404, 405, 419) ni el consumo del periodo.
    expect(suggestion.totalToPay, equals(453));

    // El historial de consumo se toma del reverso.
    expect(suggestion.historicalPeriods, hasLength(3));
    expect(suggestion.historicalPeriods[0].kwh, equals(268));
    expect(suggestion.historicalPeriods[1].kwh, equals(270));
    expect(suggestion.historicalPeriods[2].kwh, equals(280));
  });
}
