/// Subconjuntos de catálogos oficiales del SAT usados con más frecuencia.
/// No son exhaustivos: para casos particulares, validar con el contador o
/// el catálogo completo del SAT antes de facturar.
class SatCatalogs {
  const SatCatalogs._();

  static const regimenesFiscales = <String, String>{
    '601': 'General de Ley Personas Morales',
    '603': 'Personas Morales con Fines no Lucrativos',
    '605': 'Sueldos y Salarios',
    '606': 'Arrendamiento',
    '608': 'Demás ingresos',
    '612': 'Personas Físicas con Actividades Empresariales y Profesionales',
    '616': 'Sin obligaciones fiscales',
    '621': 'Incorporación Fiscal',
    '625': 'Actividades Empresariales con ingresos a través de Plataformas',
    '626': 'Régimen Simplificado de Confianza (RESICO)',
  };

  static const usosCfdi = <String, String>{
    'G01': 'Adquisición de mercancías',
    'G02': 'Devoluciones, descuentos o bonificaciones',
    'G03': 'Gastos en general',
    'I01': 'Construcciones',
    'I08': 'Otra maquinaria y equipo',
    'D01': 'Honorarios médicos, dentales y gastos hospitalarios',
    'P01': 'Por definir',
    'S01': 'Sin efectos fiscales',
    'CP01': 'Pagos',
  };

  static const formasPago = <String, String>{
    '01': 'Efectivo',
    '02': 'Cheque nominativo',
    '03': 'Transferencia electrónica de fondos',
    '04': 'Tarjeta de crédito',
    '28': 'Tarjeta de débito',
    '99': 'Por definir',
  };

  static const metodosPago = <String, String>{
    'PUE': 'Pago en una sola exhibición',
    'PPD': 'Pago en parcialidades o diferido',
  };
}
