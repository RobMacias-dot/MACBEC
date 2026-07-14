import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.showHomeButton = true,
    this.showBackButton = true,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showHomeButton;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final isMainOrAuthRoute = _isMainOrAuthRoute(currentPath);
    final canGoBack = Navigator.of(context).canPop();

    final effectiveActions = <Widget>[
      if (showHomeButton && !isMainOrAuthRoute)
        IconButton(
          tooltip: 'Ir al menú principal',
          onPressed: () => context.go(AppRoutes.dashboard),
          icon: const Icon(Icons.home_outlined),
        ),
      ...?actions,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: showBackButton && !isMainOrAuthRoute
            ? IconButton(
                tooltip: 'Regresar',
                onPressed: () {
                  if (canGoBack) {
                    context.pop();
                    return;
                  }

                  context.go(_fallbackBackRoute(currentPath));
                },
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: effectiveActions,
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  bool _isMainOrAuthRoute(String path) {
    return path == AppRoutes.splash ||
        path == AppRoutes.welcome ||
        path == AppRoutes.login ||
        path == AppRoutes.setupAdmin ||
        path == AppRoutes.dashboard;
  }

  String _fallbackBackRoute(String currentPath) {
    switch (currentPath) {
      case AppRoutes.reciboCfe:
        return AppRoutes.cotizacion;
      case AppRoutes.reciboCfeRevision:
        return AppRoutes.reciboCfe;
      case AppRoutes.analisisConsumo:
        return AppRoutes.reciboCfeRevision;
      case AppRoutes.seleccionTecnica:
        return AppRoutes.analisisConsumo;
      case AppRoutes.dimensionamientoElectrico:
        return AppRoutes.seleccionTecnica;
      case AppRoutes.estructura:
        return AppRoutes.dimensionamientoElectrico;
      case AppRoutes.proveedores:
        return AppRoutes.dashboard;
      case AppRoutes.importacionCatalogo:
      case AppRoutes.analisisProductoCatalogo:
        return AppRoutes.proveedores;
      case AppRoutes.catalogoPaneles:
      case AppRoutes.catalogoInversores:
      case AppRoutes.clientes:
      case AppRoutes.expediente:
      case AppRoutes.configuracion:
      case AppRoutes.cotizacion:
        return AppRoutes.dashboard;
      case AppRoutes.clienteForm:
      case AppRoutes.clienteDetalle:
        return AppRoutes.clientes;
      case AppRoutes.cotizacionProspectoForm:
      case AppRoutes.cotizacionInterna:
      case AppRoutes.cotizacionClientePreview:
      case AppRoutes.propuestaTecnica:
      case AppRoutes.contrato:
        return AppRoutes.cotizacion;
      case AppRoutes.contratoFirma:
        return AppRoutes.contrato;
      case AppRoutes.proyectoForm:
      case AppRoutes.proyectoDetalle:
        return AppRoutes.cotizacion;
      default:
        return AppRoutes.dashboard;
    }
  }
}
