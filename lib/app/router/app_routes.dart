class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const setupAdmin = '/setup-admin';
  static const dashboard = '/dashboard';

  static const clientes = '/clientes';
  static const clienteForm = '/clientes/form';
  static const clienteDetalle = '/clientes/detalle';
  static const clienteDatosFiscales = '/clientes/datos-fiscales';

  static const proyectoForm = '/proyectos/form';
  static const proyectoDetalle = '/proyectos/detalle';

  static const reciboCfe = '/recibo-cfe';
  static const reciboCfeRevision = '/recibo-cfe/revision';

  static const analisisConsumo = '/analisis-consumo';
  static const seleccionTecnica = '/cotizacion/seleccion-tecnica';
  static const dimensionamientoElectrico = '/dimensionamiento-electrico';
  static const estructura = '/estructura';

  static const catalogoPaneles = '/catalogo/paneles';
  static const catalogoInversores = '/catalogo/inversores';
  static const importacionCatalogo = '/catalogo/importacion';
  static const analisisProductoCatalogo = '/catalogo/analisis-producto';

  static const proveedores = '/proveedores';
  static const mecProductManager = '/mec/productos';

  static const cotizacion = '/cotizacion';
  static const cotizacionProspectoForm = '/cotizacion/prospecto-form';
  static const cotizacionInterna = '/cotizacion/interna';
  static const cotizacionClientePreview = '/cotizacion/cliente-preview';
  static const propuestaTecnica = '/cotizacion/propuesta-tecnica';

  static const contrato = '/cotizacion/contrato';
  static const contratoFirma = '/cotizacion/contrato/firma';

  static const prefactura = '/cotizacion/prefactura';

  static const expediente = '/expediente';
  static const expedienteProyecto = '/expediente/proyecto';
  static const configuracion = '/configuracion';
}
