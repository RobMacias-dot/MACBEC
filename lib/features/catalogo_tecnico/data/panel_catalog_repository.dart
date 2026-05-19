import 'package:drift/drift.dart';

import '../../../data/local/database/app_database.dart';
import '../domain/entities/solar_panel.dart';

class PanelCatalogRepository {
  PanelCatalogRepository(this._database);

  final AppDatabase _database;

  Future<List<SolarPanel>> getAllPanels() async {
    final query = _database.select(_database.panels)
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([
        (table) => OrderingTerm.asc(table.brand),
        (table) => OrderingTerm.asc(table.model),
      ]);

    final rows = await query.get();

    return rows.map(_mapRowToEntity).toList();
  }

  Future<String> createPanel(SaveSolarPanelInput input) async {
    final now = DateTime.now();

    final id = await _database.into(_database.panels).insertReturning(
          PanelsCompanion.insert(
            brand: input.brand.trim(),
            model: input.model.trim(),
            powerWatts: input.powerWatts,
            voc: Value(input.voc),
            isc: Value(input.isc),
            lengthMm: Value(input.lengthMm),
            widthMm: Value(input.widthMm),
            thicknessMm: Value(input.thicknessMm),
            purchasePrice: Value(input.purchasePrice),
            isActive: Value(input.isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return id.id;
  }

  Future<void> updatePanel({
    required String panelId,
    required SaveSolarPanelInput input,
  }) async {
    final now = DateTime.now();

    await (_database.update(_database.panels)
          ..where((table) => table.id.equals(panelId)))
        .write(
      PanelsCompanion(
        brand: Value(input.brand.trim()),
        model: Value(input.model.trim()),
        powerWatts: Value(input.powerWatts),
        voc: Value(input.voc),
        isc: Value(input.isc),
        lengthMm: Value(input.lengthMm),
        widthMm: Value(input.widthMm),
        thicknessMm: Value(input.thicknessMm),
        purchasePrice: Value(input.purchasePrice),
        isActive: Value(input.isActive),
        updatedAt: Value(now),
      ),
    );
  }

  Future<bool> upsertPanelByBrandAndModel(
    SaveSolarPanelInput input,
  ) async {
    final normalizedBrand = input.brand.trim().toLowerCase();
    final normalizedModel = input.model.trim().toLowerCase();

    final rows = await (_database.select(_database.panels)
          ..where((table) => table.isDeleted.equals(false)))
        .get();

    Panel? existingPanel;

    for (final row in rows) {
      if (row.brand.trim().toLowerCase() == normalizedBrand &&
          row.model.trim().toLowerCase() == normalizedModel) {
        existingPanel = row;
        break;
      }
    }

    if (existingPanel == null) {
      await createPanel(input);
      return true;
    }

    await updatePanel(
      panelId: existingPanel.id,
      input: input,
    );

    return false;
  }

  Future<void> setPanelActive({
    required String panelId,
    required bool isActive,
  }) async {
    final now = DateTime.now();

    await (_database.update(_database.panels)
          ..where((table) => table.id.equals(panelId)))
        .write(
      PanelsCompanion(
        isActive: Value(isActive),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> softDeletePanel(String panelId) async {
    final now = DateTime.now();

    await (_database.update(_database.panels)
          ..where((table) => table.id.equals(panelId)))
        .write(
      PanelsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  SolarPanel _mapRowToEntity(Panel row) {
    return SolarPanel(
      id: row.id,
      brand: row.brand,
      model: row.model,
      powerWatts: row.powerWatts,
      voc: row.voc,
      isc: row.isc,
      lengthMm: row.lengthMm,
      widthMm: row.widthMm,
      thicknessMm: row.thicknessMm,
      purchasePrice: row.purchasePrice,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
