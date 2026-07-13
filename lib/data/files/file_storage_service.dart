import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final fileStorageServiceProvider = Provider<FileStorageService>(
  (ref) => FileStorageService(),
);

class FileStorageService {
  Future<Directory> _baseDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'macbec_documents'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> saveBytes({
    required List<int> bytes,
    required String fileName,
    String? subfolder,
  }) async {
    final base = await _baseDirectory();
    final targetDir = subfolder == null ? base : Directory(p.join(base.path, subfolder));

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final file = File(p.join(targetDir.path, fileName));
    return file.writeAsBytes(bytes, flush: true);
  }
}
