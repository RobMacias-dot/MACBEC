import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/local/database/database_provider.dart';
import '../domain/entities/contract.dart' as contract_entity;

final contractRepositoryProvider = Provider<ContractRepository>((ref) {
  return ContractRepository(ref.watch(appDatabaseProvider));
});

final contractByDraftProvider =
    FutureProvider.family<contract_entity.Contract?, String>(
  (ref, quotationDraftId) async {
    return ref
        .watch(contractRepositoryProvider)
        .getByDraftId(quotationDraftId);
  },
);

enum SignatureRole { client, provider }

class AttachSignatureInput {
  const AttachSignatureInput({
    required this.quotationDraftId,
    required this.role,
    required this.localPath,
    required this.fileName,
    this.mimeType,
    this.sizeBytes,
  });

  final String quotationDraftId;
  final SignatureRole role;
  final String localPath;
  final String fileName;
  final String? mimeType;
  final int? sizeBytes;
}

class ContractRepository {
  ContractRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Future<String?> getDocumentLocalPath(String documentId) async {
    final query = _database.select(_database.documents)
      ..where((table) => table.id.equals(documentId));

    final row = await query.getSingleOrNull();

    return row?.localPath;
  }

  Future<contract_entity.Contract?> getByDraftId(
    String quotationDraftId,
  ) async {
    final query = _database.select(_database.contracts)
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

  Future<void> upsertContractText({
    required String quotationDraftId,
    required String contractText,
  }) async {
    final now = DateTime.now();

    final existing = await getByDraftId(quotationDraftId);

    if (existing != null && existing.isSigned) {
      throw StateError(
        'Este contrato ya fue firmado y no puede regenerarse. '
        'Genera uno nuevo si necesitas cambiar los términos.',
      );
    }

    if (existing == null) {
      await _database.into(_database.contracts).insert(
            ContractsCompanion.insert(
              quotationDraftId: quotationDraftId,
              contractText: contractText,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      return;
    }

    await (_database.update(_database.contracts)
          ..where((table) => table.id.equals(existing.id)))
        .write(
      ContractsCompanion(
        contractText: Value(contractText),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> attachSignature(AttachSignatureInput input) async {
    final documentId = _uuid.v4();
    final now = DateTime.now();

    await _database.transaction(() async {
      final contractRow = await (_database.select(_database.contracts)
            ..where(
              (table) =>
                  table.quotationDraftId.equals(input.quotationDraftId) &
                  table.isDeleted.equals(false),
            ))
          .getSingleOrNull();

      if (contractRow == null) {
        throw StateError('Primero genera el texto del contrato.');
      }

      await _database.into(_database.documents).insert(
            DocumentsCompanion.insert(
              id: Value(documentId),
              documentType: input.role == SignatureRole.client
                  ? 'client_signature'
                  : 'provider_signature',
              localPath: input.localPath,
              fileName: input.fileName,
              mimeType: Value(input.mimeType ?? 'image/png'),
              sizeBytes: Value(input.sizeBytes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final willHaveBothSignatures = input.role == SignatureRole.client
          ? contractRow.providerSignatureDocumentId != null
          : contractRow.clientSignatureDocumentId != null;

      await (_database.update(_database.contracts)
            ..where((table) => table.id.equals(contractRow.id)))
          .write(
        ContractsCompanion(
          clientSignatureDocumentId: input.role == SignatureRole.client
              ? Value(documentId)
              : Value(contractRow.clientSignatureDocumentId),
          providerSignatureDocumentId: input.role == SignatureRole.provider
              ? Value(documentId)
              : Value(contractRow.providerSignatureDocumentId),
          status: willHaveBothSignatures
              ? const Value(contract_entity.ContractStatus.signed)
              : Value(contractRow.status),
          signedAt: willHaveBothSignatures
              ? Value(now)
              : const Value.absent(),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<String> attachContractPdf({
    required String quotationDraftId,
    required String localPath,
    required String fileName,
    String? mimeType,
    int? sizeBytes,
  }) async {
    final documentId = _uuid.v4();
    final now = DateTime.now();

    return _database.transaction(() async {
      final contractRow = await (_database.select(_database.contracts)
            ..where(
              (table) =>
                  table.quotationDraftId.equals(quotationDraftId) &
                  table.isDeleted.equals(false),
            ))
          .getSingleOrNull();

      if (contractRow == null) {
        throw StateError('Primero genera el texto del contrato.');
      }

      await _database.into(_database.documents).insert(
            DocumentsCompanion.insert(
              id: Value(documentId),
              documentType: 'contract_pdf',
              localPath: localPath,
              fileName: fileName,
              mimeType: Value(mimeType ?? 'application/pdf'),
              sizeBytes: Value(sizeBytes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await (_database.update(_database.contracts)
            ..where((table) => table.id.equals(contractRow.id)))
          .write(
        ContractsCompanion(
          contractPdfDocumentId: Value(documentId),
          updatedAt: Value(now),
        ),
      );

      return documentId;
    });
  }

  contract_entity.Contract _mapRowToEntity(Contract row) {
    return contract_entity.Contract(
      id: row.id,
      quotationDraftId: row.quotationDraftId,
      contractText: row.contractText,
      status: row.status,
      clientSignatureDocumentId: row.clientSignatureDocumentId,
      providerSignatureDocumentId: row.providerSignatureDocumentId,
      contractPdfDocumentId: row.contractPdfDocumentId,
      signedAt: row.signedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
