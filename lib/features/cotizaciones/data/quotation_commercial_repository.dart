import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/local/database/database_provider.dart';
import '../domain/entities/quotation_commercial_quote.dart';
import '../domain/entities/quotation_draft.dart' show QuotationDraftStatus;

final quotationCommercialRepositoryProvider =
    Provider<QuotationCommercialRepository>((ref) {
  return QuotationCommercialRepository(ref.watch(appDatabaseProvider));
});

final quotationCommercialQuoteProvider =
    FutureProvider.family<QuotationCommercialQuote?, String>(
  (ref, quotationDraftId) async {
    return ref
        .watch(quotationCommercialRepositoryProvider)
        .getDraftQuote(quotationDraftId);
  },
);

class AttachQuotationPdfInput {
  const AttachQuotationPdfInput({
    required this.draftId,
    required this.localPath,
    required this.fileName,
    this.mimeType,
    this.sizeBytes,
  });

  final String draftId;
  final String localPath;
  final String fileName;
  final String? mimeType;
  final int? sizeBytes;
}

class QuotationCommercialRepository {
  QuotationCommercialRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Future<QuotationCommercialQuote?> getDraftQuote(
    String quotationDraftId,
  ) async {
    final query = _database.select(_database.quotationDraftCommercialQuotes)
      ..where(
        (table) =>
            table.quotationDraftId.equals(quotationDraftId) &
            table.isDeleted.equals(false),
      )
      ..orderBy([
        (table) => OrderingTerm.desc(table.updatedAt),
      ])
      ..limit(1);

    final row = await query.getSingleOrNull();

    if (row == null) return null;

    return _mapRowToEntity(row);
  }

  Future<void> upsertDraftQuote({
    required String quotationDraftId,
    required SaveQuotationCommercialQuoteInput quote,
  }) async {
    final now = DateTime.now();

    final existing = await (_database.select(
      _database.quotationDraftCommercialQuotes,
    )..where(
            (table) =>
                table.quotationDraftId.equals(quotationDraftId) &
                table.isDeleted.equals(false),
          ))
        .getSingleOrNull();

    if (existing == null) {
      await _database.into(_database.quotationDraftCommercialQuotes).insert(
            QuotationDraftCommercialQuotesCompanion.insert(
              quotationDraftId: quotationDraftId,
              generalUtilityRatePercent: quote.generalUtilityRatePercent,
              ivaRatePercent: quote.ivaRatePercent,
              discountAmount: Value(quote.discountAmount),
              advancePaymentAmount: Value(quote.advancePaymentAmount),
              currency: Value(quote.currency),
              panelUnitCost: quote.panelUnitCost,
              panelUnitPrice: quote.panelUnitPrice,
              panelQuantity: quote.panelQuantity,
              inverterUnitCost: quote.inverterUnitCost,
              inverterUnitPrice: quote.inverterUnitPrice,
              inverterQuantity: quote.inverterQuantity,
              subtotal: quote.subtotal,
              ivaAmount: quote.ivaAmount,
              total: quote.total,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } else {
      await (_database.update(_database.quotationDraftCommercialQuotes)
            ..where((table) => table.id.equals(existing.id)))
          .write(
        QuotationDraftCommercialQuotesCompanion(
          generalUtilityRatePercent: Value(quote.generalUtilityRatePercent),
          ivaRatePercent: Value(quote.ivaRatePercent),
          discountAmount: Value(quote.discountAmount),
          advancePaymentAmount: Value(quote.advancePaymentAmount),
          currency: Value(quote.currency),
          panelUnitCost: Value(quote.panelUnitCost),
          panelUnitPrice: Value(quote.panelUnitPrice),
          panelQuantity: Value(quote.panelQuantity),
          inverterUnitCost: Value(quote.inverterUnitCost),
          inverterUnitPrice: Value(quote.inverterUnitPrice),
          inverterQuantity: Value(quote.inverterQuantity),
          subtotal: Value(quote.subtotal),
          ivaAmount: Value(quote.ivaAmount),
          total: Value(quote.total),
          updatedAt: Value(now),
        ),
      );
    }

    await (_database.update(_database.quotationDrafts)
          ..where((table) => table.id.equals(quotationDraftId)))
        .write(
      QuotationDraftsCompanion(
        status: const Value(QuotationDraftStatus.quotationInProgress),
        updatedAt: Value(now),
      ),
    );
  }

  Future<String> attachGeneratedPdf(AttachQuotationPdfInput input) async {
    final documentId = _uuid.v4();
    final now = DateTime.now();

    return _database.transaction(() async {
      final quoteRow = await (_database.select(
        _database.quotationDraftCommercialQuotes,
      )..where(
              (table) =>
                  table.quotationDraftId.equals(input.draftId) &
                  table.isDeleted.equals(false),
            ))
          .getSingleOrNull();

      if (quoteRow == null) {
        throw StateError(
          'Primero guarda la cotización interna antes de generar el PDF.',
        );
      }

      await _database.into(_database.documents).insert(
            DocumentsCompanion.insert(
              id: Value(documentId),
              documentType: 'quotation_pdf',
              localPath: input.localPath,
              fileName: input.fileName,
              mimeType: Value(input.mimeType ?? 'application/pdf'),
              sizeBytes: Value(input.sizeBytes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await (_database.update(_database.quotationDraftCommercialQuotes)
            ..where((table) => table.id.equals(quoteRow.id)))
          .write(
        QuotationDraftCommercialQuotesCompanion(
          quotationPdfDocumentId: Value(documentId),
          pdfGeneratedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await (_database.update(_database.quotationDrafts)
            ..where((table) => table.id.equals(input.draftId)))
          .write(
        QuotationDraftsCompanion(
          status: const Value(QuotationDraftStatus.quotationSent),
          updatedAt: Value(now),
        ),
      );

      return documentId;
    });
  }

  QuotationCommercialQuote _mapRowToEntity(
    QuotationDraftCommercialQuote row,
  ) {
    return QuotationCommercialQuote(
      id: row.id,
      quotationDraftId: row.quotationDraftId,
      generalUtilityRatePercent: row.generalUtilityRatePercent,
      ivaRatePercent: row.ivaRatePercent,
      discountAmount: row.discountAmount,
      advancePaymentAmount: row.advancePaymentAmount,
      currency: row.currency,
      panelUnitCost: row.panelUnitCost,
      panelUnitPrice: row.panelUnitPrice,
      panelQuantity: row.panelQuantity,
      inverterUnitCost: row.inverterUnitCost,
      inverterUnitPrice: row.inverterUnitPrice,
      inverterQuantity: row.inverterQuantity,
      subtotal: row.subtotal,
      ivaAmount: row.ivaAmount,
      total: row.total,
      quotationPdfDocumentId: row.quotationPdfDocumentId,
      pdfGeneratedAt: row.pdfGeneratedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
