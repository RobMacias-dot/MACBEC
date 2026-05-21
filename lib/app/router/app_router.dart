import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analisis_energetico/presentation/screens/analisis_consumo_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/setup_admin_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/catalogo_tecnico/presentation/screens/catalogo_importacion_screen.dart';
import '../../features/catalogo_tecnico/presentation/screens/catalogo_inversores_screen.dart';
import '../../features/catalogo_tecnico/presentation/screens/catalogo_paneles_screen.dart';
import '../../features/clientes/presentation/screens/cliente_detalle_screen.dart';
import '../../features/clientes/presentation/screens/cliente_form_screen.dart';
import '../../features/clientes/presentation/screens/clientes_screen.dart';
import '../../features/configuracion/presentation/screens/configuracion_screen.dart';
import '../../features/cotizaciones/presentation/screens/cotizacion_cliente_preview_screen.dart';
import '../../features/cotizaciones/presentation/screens/cotizacion_interna_screen.dart';
import '../../features/cotizaciones/presentation/screens/cotizacion_prospecto_form_screen.dart';
import '../../features/cotizaciones/presentation/screens/cotizacion_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dimensionamiento_electrico/presentation/screens/dimensionamiento_electrico_screen.dart';
import '../../features/expediente/presentation/screens/expediente_screen.dart';
import '../../features/proveedores_precios/presentation/screens/analisis_producto_screen.dart';
import '../../features/proveedores_precios/presentation/screens/proveedores_screen.dart';
import '../../features/proyectos/presentation/screens/proyecto_detalle_screen.dart';
import '../../features/proyectos/presentation/screens/proyecto_form_screen.dart';
import '../../features/recibo_cfe/presentation/screens/recibo_cfe_revision_screen.dart';
import '../../features/recibo_cfe/presentation/screens/recibo_cfe_screen.dart';
import '../../features/seleccion_tecnica/presentation/screens/seleccion_tecnica_screen.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.setupAdmin,
        builder: (context, state) => const SetupAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.clientes,
        builder: (context, state) => const ClientesScreen(),
      ),
      GoRoute(
        path: AppRoutes.clienteForm,
        builder: (context, state) => const ClienteFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.clienteDetalle,
        builder: (context, state) => const ClienteDetalleScreen(),
      ),
      GoRoute(
        path: AppRoutes.proyectoForm,
        builder: (context, state) => const ProyectoFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.proyectoDetalle,
        builder: (context, state) => const ProyectoDetalleScreen(),
      ),
      GoRoute(
        path: AppRoutes.reciboCfe,
        builder: (context, state) => const ReciboCfeScreen(),
      ),
      GoRoute(
        path: AppRoutes.reciboCfeRevision,
        builder: (context, state) => const ReciboCfeRevisionScreen(),
      ),
      GoRoute(
        path: AppRoutes.analisisConsumo,
        builder: (context, state) => const AnalisisConsumoScreen(),
      ),
      GoRoute(
        path: AppRoutes.seleccionTecnica,
        builder: (context, state) => const SeleccionTecnicaScreen(),
      ),
      GoRoute(
        path: AppRoutes.dimensionamientoElectrico,
        builder: (context, state) => const DimensionamientoElectricoScreen(),
      ),
      GoRoute(
        path: AppRoutes.catalogoPaneles,
        builder: (context, state) => const CatalogoPanelesScreen(),
      ),
      GoRoute(
        path: AppRoutes.catalogoInversores,
        builder: (context, state) => const CatalogoInversoresScreen(),
      ),
      GoRoute(
        path: AppRoutes.proveedores,
        builder: (context, state) => const ProveedoresScreen(),
      ),
      GoRoute(
        path: AppRoutes.importacionCatalogo,
        builder: (context, state) => const CatalogoImportacionScreen(),
      ),
      GoRoute(
        path: AppRoutes.analisisProductoCatalogo,
        builder: (context, state) => const AnalisisProductoScreen(),
      ),
      GoRoute(
        path: AppRoutes.cotizacion,
        builder: (context, state) => const CotizacionScreen(),
      ),
      GoRoute(
        path: AppRoutes.cotizacionProspectoForm,
        builder: (context, state) => const CotizacionProspectoFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.cotizacionInterna,
        builder: (context, state) => const CotizacionInternaScreen(),
      ),
      GoRoute(
        path: AppRoutes.cotizacionClientePreview,
        builder: (context, state) => const CotizacionClientePreviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.expediente,
        builder: (context, state) => const ExpedienteScreen(),
      ),
      GoRoute(
        path: AppRoutes.configuracion,
        builder: (context, state) => const ConfiguracionScreen(),
      ),
    ],
  );
});
