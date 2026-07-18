import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

const _uuid = Uuid();

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'macbec_solar.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

mixin LocalFirstColumns on Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get createdBy => text().nullable()();
  TextColumn get updatedBy => text().nullable()();
  TextColumn get deviceId => text().nullable()();
}

class Roles extends Table with LocalFirstColumns {
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Users extends Table with LocalFirstColumns {
  TextColumn get roleId => text().nullable().references(Roles, #id)();
  TextColumn get fullName => text()();
  TextColumn get email => text().nullable()();
  TextColumn get pinHash => text().nullable()();
  BoolColumn get isAdmin => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Clients extends Table with LocalFirstColumns {
  TextColumn get fullName => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ClientFiscalData extends Table with LocalFirstColumns {
  TextColumn get clientId => text().references(Clients, #id)();
  TextColumn get rfc => text().nullable()();
  TextColumn get legalName => text().nullable()();
  TextColumn get fiscalRegime => text().nullable()();
  TextColumn get fiscalZipCode => text().nullable()();
  TextColumn get cfdiUse => text().nullable()();
  TextColumn get invoiceEmail => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Projects extends Table with LocalFirstColumns {
  TextColumn get clientId => text().references(Clients, #id)();
  TextColumn get name => text()();
  TextColumn get status => text().withDefault(const Constant('prospecto'))();
  TextColumn get installationType => text().nullable()();
  TextColumn get serviceAddress => text().nullable()();
  TextColumn get state => text().nullable()();
  TextColumn get municipality => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProjectStatusHistory extends Table with LocalFirstColumns {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get previousStatus => text().nullable()();
  TextColumn get newStatus => text()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Documents extends Table with LocalFirstColumns {
  TextColumn get clientId => text().nullable().references(Clients, #id)();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  // Sin FK real: QuotationDrafts ya referencia a Documents
  // (cfeReceiptDocumentId), y Drift no admite referencias circulares
  // entre tablas. Se mantiene como columna simple para poder ligar
  // documentos a un borrador sin crear el ciclo.
  TextColumn get quotationDraftId => text().nullable()();
  TextColumn get documentType => text()();
  TextColumn get localPath => text()();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  TextColumn get hash => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class QuotationDrafts extends Table with LocalFirstColumns {
  TextColumn get draftCode => text().nullable()();
  TextColumn get projectId => text().nullable().references(Projects, #id)();

  TextColumn get prospectName => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get whatsapp => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();

  TextColumn get status =>
      text().withDefault(const Constant('receipt_pending'))();

  BoolColumn get hasCfeReceipt =>
      boolean().withDefault(const Constant(false))();

  TextColumn get cfeReceiptDocumentId =>
      text().nullable().references(Documents, #id)();

  TextColumn get cfeHolderName => text().nullable()();
  TextColumn get cfeServiceAddress => text().nullable()();
  TextColumn get rpu => text().nullable()();
  TextColumn get cfeTariff => text().nullable()();
  TextColumn get cfeBillingPeriod => text().nullable()();
  RealColumn get cfeCurrentPeriodKwh => real().nullable()();
  RealColumn get cfeTotalToPay => real().nullable()();

  RealColumn get analysisPeakSunHours => real().nullable()();
  RealColumn get analysisPanelPowerWatts => real().nullable()();

  TextColumn get lastCompletedStep => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class QuotationDraftConsumptions extends Table with LocalFirstColumns {
  TextColumn get quotationDraftId => text().references(QuotationDrafts, #id)();

  TextColumn get periodLabel => text().nullable()();
  RealColumn get kwh => real()();
  RealColumn get amount => real().nullable()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class QuotationDraftPvCalculations extends Table with LocalFirstColumns {
  TextColumn get quotationDraftId => text().references(QuotationDrafts, #id)();
  TextColumn get panelId => text().nullable().references(Panels, #id)();

  RealColumn get annualConsumptionKwh => real()();
  RealColumn get dailyConsumptionKwh => real()();
  RealColumn get peakSunHours => real()();
  RealColumn get panelPowerWatts => real()();
  RealColumn get lossFactor => real().withDefault(const Constant(0.80))();
  RealColumn get generationPerPanelKwhDay => real()();
  IntColumn get requiredPanels => integer()();

  TextColumn get calculationSnapshotJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Suppliers extends Table with LocalFirstColumns {
  TextColumn get name => text()();
  TextColumn get contactName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Panels extends Table with LocalFirstColumns {
  TextColumn get brand => text()();
  TextColumn get model => text()();
  RealColumn get powerWatts => real()();

  RealColumn get voc => real().nullable()();
  RealColumn get isc => real().nullable()();
  RealColumn get vmp => real().nullable()();
  RealColumn get imp => real().nullable()();
  RealColumn get efficiency => real().nullable()();

  RealColumn get lengthMm => real().nullable()();
  RealColumn get widthMm => real().nullable()();
  RealColumn get thicknessMm => real().nullable()();

  RealColumn get purchasePrice => real().nullable()();

  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  DateTimeColumn get lastPriceUpdateAt => dateTime().nullable()();
  TextColumn get priceSource => text().nullable()();

  BoolColumn get isPriceLocked =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get requiresPriceReview =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Metadatos de archivos que respaldan una especificación técnica.
///
/// No reutiliza [Documents]: estos registros no pertenecen a un cliente ni a
/// una cotización y se conservan aunque cambie el catálogo comercial.
class TechnicalDocuments extends Table with LocalFirstColumns {
  TextColumn get source => text()();
  TextColumn get sourceVersion => text().nullable()();
  TextColumn get localPath => text().nullable()();
  TextColumn get fileName => text()();
  TextColumn get sha256 => text().nullable()();
  TextColumn get verificationStatus => text()();
  TextColumn get confidenceLevel => text()();
  DateTimeColumn get publishedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Revisión inmutable de la ficha técnica de un producto del catálogo.
class TechnicalProductRevisions extends Table with LocalFirstColumns {
  TextColumn get panelId => text().references(Panels, #id)();
  TextColumn get revisionCode => text()();
  TextColumn get sourceDocumentId =>
      text().nullable().references(TechnicalDocuments, #id)();
  TextColumn get verificationStatus => text()();
  TextColumn get confidenceLevel => text()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(true))();
  DateTimeColumn get effectiveAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Evidencia por campo para conservar la trazabilidad de valores críticos.
class TechnicalFieldEvidence extends Table with LocalFirstColumns {
  TextColumn get productRevisionId =>
      text().references(TechnicalProductRevisions, #id)();
  TextColumn get fieldKey => text()();
  TextColumn get valueText => text()();
  TextColumn get valueStatus => text()();
  TextColumn get sourceDocumentId =>
      text().nullable().references(TechnicalDocuments, #id)();
  TextColumn get sourceLocator => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Datos extendidos de panel que no pertenecen al catálogo comercial.
class PanelTechnicalSpecifications extends Table with LocalFirstColumns {
  TextColumn get productRevisionId =>
      text().references(TechnicalProductRevisions, #id)();
  TextColumn get technology => text().nullable()();
  IntColumn get cellCount => integer().nullable()();
  RealColumn get vmp => real().nullable()();
  RealColumn get imp => real().nullable()();
  RealColumn get efficiencyPercent => real().nullable()();
  RealColumn get pmaxTemperatureCoefficientPerC => real().nullable()();
  RealColumn get vocTemperatureCoefficientPerC => real().nullable()();
  RealColumn get iscTemperatureCoefficientPerC => real().nullable()();
  RealColumn get noctCelsius => real().nullable()();
  RealColumn get weightKg => real().nullable()();
  RealColumn get maxSystemVoltage => real().nullable()();
  RealColumn get maxSeriesFuseAmps => real().nullable()();
  RealColumn get minOperatingTemperatureCelsius => real().nullable()();
  RealColumn get maxOperatingTemperatureCelsius => real().nullable()();
  RealColumn get frontLoadPa => real().nullable()();
  RealColumn get rearLoadPa => real().nullable()();
  TextColumn get specificationJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Revisión inmutable de la ficha técnica de un inversor del catálogo.
class TechnicalInverterRevisions extends Table with LocalFirstColumns {
  TextColumn get inverterId => text().references(Inverters, #id)();
  TextColumn get revisionCode => text()();
  TextColumn get sourceDocumentId =>
      text().nullable().references(TechnicalDocuments, #id)();
  TextColumn get verificationStatus => text()();
  TextColumn get confidenceLevel => text()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(true))();
  DateTimeColumn get effectiveAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Datos extendidos de inversor que conservan el alcance de la ficha fuente.
class InverterTechnicalSpecifications extends Table with LocalFirstColumns {
  TextColumn get productRevisionId =>
      text().references(TechnicalInverterRevisions, #id)();
  RealColumn get mpptMinVoltage => real().nullable()();
  RealColumn get mpptMaxVoltage => real().nullable()();
  RealColumn get startupVoltage => real().nullable()();
  RealColumn get nominalDcVoltage => real().nullable()();
  RealColumn get maxInputCurrentPerMppt => real().nullable()();
  IntColumn get stringsPerMppt => integer().nullable()();
  RealColumn get maxEfficiencyPercent => real().nullable()();
  TextColumn get gridConnection => text().nullable()();
  TextColumn get protectionRating => text().nullable()();
  RealColumn get weightKg => real().nullable()();
  TextColumn get specificationJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Compatibilidades técnicas entre productos usando sus claves de catálogo.
class TechnicalProductCompatibilities extends Table with LocalFirstColumns {
  @ReferenceName('sourcePanelCompatibilities')
  TextColumn get sourcePanelId => text().references(Panels, #id)();

  @ReferenceName('compatiblePanelCompatibilities')
  TextColumn get compatiblePanelId =>
      text().nullable().references(Panels, #id)();
  TextColumn get compatibilityType => text()();
  TextColumn get status => text()();
  TextColumn get evidenceId =>
      text().nullable().references(TechnicalFieldEvidence, #id)();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Inverters extends Table with LocalFirstColumns {
  TextColumn get brand => text()();
  TextColumn get model => text()();
  RealColumn get nominalPowerWatts => real()();
  RealColumn get maxPvPowerWatts => real().nullable()();
  RealColumn get maxDcVoltage => real().nullable()();
  RealColumn get maxShortCircuitCurrentPerMppt => real().nullable()();
  RealColumn get maxOutputCurrent => real().nullable()();
  IntColumn get mpptCount => integer().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  DateTimeColumn get lastPriceUpdateAt => dateTime().nullable()();
  TextColumn get priceSource => text().nullable()();
  BoolColumn get isPriceLocked =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get requiresPriceReview =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Cables extends Table with LocalFirstColumns {
  TextColumn get name => text()();
  TextColumn get material => text().withDefault(const Constant('cobre'))();
  TextColumn get gauge => text()();
  RealColumn get ampacity => real().nullable()();
  RealColumn get resistance => real().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catálogo comercial genérico para materiales que no tienen tabla propia
/// (estructura, protecciones CD/CA, material eléctrico, tubería/cable
/// comercial, mano de obra). Espeja las columnas de la hoja
/// `Catalogo_Productos` del Excel estándar de MacBec - ver Fase 6.22.
class MaterialCatalogProducts extends Table with LocalFirstColumns {
  TextColumn get codigoInterno => text().nullable()();
  TextColumn get categoriaApp => text()();
  TextColumn get subcategoria => text().nullable()();
  TextColumn get marca => text().nullable()();
  TextColumn get modelo => text().nullable()();
  TextColumn get descripcion => text().nullable()();
  TextColumn get unidadCompra => text().nullable()();
  TextColumn get moneda => text().withDefault(const Constant('MXN'))();
  RealColumn get precioCompra => real().nullable()();
  RealColumn get precioMxn => real().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  BoolColumn get revisarPrecio =>
      boolean().withDefault(const Constant(false))();
  TextColumn get estadoParaCalculo => text().nullable()();
  RealColumn get longitudNominalM => real().nullable()();
  RealColumn get longitudUtilCalculoM => real().nullable()();

  /// Clave estructurada de `tipo_elemento_estructura` (p. ej. RIEL,
  /// PERFIL_PTR, PERFIL_ANGULO_ALUMINIO, CLAMP_INTERMEDIO, CLAMP_FINAL,
  /// ANCLAJE_QUIMICO). Solo aplica a categoría ESTRUCTURA, pero se guarda
  /// aquí porque es mucho más confiable para emparejar BOM que buscar
  /// palabras clave en la descripción.
  TextColumn get tipoElementoEstructura => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Conduits extends Table with LocalFirstColumns {
  TextColumn get name => text()();
  TextColumn get material => text().nullable()();
  TextColumn get diameter => text().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class SolarRadiation extends Table with LocalFirstColumns {
  TextColumn get stateName => text()();
  TextColumn get municipality => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get peakSunHours => real()();
  TextColumn get source => text().nullable()();
  DateTimeColumn get sourceUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CfeReceipts extends Table with LocalFirstColumns {
  TextColumn get clientId => text().references(Clients, #id)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get holderName => text().nullable()();
  TextColumn get serviceAddress => text().nullable()();
  TextColumn get serviceNumber => text().nullable()();
  TextColumn get rmu => text().nullable()();
  TextColumn get account => text().nullable()();
  TextColumn get tariff => text().nullable()();
  TextColumn get meterNumber => text().nullable()();
  IntColumn get wiresCount => integer().nullable()();
  TextColumn get billingPeriod => text().nullable()();
  RealColumn get currentPeriodKwh => real().nullable()();
  RealColumn get totalToPay => real().nullable()();
  TextColumn get originalDocumentId =>
      text().nullable().references(Documents, #id)();
  BoolColumn get isValidated => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class CfeConsumptions extends Table with LocalFirstColumns {
  TextColumn get receiptId => text().references(CfeReceipts, #id)();
  TextColumn get periodLabel => text()();
  RealColumn get kwh => real()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class PvCalculations extends Table with LocalFirstColumns {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get panelId => text().nullable().references(Panels, #id)();
  RealColumn get annualConsumptionKwh => real()();
  RealColumn get dailyConsumptionKwh => real()();
  RealColumn get peakSunHours => real()();
  RealColumn get panelPowerWatts => real()();
  RealColumn get lossFactor => real().withDefault(const Constant(0.80))();
  RealColumn get generationPerPanelKwhDay => real()();
  IntColumn get requiredPanels => integer()();
  TextColumn get calculationSnapshotJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Quotations extends Table with LocalFirstColumns {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get code => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  IntColumn get versionNumber => integer().withDefault(const Constant(1))();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(true))();
  BoolColumn get isAccepted => boolean().withDefault(const Constant(false))();
  RealColumn get ivaRate => real().withDefault(const Constant(0.16))();
  RealColumn get generalUtilityRate => real().nullable()();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get advancePaymentAmount =>
      real().withDefault(const Constant(0))();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get ivaAmount => real().withDefault(const Constant(0))();
  RealColumn get total => real().withDefault(const Constant(0))();
  TextColumn get snapshotJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class QuotationItems extends Table with LocalFirstColumns {
  TextColumn get quotationId => text().references(Quotations, #id)();
  TextColumn get itemType => text()();
  TextColumn get description => text()();
  RealColumn get quantity => real()();
  RealColumn get unitCost => real()();
  RealColumn get utilityRate => real().nullable()();
  RealColumn get unitPrice => real()();
  RealColumn get total => real()();
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  TextColumn get productSnapshotJson => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class CompanySettings extends Table with LocalFirstColumns {
  TextColumn get companyName => text()();
  TextColumn get rfc => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get logoDocumentId =>
      text().nullable().references(Documents, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettings extends Table with LocalFirstColumns {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class AuditLogs extends Table with LocalFirstColumns {
  TextColumn get entityType => text()();
  TextColumn get entityId => text().nullable()();
  TextColumn get action => text()();
  TextColumn get description => text().nullable()();
  TextColumn get payloadJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class QuotationDraftElectricalSelections extends Table with LocalFirstColumns {
  TextColumn get quotationDraftId => text().references(QuotationDrafts, #id)();
  TextColumn get inverterId => text().references(Inverters, #id)();
  RealColumn get acDistanceMeters => real().nullable()();
  RealColumn get acVoltage => real().nullable()();
  TextColumn get acMaterial => text().nullable()();
  TextColumn get acPhaseType => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class QuotationDraftCommercialQuotes extends Table with LocalFirstColumns {
  TextColumn get quotationDraftId => text().references(QuotationDrafts, #id)();

  IntColumn get versionNumber => integer().withDefault(const Constant(1))();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(true))();
  BoolColumn get isAccepted => boolean().withDefault(const Constant(false))();

  RealColumn get generalUtilityRatePercent => real()();
  RealColumn get panelUtilityRatePercent => real().nullable()();
  RealColumn get inverterUtilityRatePercent => real().nullable()();
  RealColumn get ivaRatePercent => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get advancePaymentAmount =>
      real().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('MXN'))();
  TextColumn get paymentTermsNote => text().nullable()();

  RealColumn get panelUnitCost => real()();
  RealColumn get panelUnitPrice => real()();
  IntColumn get panelQuantity => integer()();

  RealColumn get inverterUnitCost => real()();
  RealColumn get inverterUnitPrice => real()();
  IntColumn get inverterQuantity => integer()();

  RealColumn get structureMaterialsCost =>
      real().withDefault(const Constant(0))();
  RealColumn get structureMaterialsPrice =>
      real().withDefault(const Constant(0))();
  BoolColumn get structureMaterialsHasMissingPrices =>
      boolean().withDefault(const Constant(false))();

  RealColumn get subtotal => real()();
  RealColumn get ivaAmount => real()();
  RealColumn get total => real()();

  TextColumn get quotationPdfDocumentId =>
      text().nullable().references(Documents, #id)();
  DateTimeColumn get pdfGeneratedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class QuotationDraftStructureDesigns extends Table with LocalFirstColumns {
  TextColumn get quotationDraftId => text().references(QuotationDrafts, #id)();

  TextColumn get mountType => text()();
  TextColumn get fixingType => text()();
  IntColumn get structuresCount => integer()();
  IntColumn get panelsHorizontal => integer()();
  IntColumn get panelRows => integer()();
  RealColumn get inclinationDegrees => real()();
  RealColumn get frontLegCm => real()();
  TextColumn get angleMaterial =>
      text().withDefault(const Constant('steelPtr'))();

  @override
  Set<Column> get primaryKey => {id};
}

class PreInvoices extends Table with LocalFirstColumns {
  TextColumn get quotationDraftId => text().references(QuotationDrafts, #id)();

  TextColumn get clientRfc => text().nullable()();
  TextColumn get clientLegalName => text().nullable()();
  TextColumn get clientFiscalRegime => text().nullable()();
  TextColumn get clientFiscalZipCode => text().nullable()();
  TextColumn get cfdiUse => text().nullable()();
  TextColumn get paymentForm => text()();
  TextColumn get paymentMethod => text()();

  RealColumn get subtotal => real()();
  RealColumn get ivaAmount => real()();
  RealColumn get total => real()();

  TextColumn get folio => text().nullable()();
  TextColumn get pdfDocumentId =>
      text().nullable().references(Documents, #id)();
  DateTimeColumn get generatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Contracts extends Table with LocalFirstColumns {
  TextColumn get quotationDraftId => text().references(QuotationDrafts, #id)();
  TextColumn get contractText => text()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get clientSignatureDocumentId =>
      text().nullable().references(Documents, #id)();
  TextColumn get providerSignatureDocumentId =>
      text().nullable().references(Documents, #id)();
  TextColumn get contractPdfDocumentId =>
      text().nullable().references(Documents, #id)();
  DateTimeColumn get signedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table with LocalFirstColumns {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get processedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Roles,
    Users,
    Clients,
    ClientFiscalData,
    Projects,
    ProjectStatusHistory,
    Documents,
    QuotationDrafts,
    QuotationDraftConsumptions,
    QuotationDraftPvCalculations,
    Suppliers,
    Panels,
    TechnicalDocuments,
    TechnicalProductRevisions,
    TechnicalFieldEvidence,
    PanelTechnicalSpecifications,
    TechnicalInverterRevisions,
    InverterTechnicalSpecifications,
    TechnicalProductCompatibilities,
    Inverters,
    Cables,
    Conduits,
    MaterialCatalogProducts,
    SolarRadiation,
    CfeReceipts,
    CfeConsumptions,
    PvCalculations,
    Quotations,
    QuotationItems,
    QuotationDraftElectricalSelections,
    QuotationDraftCommercialQuotes,
    QuotationDraftStructureDesigns,
    Contracts,
    PreInvoices,
    CompanySettings,
    AppSettings,
    AuditLogs,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 21;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(quotationDrafts);
          }

          if (from < 3) {
            await m.addColumn(
              quotationDrafts,
              quotationDrafts.cfeTariff,
            );
            await m.addColumn(
              quotationDrafts,
              quotationDrafts.cfeBillingPeriod,
            );
            await m.addColumn(
              quotationDrafts,
              quotationDrafts.cfeCurrentPeriodKwh,
            );
            await m.addColumn(
              quotationDrafts,
              quotationDrafts.cfeTotalToPay,
            );
          }

          if (from < 4) {
            await m.createTable(
              quotationDraftConsumptions,
            );
          }

          if (from < 5) {
            await m.addColumn(
              quotationDrafts,
              quotationDrafts.analysisPeakSunHours,
            );
            await m.addColumn(
              quotationDrafts,
              quotationDrafts.analysisPanelPowerWatts,
            );
          }
          if (from < 6) {
            await m.createTable(
              quotationDraftPvCalculations,
            );
          }
          if (from < 7) {
            await m.addColumn(
              panels,
              panels.lengthMm,
            );
            await m.addColumn(
              panels,
              panels.widthMm,
            );
            await m.addColumn(
              panels,
              panels.thicknessMm,
            );
            await m.addColumn(
              panels,
              panels.isActive,
            );
          }
          if (from < 8) {
            await m.createTable(quotationDraftElectricalSelections);
            await m.createTable(quotationDraftCommercialQuotes);
          }
          if (from < 9) {
            await m.addColumn(projects, projects.installationType);
            await m.addColumn(quotationDrafts, quotationDrafts.projectId);
          }
          if (from < 10) {
            await m.addColumn(
              quotationDraftCommercialQuotes,
              quotationDraftCommercialQuotes.versionNumber,
            );
            await m.addColumn(
              quotationDraftCommercialQuotes,
              quotationDraftCommercialQuotes.isCurrent,
            );
            await m.addColumn(
              quotationDraftCommercialQuotes,
              quotationDraftCommercialQuotes.isAccepted,
            );
            await m.addColumn(
              quotationDraftCommercialQuotes,
              quotationDraftCommercialQuotes.panelUtilityRatePercent,
            );
            await m.addColumn(
              quotationDraftCommercialQuotes,
              quotationDraftCommercialQuotes.inverterUtilityRatePercent,
            );
            await m.addColumn(
              quotationDraftCommercialQuotes,
              quotationDraftCommercialQuotes.paymentTermsNote,
            );
          }
          if (from < 11) {
            await m.createTable(quotationDraftStructureDesigns);
          }
          if (from < 12) {
            await m.createTable(contracts);
          }
          if (from < 13) {
            await m.createTable(preInvoices);
          }
          if (from < 14) {
            await m.addColumn(documents, documents.quotationDraftId);
          }
          if (from < 15) {
            await m.addColumn(
              quotationDrafts,
              quotationDrafts.lastCompletedStep,
            );
          }
          if (from < 16) {
            await m.addColumn(
              quotationDraftStructureDesigns,
              quotationDraftStructureDesigns.angleMaterial,
            );
          }
          if (from < 17) {
            await m.createTable(materialCatalogProducts);
          }
          if (from < 18) {
            await m.addColumn(
              materialCatalogProducts,
              materialCatalogProducts.codigoInterno,
            );
            await m.addColumn(
              materialCatalogProducts,
              materialCatalogProducts.tipoElementoEstructura,
            );
          }
          if (from < 19) {
            await m.addColumn(
              quotationDraftCommercialQuotes,
              quotationDraftCommercialQuotes.structureMaterialsCost,
            );
            await m.addColumn(
              quotationDraftCommercialQuotes,
              quotationDraftCommercialQuotes.structureMaterialsPrice,
            );
            await m.addColumn(
              quotationDraftCommercialQuotes,
              quotationDraftCommercialQuotes.structureMaterialsHasMissingPrices,
            );
          }
          if (from < 20) {
            await m.createTable(technicalDocuments);
            await m.createTable(technicalProductRevisions);
            await m.createTable(technicalFieldEvidence);
            await m.createTable(panelTechnicalSpecifications);
            await m.createTable(technicalProductCompatibilities);
          }
          if (from < 21) {
            await m.createTable(technicalInverterRevisions);
            await m.createTable(inverterTechnicalSpecifications);
          }
        },
      );
}
