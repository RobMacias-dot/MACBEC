class ContractTemplateInput {
  const ContractTemplateInput({
    required this.companyName,
    required this.companyRfc,
    required this.companyAddress,
    required this.clientName,
    required this.systemDescription,
    required this.totalPvKw,
    required this.currency,
    required this.total,
    required this.advancePayment,
    required this.warrantyNote,
    required this.date,
    this.clientAddress,
    this.paymentTermsNote,
  });

  final String companyName;
  final String companyRfc;
  final String companyAddress;
  final String clientName;
  final String? clientAddress;
  final String systemDescription;
  final double totalPvKw;
  final String currency;
  final double total;
  final double advancePayment;
  final String? paymentTermsNote;
  final String warrantyNote;
  final DateTime date;
}

/// Genera el texto de un contrato base de instalación fotovoltaica a partir
/// de los datos ya capturados en la cotización (cliente, equipos, montos,
/// garantías). Es una plantilla genérica de apoyo operativo: debe revisarse
/// y validarse por un profesional legal antes de usarse como contrato
/// oficial vinculante.
class ContractTemplateBuilder {
  const ContractTemplateBuilder._();

  static String build(ContractTemplateInput input) {
    final dateLabel = _formatDate(input.date);
    final advanceLabel = input.advancePayment > 0
        ? '${input.currency} ${input.advancePayment.toStringAsFixed(2)} '
            'como anticipo y el resto conforme al esquema de pagos acordado'
        : 'conforme al esquema de pagos acordado';

    return '''
CONTRATO DE PRESTACIÓN DE SERVICIOS DE INSTALACIÓN FOTOVOLTAICA

Entre ${input.companyName}, RFC ${input.companyRfc.isEmpty ? 'no registrado' : input.companyRfc}, con domicilio en ${input.companyAddress.isEmpty ? 'no registrado' : input.companyAddress} (en adelante "el Proveedor"), y ${input.clientName}${input.clientAddress != null && input.clientAddress!.trim().isNotEmpty ? ', con domicilio en ${input.clientAddress}' : ''} (en adelante "el Cliente"), se celebra el presente contrato al día $dateLabel, sujeto a las siguientes cláusulas:

PRIMERA. Objeto del contrato.
El Proveedor se compromete a suministrar e instalar un sistema fotovoltaico con capacidad instalada aproximada de ${input.totalPvKw.toStringAsFixed(2)} kWp, integrado por: ${input.systemDescription}.

SEGUNDA. Monto y forma de pago.
El monto total de este contrato es de ${input.currency} \$${input.total.toStringAsFixed(2)}, pagadero $advanceLabel.
${input.paymentTermsNote != null && input.paymentTermsNote!.trim().isNotEmpty ? 'Esquema de pagos acordado: ${input.paymentTermsNote}.' : ''}

TERCERA. Garantías.
${input.warrantyNote}

CUARTA. Vigencia y entrega.
El plazo de instalación se acordará por separado entre las partes según disponibilidad de equipos y condiciones del sitio.

QUINTA. Firmas.
Ambas partes firman de conformidad con lo aquí establecido.

--
Plantilla base sujeta a revisión legal antes de su uso oficial. No sustituye asesoría jurídica profesional.
''';
  }

  static String _formatDate(DateTime date) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }
}
