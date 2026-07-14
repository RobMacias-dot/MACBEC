import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/local/database/database_provider.dart';
import '../domain/entities/document_record.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository(ref.watch(appDatabaseProvider));
});

final documentsByProjectProvider =
    FutureProvider.family<List<DocumentRecord>, String>((ref, projectId) async {
  return ref.watch(documentsRepositoryProvider).getByProjectId(projectId);
});

class DocumentsRepository {
  DocumentsRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  /// Registro genérico para documentos que no tienen un repositorio propio
  /// (por ejemplo, propuesta técnica o PDF de estructura).
  Future<String> attachDraftDocument({
    required String quotationDraftId,
    required String documentType,
    required String localPath,
    required String fileName,
    String? mimeType,
    int? sizeBytes,
  }) async {
    final documentId = _uuid.v4();
    final now = DateTime.now();

    await _database.into(_database.documents).insert(
          DocumentsCompanion.insert(
            id: Value(documentId),
            quotationDraftId: Value(quotationDraftId),
            documentType: documentType,
            localPath: localPath,
            fileName: fileName,
            mimeType: Value(mimeType),
            sizeBytes: Value(sizeBytes),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return documentId;
  }

  Future<List<DocumentRecord>> getByDraftId(String quotationDraftId) async {
    final query = _database.select(_database.documents)
      ..where(
        (table) =>
            table.quotationDraftId.equals(quotationDraftId) &
            table.isDeleted.equals(false),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

    final rows = await query.get();

    return rows.map(_mapRowToEntity).toList();
  }

  Future<List<DocumentRecord>> getByProjectId(String projectId) async {
    final draftsQuery = _database.select(_database.quotationDrafts)
      ..where(
        (table) =>
            table.projectId.equals(projectId) & table.isDeleted.equals(false),
      );

    final drafts = await draftsQuery.get();

    if (drafts.isEmpty) return [];

    final draftIds = drafts.map((draft) => draft.id).toList();

    final documentsQuery = _database.select(_database.documents)
      ..where(
        (table) =>
            table.quotationDraftId.isIn(draftIds) &
            table.isDeleted.equals(false),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

    final rows = await documentsQuery.get();

    return rows.map(_mapRowToEntity).toList();
  }

  DocumentRecord _mapRowToEntity(Document row) {
    return DocumentRecord(
      id: row.id,
      quotationDraftId: row.quotationDraftId,
      documentType: row.documentType,
      localPath: row.localPath,
      fileName: row.fileName,
      mimeType: row.mimeType,
      sizeBytes: row.sizeBytes,
      createdAt: row.createdAt,
    );
  }
}
