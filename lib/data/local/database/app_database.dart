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

  RealColumn get subtotal => real()();
  RealColumn get ivaAmount => real()();
  RealColumn get total => real()();

  TextColumn get quotationPdfDocumentId =>
      text().nullable().references(Documents, #id)();
  DateTimeColumn get pdfGeneratedAt => dateTime().nullable()();

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
    Inverters,
    Cables,
    Conduits,
    SolarRadiation,
    CfeReceipts,
    CfeConsumptions,
    PvCalculations,
    Quotations,
    QuotationItems,
    QuotationDraftElectricalSelections,
    QuotationDraftCommercialQuotes,
    CompanySettings,
    AppSettings,
    AuditLogs,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 10;

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
        },
      );
}
