import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/database_provider.dart';
import '../data/panel_catalog_repository.dart';
import '../domain/entities/solar_panel.dart';

final panelCatalogRepositoryProvider = Provider<PanelCatalogRepository>(
  (ref) {
    return PanelCatalogRepository(ref.watch(appDatabaseProvider));
  },
);

final panelsCatalogProvider = FutureProvider<List<SolarPanel>>(
  (ref) async {
    return ref.watch(panelCatalogRepositoryProvider).getAllPanels();
  },
);
