import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backup_service.dart';
import '../db_helper.dart';
import '../theme.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  String? _lastBackupInfo;

  @override
  void initState() {
    super.initState();
    _loadLastBackupInfo();
  }

  Future<void> _loadLastBackupInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _lastBackupInfo = prefs.getString('last_backup_info'));
  }

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    final result = await BackupService.createBackup();
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success && result.filePath != null) {
      final prefs = await SharedPreferences.getInstance();
      final info = '${result.filePath}|${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}';
      await prefs.setString('last_backup_info', info);
      _loadLastBackupInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    String? lastPath;
    String? lastWhen;
    if (_lastBackupInfo != null) {
      final parts = _lastBackupInfo!.split('|');
      lastPath = parts[0];
      lastWhen = parts.length > 1 ? parts[1] : null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Backup Database')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Icon(Icons.cloud_upload_outlined, size: 64, color: AppColors.accent),
                const SizedBox(height: 12),
                const Text('Create a backup of your database.', textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (lastWhen != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Last Backup', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  Text(lastWhen),
                  const SizedBox(height: 4),
                  Text(lastPath ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy ? null : _createBackup,
            child: _busy ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Backup Now'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Backups are saved wherever you choose on your device. You can then copy this file to Google Drive, email it to yourself, or store it anywhere safe.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  bool _busy = false;

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Database'),
        content: const Text('This will replace all current data with the backup data. This cannot be undone. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    final result = await BackupService.restoreBackup();
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success && mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restore Database')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Icon(Icons.cloud_download_outlined, size: 64, color: AppColors.accent),
                const SizedBox(height: 12),
                const Text('Restore your database from a backup file.', textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: _busy ? null : _restore,
            child: _busy ? const CircularProgressIndicator(color: Colors.white) : const Text('Restore Database'),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 18),
              SizedBox(width: 6),
              Expanded(
                child: Text('This will replace all current data with the backup data.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MoreScreen extends StatefulWidget {
  final void Function(int) onNavigate;
  const MoreScreen({super.key, required this.onNavigate});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  Future<void> _wipeData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erase all data?'),
        content: const Text('This deletes every position, lot, and closed trade on this device. Make sure you have a backup first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erase Everything'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DBHelper.instance.wipeAllData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data erased.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          _sectionHeader('DATA'),
          _tile(Icons.cloud_upload_outlined, 'Backup Database', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()))),
          _tile(Icons.cloud_download_outlined, 'Restore Database', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RestoreScreen()))),
          _sectionHeader('MANAGE'),
          _tile(Icons.people_outline, 'Accounts', () {}),
          _tile(Icons.settings_outlined, 'Settings', () {}),
          _sectionHeader('DANGER ZONE'),
          _tile(Icons.delete_outline, 'Erase All Data', _wipeData, color: AppColors.red),
          _sectionHeader('HELP'),
          _tile(Icons.help_outline, 'How to Use', () {}),
          _tile(Icons.info_outline, 'About App', () {}),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1)),
      );

  Widget _tile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
