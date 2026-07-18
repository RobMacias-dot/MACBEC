import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../data/local/database/app_database.dart';

/// Guarda una ficha técnica dentro del almacenamiento local de la app y deja
/// su huella criptográfica para que el MEC pueda rastrear su procedencia.
class MecDocumentImporter {
  const MecDocumentImporter(this._database);

  final AppDatabase _database;

  Future<TechnicalDocument> importPdf({
    required String sourcePath,
    required MecImportedProductType productType,
  }) async {
    final source = File(sourcePath);
    final bytes = await source.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final existing = await (_database.select(_database.technicalDocuments)
          ..where((row) => row.sha256.equals(hash)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final targetDirectory = Directory(
      path.join(documentsDirectory.path, 'macbec_mec', 'datasheets'),
    );
    await targetDirectory.create(recursive: true);
    final extension = path.extension(source.path).toLowerCase();
    if (extension != '.pdf') {
      throw ArgumentError.value(sourcePath, 'sourcePath', 'Debe ser un PDF');
    }
    final storedName = '${hash.substring(0, 12)}_${path.basename(source.path)}';
    final target = File(path.join(targetDirectory.path, storedName));
    await target.writeAsBytes(bytes, flush: true);

    return _database.into(_database.technicalDocuments).insertReturning(
          TechnicalDocumentsCompanion.insert(
            source: 'Carga manual MEC - ${productType.label}',
            localPath: Value(target.path),
            fileName: source.uri.pathSegments.last,
            sha256: Value(hash),
            verificationStatus: 'pending_review',
            confidenceLevel: 'pending',
          ),
        );
  }
}

enum MecImportedProductType {
  panel('Panel solar'),
  inverter('Inversor');

  const MecImportedProductType(this.label);
  final String label;
}
