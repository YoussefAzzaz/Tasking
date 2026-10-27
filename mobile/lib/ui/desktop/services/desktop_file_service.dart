import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:axis/data/powersync_db.dart';

/// Native Windows Desktop File & Storage Service.
/// Handles file exports, imports, attachments, and local database telemetry.
class DesktopFileService {
  static final DesktopFileService _instance = DesktopFileService._internal();
  factory DesktopFileService() => _instance;
  DesktopFileService._internal();

  /// Gets the formatted size of the local SQLite database file.
  /// Returns null when the database cannot be located or read — callers must
  /// render an em dash instead of inventing a value.
  Future<String?> getLocalDatabaseSize() async {
    try {
      final appSupport = await getApplicationSupportDirectory();
      final dbFile = File(p.join(appSupport.path, 'axis_local.db'));
      if (await dbFile.exists()) {
        final bytes = await dbFile.length();
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      debugPrint('[DesktopFileService] getLocalDatabaseSize error: $e');
    }
    return null;
  }

  /// Counts local content rows (tasks, habits, notes, projects, focus
  /// sessions, tags) for honest storage telemetry. Returns null when the
  /// database is unavailable.
  Future<int?> getLocalRowCount() async {
    if (!isDatabaseInitialized) return null;
    try {
      final row = await db.getOptional('''
        SELECT
          (SELECT COUNT(*) FROM tasks) +
          (SELECT COUNT(*) FROM habits) +
          (SELECT COUNT(*) FROM notes) +
          (SELECT COUNT(*) FROM projects) +
          (SELECT COUNT(*) FROM focus_sessions) +
          (SELECT COUNT(*) FROM tags) AS total
      ''');
      return (row?['total'] as num?)?.toInt();
    } catch (e) {
      debugPrint('[DesktopFileService] getLocalRowCount error: $e');
      return null;
    }
  }

  /// Exports a markdown note or journal entry directly to the user's local disk.
  Future<String?> exportMarkdownFile({
    required String title,
    required String markdownContent,
  }) async {
    try {
      final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final defaultFileName = '${sanitizedTitle.isEmpty ? "entry" : sanitizedTitle}.md';

      final bytes = Uint8List.fromList(utf8.encode(markdownContent));
      String? savePath;
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        final uri = await FilePicker.saveFile(
          dialogTitle: 'Export Markdown File',
          fileName: defaultFileName,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['md', 'txt'],
        );
        if (uri != null) {
          savePath = uri.toFilePath();
        }
      }

      if (savePath == null) {
        // Fallback to Documents/Axis_Vault folder
        final docDir = await getApplicationDocumentsDirectory();
        final vaultDir = Directory(p.join(docDir.path, 'Axis_Vault'));
        if (!await vaultDir.exists()) {
          await vaultDir.create(recursive: true);
        }
        savePath = p.join(vaultDir.path, defaultFileName);
        final file = File(savePath);
        await file.writeAsBytes(bytes);
      }
      return savePath;
    } catch (e) {
      debugPrint('[DesktopFileService] exportMarkdownFile error: $e');
      return null;
    }
  }

  /// Exports local tasks, habits, and notes as a portable JSON backup file.
  Future<String?> exportBackupJson() async {
    try {
      final uid = currentUserId;
      final tasks = await db.getAll('SELECT * FROM tasks WHERE user_id = ? OR user_id IS NULL', uid.isNotEmpty ? [uid] : []);
      final habits = await db.getAll('SELECT * FROM habits WHERE user_id = ? OR user_id IS NULL', uid.isNotEmpty ? [uid] : []);
      final notes = await db.getAll('SELECT * FROM notes WHERE user_id = ? OR user_id IS NULL', uid.isNotEmpty ? [uid] : []);

      final backupData = {
        'version': '2.4',
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'user_id': uid,
        'tasks': tasks,
        'habits': habits,
        'notes': notes,
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final defaultFileName = 'axis_backup_$timestamp.json';

      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      String? savePath;
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        final uri = await FilePicker.saveFile(
          dialogTitle: 'Save Database JSON Backup',
          fileName: defaultFileName,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (uri != null) {
          savePath = uri.toFilePath();
        }
      }

      if (savePath == null) {
        final docDir = await getApplicationDocumentsDirectory();
        final vaultDir = Directory(p.join(docDir.path, 'Axis_Vault'));
        if (!await vaultDir.exists()) {
          await vaultDir.create(recursive: true);
        }
        savePath = p.join(vaultDir.path, defaultFileName);
        final file = File(savePath);
        await file.writeAsBytes(bytes);
      }
      return savePath;
    } catch (e) {
      debugPrint('[DesktopFileService] exportBackupJson error: $e');
      return null;
    }
  }

  /// Opens a Windows native file picker to select a local file to attach.
  Future<PlatformFile?> pickLocalFileAttachment({
    List<String>? allowedExtensions,
  }) async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Select File to Attach',
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );
      if (files.isNotEmpty) {
        return files.first;
      }
    } catch (e) {
      debugPrint('[DesktopFileService] pickLocalFileAttachment error: $e');
    }
    return null;
  }

  /// Opens the Windows File Explorer to the local app documents directory.
  Future<void> openLocalVaultFolder() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory(p.join(docDir.path, 'Axis_Vault'));
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [vaultDir.path]);
      }
    } catch (e) {
      debugPrint('[DesktopFileService] openLocalVaultFolder error: $e');
    }
  }
}
