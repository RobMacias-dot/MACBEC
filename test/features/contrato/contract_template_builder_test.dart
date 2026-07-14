import 'package:flutter_test/flutter_test.dart';
import 'package:macbec_solar_app/features/contrato/domain/contract_template_builder.dart';

void main() {
  test('incluye cliente, equipos, monto y garantia en el texto generado', () {
    final text = ContractTemplateBuilder.build(
      ContractTemplateInput(
        companyName: 'MacBec Soluciones en Energía',
        companyRfc: 'MSE010101AAA',
        companyAddress: 'Calle Falsa 123',
        clientName: 'Juan Pérez',
        clientAddress: 'Av. Siempre Viva 742',
        systemDescription: '10 × Jinko Tiger Neo 585W, 1 × Growatt 6000TL-X',
        totalPvKw: 5.85,
        currency: 'MXN',
        total: 84000,
        advancePayment: 42000,
        paymentTermsNote: '50% anticipo, 50% contra entrega',
        warrantyNote: 'Garantía de 12 años en producto, 25 en generación.',
        date: DateTime(2026, 3, 15),
      ),
    );

    expect(text, contains('Juan Pérez'));
    expect(text, contains('Av. Siempre Viva 742'));
    expect(text, contains('10 × Jinko Tiger Neo 585W'));
    expect(text, contains('5.85'));
    expect(text, contains(r'$84000.00'));
    expect(text, contains('50% anticipo, 50% contra entrega'));
    expect(text, contains('Garantía de 12 años'));
    expect(text, contains('15 de marzo de 2026'));
    expect(text, contains('revisión legal'));
  });

  test('usa textos por defecto cuando falta RFC o domicilio de la empresa',
      () {
    final text = ContractTemplateBuilder.build(
      ContractTemplateInput(
        companyName: 'MacBec',
        companyRfc: '',
        companyAddress: '',
        clientName: 'Cliente sin dirección',
        systemDescription: '5 × Panel X',
        totalPvKw: 2.5,
        currency: 'MXN',
        total: 30000,
        advancePayment: 0,
        warrantyNote: 'Garantía estándar.',
        date: DateTime(2026, 1, 1),
      ),
    );

    expect(text, contains('RFC no registrado'));
    expect(text, contains('conforme al esquema de pagos acordado'));
  });
}
