import '../../data/local/database/app_database.dart';
import '../../features/engineering_core/data/jinko_66hl4m_bdv_seed.dart';
import '../../features/engineering_core/data/mec_initial_catalog_seed.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    // Fase 0:
    // Aquí crecerá la inicialización global:
    // - configuración de timezone/locale
    // - validación de storage seguro
    // - preparación de SQLite
    // - carga de settings iniciales
    // - migraciones futuras
    //
    // El catálogo técnico confirmado se inicializa de forma idempotente y
    // separada de precios o datos de demo.
    final database = AppDatabase();
    try {
      await Jinko66hl4mBdvSeed.ensureSeeded(database);
      await MecInitialCatalogSeed.ensureSeeded(database);
    } finally {
      await database.close();
    }
  }
}
