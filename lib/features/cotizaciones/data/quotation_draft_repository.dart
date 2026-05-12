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
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String? _cleanNullableText(String? value) {
    final cleanValue = value?.trim() ?? '';
    return cleanValue.isEmpty ? null : cleanValue;
  }
}
