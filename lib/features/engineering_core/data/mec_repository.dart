import 'package:drift/drift.dart';

import '../../../data/local/database/app_database.dart';

/// Persistencia mínima del MEC. No escribe ni consulta precios comerciales.
class MecRepository {
  MecRepository(this._database);

  final AppDatabase _database;

  Future<TechnicalDocument> saveTechnicalDocument(
    TechnicalDocumentsCompanion document,
  ) {
    return _database
        .into(_database.technicalDocuments)
        .insertReturning(document);
  }

  Future<TechnicalProductRevision> saveProductRevision(
    TechnicalProductRevisionsCompanion revision,
  ) async {
    await (_database.update(_database.technicalProductRevisions)
          ..where(
            (row) => row.panelId.equals(revision.panelId.value),
          ))
        .write(
      const TechnicalProductRevisionsCompanion(isCurrent: Value(false)),
    );
    return _database
        .into(_database.technicalProductRevisions)
        .insertReturning(revision);
  }

  Future<PanelTechnicalSpecification> savePanelSpecification(
    PanelTechnicalSpecificationsCompanion specification,
  ) {
    return _database
        .into(_database.panelTechnicalSpecifications)
        .insertReturning(specification);
  }

  Future<TechnicalProductRevision?> getCurrentPanelRevision(String panelId) {
    return (_database.select(_database.technicalProductRevisions)
          ..where(
            (row) => row.panelId.equals(panelId) & row.isCurrent.equals(true),
          ))
        .getSingleOrNull();
  }

  Future<List<TechnicalFieldEvidenceData>> getFieldEvidence({
    required String productRevisionId,
    required String fieldKey,
  }) {
    return (_database.select(_database.technicalFieldEvidence)
          ..where(
            (row) =>
                row.productRevisionId.equals(productRevisionId) &
                row.fieldKey.equals(fieldKey),
          ))
        .get();
  }

  Future<PanelTechnicalSpecification?> getCurrentPanelSpecification(
    String panelId,
  ) async {
    final revision = await getCurrentPanelRevision(panelId);
    if (revision == null) return null;
    return (_database.select(_database.panelTechnicalSpecifications)
          ..where((row) => row.productRevisionId.equals(revision.id)))
        .getSingleOrNull();
  }

  Future<TechnicalInverterRevision> saveInverterRevision(
    TechnicalInverterRevisionsCompanion revision,
  ) async {
    await (_database.update(_database.technicalInverterRevisions)
          ..where((row) => row.inverterId.equals(revision.inverterId.value)))
        .write(
      const TechnicalInverterRevisionsCompanion(isCurrent: Value(false)),
    );
    return _database
        .into(_database.technicalInverterRevisions)
        .insertReturning(revision);
  }

  Future<InverterTechnicalSpecification> saveInverterSpecification(
    InverterTechnicalSpecificationsCompanion specification,
  ) {
    return _database
        .into(_database.inverterTechnicalSpecifications)
        .insertReturning(specification);
  }
}
