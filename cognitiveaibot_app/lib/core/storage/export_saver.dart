import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Where "Download my data" puts the export file.
abstract interface class ExportSaver {
  /// Writes [contents] as [fileName] and returns where it was saved, in
  /// words the user can follow to find it.
  Future<SavedExport> save(String fileName, String contents);
}

class SavedExport {
  const SavedExport({required this.path, required this.description});

  /// The file's full path.
  final String path;

  /// e.g. "Downloads" (macOS) or "Files › On My iPhone › Cognitiveaibot" (iOS).
  final String description;
}

/// macOS: the Downloads folder (the sandbox has the Downloads entitlement).
/// iOS: the app's Documents folder, which the Files app shows under
/// On My iPhone (UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace).
class FileExportSaver implements ExportSaver {
  const FileExportSaver();

  @override
  Future<SavedExport> save(String fileName, String contents) async {
    final Directory dir;
    final String description;
    if (!kIsWeb && Platform.isMacOS) {
      dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      description = 'Downloads';
    } else {
      dir = await getApplicationDocumentsDirectory();
      description = 'Files › On My iPhone › Cognitiveaibot';
    }
    await dir.create(recursive: true);
    final file = await _unusedFile(dir, fileName);
    await file.writeAsString(contents, flush: true);
    return SavedExport(path: file.path, description: description);
  }

  /// `name.json`, or `name (2).json` etc. when that exists already.
  static Future<File> _unusedFile(Directory dir, String fileName) async {
    final dot = fileName.lastIndexOf('.');
    final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot) : '';
    var file = File('${dir.path}/$fileName');
    for (var n = 2; await file.exists(); n++) {
      file = File('${dir.path}/$stem ($n)$ext');
    }
    return file;
  }
}
