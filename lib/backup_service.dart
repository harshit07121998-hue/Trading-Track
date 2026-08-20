import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'db_helper.dart';

class BackupResult {
  final bool success;
  final String message;
  final String? filePath;
  BackupResult(this.success, this.message, {this.filePath});
}

// Handles exporting the on-device SQLite file to a backup, and restoring
// from a previously exported backup file. Nothing here ever leaves the
// device unless the user explicitly shares the backup file themselves.
class BackupService {
  static Future<BackupResult> createBackup() async {
    try {
      final dbPath = await DBHelper.instance.dbPath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        return BackupResult(false, 'No database found yet — add a position first.');
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupName = 'trading_tracker_backup_$timestamp.db';

      // Flush WAL to main db file before copying, for a consistent snapshot.
      await DBHelper.instance.closeAndReopen();

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup as',
        fileName: backupName,
        type: FileType.any,
      );

      if (savePath == null) {
        return BackupResult(false, 'Backup cancelled.');
      }

      final bytes = await dbFile.readAsBytes();
      final outFile = File(savePath);
      await outFile.writeAsBytes(bytes, flush: true);

      return BackupResult(true, 'Backup saved successfully.', filePath: savePath);
    } catch (e) {
      return BackupResult(false, 'Backup failed: $e');
    }
  }

  static Future<void> shareLastBackup(String filePath) async {
    await Share.shareXFiles([XFile(filePath)], text: 'Trading Tracker backup');
  }

  static Future<BackupResult> restoreBackup() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select backup file to restore',
        type: FileType.any,
      );
      if (picked == null || picked.files.single.path == null) {
        return BackupResult(false, 'Restore cancelled.');
      }

      final sourcePath = picked.files.single.path!;
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return BackupResult(false, 'Selected file could not be read.');
      }

      final dbPath = await DBHelper.instance.dbPath();
      await DBHelper.instance.closeAndReopen(); // release file lock first
      final bytes = await sourceFile.readAsBytes();
      final dbFile = File(dbPath);
      await dbFile.writeAsBytes(bytes, flush: true);
      await DBHelper.instance.closeAndReopen(); // reopen fresh db

      return BackupResult(true, 'Database restored successfully.');
    } catch (e) {
      return BackupResult(false, 'Restore failed: $e');
    }
  }
}
