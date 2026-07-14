import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/local/database/database_provider.dart';
import '../domain/entities/pre_invoice.dart' as pre_invoice_entity;

final preInvoiceRepositoryProvider = Provider<PreInvoiceRepository>((ref) {
  return PreInvoiceRepository(ref.watch(appDatabaseProvider));
});

final preInvoiceByDraftProvider =
    FutureProvider.family<pre_invoice_entity.PreInvoice?, String>(
  (ref, quotationDraftId) async {
    return ref
        .watch(preInvoiceRepositoryProvider)
        .getByDraftId(quotationDraftId);
  },
);

class PreInvoiceRepository {
  PreInvoiceRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Future<pre_invoice_entity.PreInvoice?> getByDraftId(
    String quotationDraftId,
  ) async {
    final query = _database.select(_database.preInvoices)
      ..where(
        (table) =>
            table.quotationDraftId.equals(quotationDraftId) &
            table.isDeleted.equals(false),
      )
      ..limit(1);

    final row = await query.getSingleOrNull();

    if (row == null) return null;

    return _mapRowToEntity(row);
  }

  Future<void> upsert({
    required String quotationDraftId,
    required pre_invoice_entity.SavePreInvoiceInput input,
  }) async {
    final now = DateTime.now();

    final existing = await (_database.select(_database.preInvoices)
          ..where(
            (table) =>
                table.quotationDraftId.equals(quotationDraftId) &
                table.isDeleted.equals(false),
          ))
        .getSingleOrNull();

    if (existing == null) {
      await _database.into(_database.preInvoices).insert(
            PreInvoicesCompanion.insert(
              quotationDraftId: quotationDraftId,
              clientRfc: Value(_cleanNullableText(input.clientRfc)),
              clientLegalName: Value(_cleanNullableText(input.clientLegalName)),
              clientFiscalRegime:
                  Value(_cleanNullableText(input.clientFiscalRegime)),
              clientFiscalZipCode:
                  Value(_cleanNullableText(input.clientFiscalZipCode)),
              cfdiUse: Value(_cleanNullableText(input.cfdiUse)),
              paymentForm: input.paymentForm,
              paymentMethod: input.paymentMethod,
              subtotal: input.subtotal,
              ivaAmount: input.ivaAmount,
              total: input.total,
              folio: Value(_cleanNullableText(input.folio)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      return;
    }

    await (_database.update(_database.preInvoices)
          ..where((table) => table.id.equals(existing.id)))
        .write(
      PreInvoicesCompanion(
        clientRfc: Value(_cleanNullableText(input.clientRfc)),
        clientLegalName: Value(_cleanNullableText(input.clientLegalName)),
        clientFiscalRegime:
            Value(_cleanNullableText(input.clientFiscalRegime)),
        clientFiscalZipCode:
            Value(_cleanNullableText(input.clientFiscalZipCode)),
        cfdiUse: Value(_cleanNullableText(input.cfdiUse)),
        paymentForm: Value(input.paymentForm),
        paymentMethod: Value(input.paymentMethod),
        subtotal: Value(input.subtotal),
        ivaAmount: Value(input.ivaAmount),
        total: Value(input.total),
        folio: Value(_cleanNullableText(input.folio)),
        updatedAt: Value(now),
      ),
    );
  }

  Future<String> attachGeneratedPdf({
    required String quotationDraftId,
    required String localPath,
    required String fileName,
    String? mimeType,
    int? sizeBytes,
  }) async {
    final documentId = _uuid.v4();
    final now = DateTime.now();

    return _database.transaction(() async {
      final row = await (_database.select(_database.preInvoices)
            ..where(
              (table) =>
                  table.quotationDraftId.equals(quotationDraftId) &
                  table.isDeleted.equals(false),
            ))
          .getSingleOrNull();

      if (row == null) {
        throw StateError('Primero guarda los datos de la pre-factura.');
      }

      await _database.into(_database.documents).insert(
            DocumentsCompanion.insert(
              id: Value(documentId),
              documentType: 'pre_invoice_pdf',
              localPath: localPath,
              fileName: fileName,
              mimeType: Value(mimeType ?? 'application/pdf'),
              sizeBytes: Value(sizeBytes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await (_database.update(_database.preInvoices)
            ..where((table) => table.id.equals(row.id)))
          .write(
        PreInvoicesCompanion(
          pdfDocumentId: Value(documentId),
          generatedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      return documentId;
    });
  }

  pre_invoice_entity.PreInvoice _mapRowToEntity(PreInvoice row) {
    return pre_invoice_entity.PreInvoice(
      id: row.id,
      quotationDraftId: row.quotationDraftId,
      clientRfc: row.clientRfc,
      clientLegalName: row.clientLegalName,
      clientFiscalRegime: row.clientFiscalRegime,
      clientFiscalZipCode: row.clientFiscalZipCode,
      cfdiUse: row.cfdiUse,
      paymentForm: row.paymentForm,
      paymentMethod: row.paymentMethod,
      subtotal: row.subtotal,
      ivaAmount: row.ivaAmount,
      total: row.total,
      folio: row.folio,
      pdfDocumentId: row.pdfDocumentId,
      generatedAt: row.generatedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String? _cleanNullableText(String? value) {
    final cleanValue = value?.trim() ?? '';
    return cleanValue.isEmpty ? null : cleanValue;
  }
}
