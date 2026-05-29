import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database/app_database.dart';
import '../domain/entities/quotation_draft.dart' as quotation_entity;

class CreateQuotationDraftInput {
  const CreateQuotationDraftInput({
    required this.prospectName,
    this.phone,
    this.whatsapp,
    this.email,
    this.address,
    this.notes,
  });

  final String prospectName;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? notes;
}

class AttachCfeReceiptDocumentInput {
  const AttachCfeReceiptDocumentInput({
    required this.draftId,
    required this.localPath,
    required this.fileName,
    required this.documentType,
    this.mimeType,
    this.sizeBytes,
  });

  final String draftId;
  final String localPath;
  final String fileName;
  final String documentType;
  final String? mimeType;
  final int? sizeBytes;
}

class UpdateCfeReceiptReviewInput {
  const UpdateCfeReceiptReviewInput({
    required this.draftId,
    this.holderName,
    this.serviceAddress,
    this.rpu,
    this.tariff,
    this.billingPeriod,
    this.currentPeriodKwh,
    this.totalToPay,
  });

  final String draftId;
  final String? holderName;
  final String? serviceAddress;
  final String? rpu;
  final String? tariff;
  final String? billingPeriod;
  final double? currentPeriodKwh;
  final double? totalToPay;
}

class QuotationDraftRepository {
  QuotationDraftRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Future<String> create(CreateQuotationDraftInput input) async {
    final draftId = _uuid.v4();

    await _database.into(_database.quotationDrafts).insert(
          QuotationDraftsCompanion.insert(
            id: Value(draftId),
            prospectName: input.prospectName.trim(),
            phone: Value(_cleanNullableText(input.phone)),
            whatsapp: Value(_cleanNullableText(input.whatsapp)),
            email: Value(_cleanNullableText(input.email)),
            address: Value(_cleanNullableText(input.address)),
            notes: Value(_cleanNullableText(input.notes)),
            status: const Value(
              quotation_entity.QuotationDraftStatus.receiptPending,
            ),
            hasCfeReceipt: const Value(false),
          ),
        );

    return draftId;
  }

  Future<String> attachCfeReceiptDocument(
    AttachCfeReceiptDocumentInput input,
  ) async {
    final documentId = _uuid.v4();
    final now = DateTime.now();

    return _database.transaction(() async {
      final draft = await (_database.select(_database.quotationDrafts)
            ..where(
              (table) =>
                  table.id.equals(input.draftId) &
                  table.isDeleted.equals(false),
            ))
          .getSingleOrNull();

      if (draft == null) {
        throw StateError(
          'No existe un borrador activo válido para asociar el recibo CFE.',
        );
      }

      await _database.into(_database.documents).insert(
            DocumentsCompanion.insert(
              id: Value(documentId),
              documentType: input.documentType.trim(),
              localPath: input.localPath.trim(),
              fileName: input.fileName.trim(),
              mimeType: Value(_cleanNullableText(input.mimeType)),
              sizeBytes: Value(input.sizeBytes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await (_database.update(_database.quotationDrafts)
            ..where((table) => table.id.equals(input.draftId)))
          .write(
        QuotationDraftsCompanion(
          status: const Value(
            quotation_entity.QuotationDraftStatus.receiptReceived,
          ),
          hasCfeReceipt: const Value(true),
          cfeReceiptDocumentId: Value(documentId),
          updatedAt: Value(now),
        ),
      );

      return documentId;
    });
  }

  Future<void> updateCfeReceiptReview(
    UpdateCfeReceiptReviewInput input,
  ) async {
    final now = DateTime.now();

    final draft = await (_database.select(_database.quotationDrafts)
          ..where(
            (table) =>
                table.id.equals(input.draftId) & table.isDeleted.equals(false),
          ))
        .getSingleOrNull();

    if (draft == null) {
      throw StateError(
        'No existe un borrador activo válido para actualizar la revisión CFE.',
      );
    }

    if (!draft.hasCfeReceipt || draft.cfeReceiptDocumentId == null) {
      throw StateError(
        'Primero debes guardar un recibo CFE antes de capturar la revisión.',
      );
    }

    var nextStatus = draft.status;

    if (draft.status == quotation_entity.QuotationDraftStatus.receiptPending ||
        draft.status == quotation_entity.QuotationDraftStatus.receiptReceived) {
      nextStatus = quotation_entity.QuotationDraftStatus.inAnalysis;
    }

    await (_database.update(_database.quotationDrafts)
          ..where((table) => table.id.equals(input.draftId)))
        .write(
      QuotationDraftsCompanion(
        status: Value(nextStatus),
        cfeHolderName: Value(_cleanNullableText(input.holderName)),
        cfeServiceAddress: Value(_cleanNullableText(input.serviceAddress)),
        rpu: Value(_cleanNullableText(input.rpu)),
        cfeTariff: Value(_cleanNullableText(input.tariff)),
        cfeBillingPeriod: Value(_cleanNullableText(input.billingPeriod)),
        cfeCurrentPeriodKwh: Value(input.currentPeriodKwh),
        cfeTotalToPay: Value(input.totalToPay),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<quotation_entity.QuotationDraft>> getAllActive() async {
    final query = _database.select(_database.quotationDrafts)
      ..where((draft) => draft.isDeleted.equals(false))
      ..orderBy([
        (draft) => OrderingTerm.desc(draft.createdAt),
      ]);

    final rows = await query.get();

    return rows.map(_mapRowToEntity).toList();
  }

  quotation_entity.QuotationDraft _mapRowToEntity(QuotationDraft row) {
    return quotation_entity.QuotationDraft(
      id: row.id,
      draftCode: row.draftCode,
      prospectName: row.prospectName,
      phone: row.phone,
      whatsapp: row.whatsapp,
      email: row.email,
      address: row.address,
      notes: row.notes,
      status: row.status,
      hasCfeReceipt: row.hasCfeReceipt,
      cfeReceiptDocumentId: row.cfeReceiptDocumentId,
      cfeHolderName: row.cfeHolderName,
      cfeServiceAddress: row.cfeServiceAddress,
      rpu: row.rpu,
      cfeTariff: row.cfeTariff,
      cfeBillingPeriod: row.cfeBillingPeriod,
      cfeCurrentPeriodKwh: row.cfeCurrentPeriodKwh,
      cfeTotalToPay: row.cfeTotalToPay,
      analysisPeakSunHours: row.analysisPeakSunHours,
      analysisPanelPowerWatts: row.analysisPanelPowerWatts,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String? _cleanNullableText(String? value) {
    final cleanValue = value?.trim() ?? '';
    return cleanValue.isEmpty ? null : cleanValue;
  }
}
