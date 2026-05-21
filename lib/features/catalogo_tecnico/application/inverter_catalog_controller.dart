import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/database_provider.dart';
import '../data/inverter_catalog_repository.dart';
import '../domain/entities/solar_inverter.dart';

final inverterCatalogRepositoryProvider = Provider<InverterCatalogRepository>(
  (ref) {
    return InverterCatalogRepository(ref.watch(appDatabaseProvider));
  },
);

final invertersCatalogProvider = FutureProvider<List<SolarInverter>>(
  (ref) async {
    return ref.watch(inverterCatalogRepositoryProvider).getAllInverters();
  },
);
