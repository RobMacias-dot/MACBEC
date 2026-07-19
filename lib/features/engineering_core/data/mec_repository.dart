import 'package:drift/drift.dart';

import '../../../data/local/database/app_database.dart';

/// Persistencia mínima del MEC. No escribe ni consulta precios comerciales.
class MecRepository {
  MecRepository(this._database);

  final AppDatabase _database;

  Future<List<MecProductSummary>> listProducts({String query = ''}) async {
    final normalized = query.trim().toLowerCase();
    final panels = await _database.select(_database.panels).get();
    final inverters = await _database.select(_database.inverters).get();
    final result = <MecProductSummary>[
      ...panels.map((row) => MecProductSummary.panel(row)),
      ...inverters.map((row) => MecProductSummary.inverter(row)),
    ];
    if (normalized.isEmpty) return result;
    final offers = await _database.select(_database.commercialOffers).get();
    final suppliers = await _database.select(_database.suppliers).get();
    final supplierById = {
      for (final supplier in suppliers) supplier.id: supplier.name
    };
    return result.where((product) {
      final offerText = offers
          .where((offer) =>
              offer.productType == product.type &&
              offer.productId == product.id)
          .map((offer) =>
              '${offer.supplierSku ?? ''} ${offer.supplierName ?? supplierById[offer.supplierId] ?? ''}')
          .join(' ')
          .toLowerCase();
      return '${product.brand} ${product.model} ${product.id} $offerText'
          .toLowerCase()
          .contains(normalized);
    }).toList();
  }

  Future<List<CommercialOfferWithSupplier>> listCommercialOffers(
    String productType,
    String productId,
  ) async {
    final rows = await (_database.select(_database.commercialOffers)
          ..where((row) =>
              row.productType.equals(productType) &
              row.productId.equals(productId))
          ..orderBy([
            (row) => OrderingTerm.asc(row.isActive),
            (row) => OrderingTerm.desc(row.updatedAt)
          ]))
        .get();
    final suppliers = await _database.select(_database.suppliers).get();
    final names = {for (final item in suppliers) item.id: item.name};
    return rows
        .map((row) => CommercialOfferWithSupplier(
            row, row.supplierName ?? names[row.supplierId] ?? 'Sin proveedor'))
        .toList();
  }

  Future<CommercialOffer?> findDuplicateOffer({
    required String productType,
    required String productId,
    String? supplierId,
    String? supplierSku,
    String? excludingId,
  }) async {
    final rows = await listCommercialOffers(productType, productId);
    for (final item in rows) {
      final offer = item.offer;
      if (offer.id != excludingId &&
          offer.supplierId == supplierId &&
          offer.supplierSku == supplierSku) return offer;
    }
    return null;
  }

  Future<void> saveCommercialOffer(CommercialOffersCompanion offer) async {
    final duplicate = await findDuplicateOffer(
      productType: offer.productType.value,
      productId: offer.productId.value,
      supplierId: offer.supplierId.present ? offer.supplierId.value : null,
      supplierSku: offer.supplierSku.present ? offer.supplierSku.value : null,
      excludingId: offer.id.present ? offer.id.value : null,
    );
    if (duplicate != null)
      throw StateError('Ya existe una oferta para este proveedor y SKU.');
    if (offer.id.present) {
      await (_database.update(_database.commercialOffers)
            ..where((row) => row.id.equals(offer.id.value)))
          .write(offer);
    } else {
      await _database.into(_database.commercialOffers).insert(offer);
    }
  }

  Future<void> deactivateCommercialOffer(String id) =>
      (_database.update(_database.commercialOffers)
            ..where((row) => row.id.equals(id)))
          .write(
        CommercialOffersCompanion(
            isActive: const Value(false), updatedAt: Value(DateTime.now())),
      );

  Future<void> setCommercialOfferActive(String id, bool active) =>
      (_database.update(_database.commercialOffers)
            ..where((row) => row.id.equals(id)))
          .write(
        CommercialOffersCompanion(
          isActive: Value(active),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> updateProductGeneral(MecProductSummary product,
      {required String brand,
      required String model,
      required String description,
      required bool active}) async {
    if (product.type == 'panel') {
      await (_database.update(_database.panels)
            ..where((row) => row.id.equals(product.id)))
          .write(
        PanelsCompanion(
            brand: Value(brand),
            model: Value(model),
            description: Value(description),
            isActive: Value(active)),
      );
    } else {
      await (_database.update(_database.inverters)
            ..where((row) => row.id.equals(product.id)))
          .write(
        InvertersCompanion(
            brand: Value(brand),
            model: Value(model),
            description: Value(description)),
      );
    }
  }

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

class MecProductSummary {
  MecProductSummary(
      {required this.id,
      required this.type,
      required this.brand,
      required this.model,
      required this.description,
      required this.powerLabel,
      required this.active});
  factory MecProductSummary.panel(Panel row) => MecProductSummary(
      id: row.id,
      type: 'panel',
      brand: row.brand,
      model: row.model,
      description: row.description ?? '',
      powerLabel: '${row.powerWatts.toStringAsFixed(0)} W',
      active: row.isActive);
  factory MecProductSummary.inverter(Inverter row) => MecProductSummary(
      id: row.id,
      type: 'inverter',
      brand: row.brand,
      model: row.model,
      description: row.description ?? '',
      powerLabel: '${row.nominalPowerWatts.toStringAsFixed(0)} W',
      active: true);
  final String id, type, brand, model, description, powerLabel;
  final bool active;
}

class CommercialOfferWithSupplier {
  const CommercialOfferWithSupplier(this.offer, this.supplierName);
  final CommercialOffer offer;
  final String supplierName;
}
