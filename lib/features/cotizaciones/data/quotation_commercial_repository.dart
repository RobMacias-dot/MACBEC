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
        .getCurrentDraftQuote(quotationDraftId);
  },
);

final quotationCommercialHistoryProvider =
    FutureProvider.family<List<QuotationCommercialQuote>, String>(
  (ref, quotationDraftId) async {
    return ref
        .watch(quotationCommercialRepositoryProvider)
        .getVersionHistory(quotationDraftId);
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

  /// Devuelve la versión vigente (isCurrent) de la cotización comercial.
  Future<QuotationCommercialQuote?> getCurrentDraftQuote(
    String quotationDraftId,
  ) async {
    final query = _database.select(_database.quotationDraftCommercialQuotes)
      ..where(
        (table) =>
            table.quotationDraftId.equals(quotationDraftId) &
            table.isCurrent.equals(true) &
            table.isDeleted.equals(false),
      )
      ..limit(1);

    final row = await query.getSingleOrNull();

    if (row == null) return null;

    return _mapRowToEntity(row);
  }

  Future<List<QuotationCommercialQuote>> getVersionHistory(
    String quotationDraftId,
  ) async {
    final query = _database.select(_database.quotationDraftCommercialQuotes)
      ..where(
        (table) =>
            table.quotationDraftId.equals(quotationDraftId) &
            table.isDeleted.equals(false),
      )
      ..orderBy([
        (table) => OrderingTerm.desc(table.versionNumber),
      ]);

    final rows = await query.get();

    return rows.map(_mapRowToEntity).toList();
  }

  /// Crea una nueva versión de la cotización comercial. La versión anterior
  /// (si existe) deja de ser vigente pero se conserva para historial/auditoría.
  Future<void> createQuoteVersion({
    required String quotationDraftId,
    required SaveQuotationCommercialQuoteInput quote,
  }) async {
    final now = DateTime.now();

    await _database.transaction(() async {
      final previousCurrent = await (_database.select(
        _database.quotationDraftCommercialQuotes,
      )..where(
              (table) =>
                  table.quotationDraftId.equals(quotationDraftId) &
                  table.isCurrent.equals(true) &
                  table.isDeleted.equals(false),
            ))
          .getSingleOrNull();

      if (previousCurrent != null) {
        await (_database.update(_database.quotationDraftCommercialQuotes)
              ..where((table) => table.id.equals(previousCurrent.id)))
            .write(
          QuotationDraftCommercialQuotesCompanion(
            isCurrent: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }

      final nextVersion = (previousCurrent?.versionNumber ?? 0) + 1;

      await _database.into(_database.quotationDraftCommercialQuotes).insert(
            QuotationDraftCommercialQuotesCompanion.insert(
              quotationDraftId: quotationDraftId,
              versionNumber: Value(nextVersion),
              isCurrent: const Value(true),
              generalUtilityRatePercent: quote.generalUtilityRatePercent,
              panelUtilityRatePercent: Value(quote.panelUtilityRatePercent),
              inverterUtilityRatePercent: Value(
                quote.inverterUtilityRatePercent,
              ),
              ivaRatePercent: quote.ivaRatePercent,
              discountAmount: Value(quote.discountAmount),
              advancePaymentAmount: Value(quote.advancePaymentAmount),
              currency: Value(quote.currency),
              paymentTermsNote: Value(_cleanNullableText(quote.paymentTermsNote)),
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

      await (_database.update(_database.quotationDrafts)
            ..where((table) => table.id.equals(quotationDraftId)))
          .write(
        QuotationDraftsCompanion(
          status: const Value(QuotationDraftStatus.quotationInProgress),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Marca la versión vigente como aceptada por el cliente. No permite
  /// aceptar más de una versión a la vez: si ya había una aceptada, queda
  /// reemplazada por la nueva (solo una vigente/aceptada por cotización).
  Future<void> markCurrentAsAccepted(String quotationDraftId) async {
    final now = DateTime.now();

    final current = await getCurrentDraftQuote(quotationDraftId);

    if (current == null) {
      throw StateError(
        'No hay una cotización guardada para marcar como aceptada.',
      );
    }

    await _database.transaction(() async {
      await (_database.update(_database.quotationDraftCommercialQuotes)
            ..where((table) => table.id.equals(current.id)))
          .write(
        QuotationDraftCommercialQuotesCompanion(
          isAccepted: const Value(true),
          updatedAt: Value(now),
        ),
      );

      final draft = await (_database.select(_database.quotationDrafts)
            ..where((table) => table.id.equals(quotationDraftId)))
          .getSingleOrNull();

      await (_database.update(_database.quotationDrafts)
            ..where((table) => table.id.equals(quotationDraftId)))
          .write(
        QuotationDraftsCompanion(
          status: const Value(QuotationDraftStatus.accepted),
          updatedAt: Value(now),
        ),
      );

      // Solo una cotización vigente/aceptada por proyecto: las demás
      // cotizaciones del mismo proyecto quedan canceladas.
      final projectId = draft?.projectId;
      if (projectId == null) return;

      final siblingDrafts = await (_database.select(_database.quotationDrafts)
            ..where(
              (table) =>
                  table.projectId.equals(projectId) &
                  table.id.equals(quotationDraftId).not() &
                  table.isDeleted.equals(false),
            ))
          .get();

      for (final sibling in siblingDrafts) {
        if (sibling.status == QuotationDraftStatus.accepted ||
            sibling.status == QuotationDraftStatus.cancelled) {
          continue;
        }

        await (_database.update(_database.quotationDrafts)
              ..where((table) => table.id.equals(sibling.id)))
            .write(
          QuotationDraftsCompanion(
            status: const Value(QuotationDraftStatus.cancelled),
            updatedAt: Value(now),
          ),
        );
      }
    });
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
                  table.isCurrent.equals(true) &
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
              quotationDraftId: Value(input.draftId),
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
      versionNumber: row.versionNumber,
      isCurrent: row.isCurrent,
      isAccepted: row.isAccepted,
      generalUtilityRatePercent: row.generalUtilityRatePercent,
      panelUtilityRatePercent: row.panelUtilityRatePercent,
      inverterUtilityRatePercent: row.inverterUtilityRatePercent,
      ivaRatePercent: row.ivaRatePercent,
      discountAmount: row.discountAmount,
      advancePaymentAmount: row.advancePaymentAmount,
      currency: row.currency,
      paymentTermsNote: row.paymentTermsNote,
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

  String? _cleanNullableText(String? value) {
    final cleanValue = value?.trim() ?? '';
    return cleanValue.isEmpty ? null : cleanValue;
  }
}
