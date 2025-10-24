import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/services/automated_report_service.dart';
import '../../data/services/connectivity_monitor_service.dart';
import '../../data/services/data_clear_service.dart';
import '../../data/services/document_sync_service.dart';
import '../../data/services/expense_sync_service.dart';
import '../../data/services/folder_sync_service.dart';
import '../../data/services/hive_service.dart';
import '../../data/services/native_network_service.dart';
import '../../data/services/smart_sync_service.dart';
import '../../data/services/user_settings_sync_service.dart';
import '../../providers/app_providers.dart';
import '../logs/logs_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;
  String _autoSyncInterval = 'manual'; // manual, 6h, 8h, 12h, 24h
  bool _syncOnWifiOnly = true; // Default: WiFi only

  // Warranty Reminders
  bool _warrantyRemindersEnabled = false;
  List<int> _warrantyReminderDays = [
    30,
    7,
    1
  ]; // Default: 30, 7, and 1 day before

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final biometric =
        HiveService.getSetting('biometric_enabled', defaultValue: false);
    final notifications =
        HiveService.getSetting('notifications_enabled', defaultValue: true);
    final autoSync =
        HiveService.getSetting('auto_sync_interval', defaultValue: 'manual')
            as String;
    final wifiOnly =
        HiveService.getSetting('sync_on_wifi_only', defaultValue: true);
    final warrantyEnabled = HiveService.getSetting('warranty_reminders_enabled',
        defaultValue: false);
    final warrantyDays = HiveService.getSetting('warranty_reminder_days',
        defaultValue: [30, 7, 1]) as List;

    setState(() {
      _biometricEnabled = biometric;
      _notificationsEnabled = notifications;
      _autoSyncInterval = autoSync;
      _syncOnWifiOnly = wifiOnly;
      _warrantyRemindersEnabled = warrantyEnabled;
      _warrantyReminderDays = warrantyDays.cast<int>();
    });
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  int _getIntervalHours(String interval) {
    switch (interval) {
      case '2h':
        return 2;
      case '6h':
        return 6;
      case '8h':
        return 8;
      case '12h':
        return 12;
      case '24h':
        return 24;
      default: // 'manual'
        return 0;
    }
  }

  String _getIntervalLabel(String interval) {
    switch (interval) {
      case '2h':
        return '2 hours';
      case '6h':
        return '6 hours';
      case '8h':
        return '8 hours';
      case '12h':
        return '12 hours';
      case '24h':
        return '24 hours';
      default:
        return 'Not scheduled';
    }
  }

  Future<void> _performSync() async {
    try {
      print('🔄 [Sync] Starting full sync...');

      // Sync folders
      print('📤 [Sync] Syncing folders...');
      await FolderSyncService.syncAllFoldersToMongoDB();

      // Sync documents
      print('📤 [Sync] Syncing documents...');
      await DocumentSyncService.syncAllDocumentsToMongoDB();

      // Sync expenses
      print('📤 [Sync] Syncing expenses...');
      await ExpenseSyncService().syncAllExpensesToMongoDB();

      print('✅ [Sync] Upload complete');

      // Save backup time (for both manual and scheduled)
      final syncTime = DateTime.now();
      await HiveService.saveSetting(
          'last_sync_time', syncTime.millisecondsSinceEpoch);

      // Also save as last backup time (shown in settings)
      await HiveService.saveSetting(
          'last_backup_time', syncTime.millisecondsSinceEpoch);

      // Update sync time in MongoDB user settings
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await UserSettingsSyncService.updateSetting(
          userId: user.uid,
          lastSyncTime: syncTime,
        );
      }

      print('✅ [Sync] Backup complete at ${syncTime.toString()}');
    } catch (e) {
      print('❌ [Sync] Error: $e');
      rethrow; // Re-throw so caller can handle the error
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isDarkMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // User Profile Section
          if (user != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  user.displayName?.substring(0, 1).toUpperCase() ??
                      user.email?.substring(0, 1).toUpperCase() ??
                      'U',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(user.displayName ?? 'User'),
              subtitle: Text(user.email ?? ''),
            ),

          const Divider(),

          // Appearance Section
          _buildSectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme'),
            value: isDarkMode,
            onChanged: (value) async {
              ref.read(themeModeProvider.notifier).setDarkMode(value);

              // Sync setting to MongoDB
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await UserSettingsSyncService.updateSetting(
                  userId: user.uid,
                  isDarkMode: value,
                );
              }
            },
            secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
          ),

          const Divider(),

          // Security Section
          _buildSectionHeader('Security'),
          SwitchListTile(
            title: const Text('Biometric Lock'),
            subtitle: const Text('Use fingerprint or face to unlock'),
            value: _biometricEnabled,
            onChanged: (value) async {
              if (value) {
                try {
                  // Check if biometric is available
                  final canCheckBiometrics =
                      await _localAuth.canCheckBiometrics;
                  final isDeviceSupported =
                      await _localAuth.isDeviceSupported();

                  if (!canCheckBiometrics && !isDeviceSupported) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Biometric authentication not available on this device'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  // Check if credentials are already saved (from login)
                  final secureStorage = const FlutterSecureStorage();
                  final savedEmail =
                      await secureStorage.read(key: 'saved_email');

                  if (savedEmail == null) {
                    // No credentials saved, inform user
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '⚠️ Please enable biometric during login. Credentials must be saved securely.'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 4),
                      ),
                    );
                    return;
                  }

                  // Try to authenticate
                  if (!mounted) return;

                  final authenticated = await _localAuth.authenticate(
                    localizedReason:
                        'Enable biometric authentication for app security',
                    options: const AuthenticationOptions(
                      stickyAuth: false,
                      biometricOnly: false, // Allow PIN/pattern as fallback
                      useErrorDialogs: true,
                      sensitiveTransaction: false,
                    ),
                  );

                  if (authenticated && mounted) {
                    setState(() => _biometricEnabled = true);
                    await HiveService.saveSetting('biometric_enabled', true);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Text('Biometric lock enabled'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Could not enable biometric: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                // Disable biometric - clear saved credentials
                setState(() => _biometricEnabled = false);
                await HiveService.saveSetting('biometric_enabled', false);

                // Clear saved credentials from secure storage
                final secureStorage = FlutterSecureStorage();
                await secureStorage.delete(key: 'saved_email');
                await secureStorage.delete(key: 'saved_password');

                // 🔧 FIX: Reset the prompt flag so user can be prompted again on next login
                await HiveService.saveSetting('biometric_prompt_shown', false);
                print(
                    '🔒 [Settings] Reset biometric_prompt_shown to allow re-prompting on next login');

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Biometric lock disabled'),
                  ),
                );
              }
            },
            secondary: const Icon(Icons.fingerprint),
          ),

          const Divider(),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive alerts and reminders'),
            value: _notificationsEnabled,
            onChanged: (value) async {
              setState(() => _notificationsEnabled = value);
              await HiveService.saveSetting('notifications_enabled', value);

              // Sync setting to MongoDB
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await UserSettingsSyncService.updateSetting(
                  userId: user.uid,
                  notificationsEnabled: value,
                );
              }
            },
            secondary: const Icon(Icons.notifications_outlined),
          ),
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('Warranty Reminders'),
            subtitle: Text(_warrantyRemindersEnabled
                ? 'Enabled (${_warrantyReminderDays.length} reminder${_warrantyReminderDays.length != 1 ? 's' : ''})'
                : 'Get notified before expiry'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showWarrantyRemindersSettings(context);
            },
          ),

          const Divider(),

          // Data & Storage Section
          _buildSectionHeader('Data & Storage'),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('View App Logs'),
            subtitle: const Text('Debug information and activity'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LogsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Storage Usage'),
            subtitle: const Text('View local storage details'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showStorageInfo(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup, color: Colors.green),
            title: const Text('Automatic Backup'),
            subtitle: Text(_autoSyncInterval != 'manual'
                ? 'Scheduled every ${_getIntervalLabel(_autoSyncInterval)}'
                : 'Manual backup only'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showAutomaticBackupSettings(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export Data'),
            subtitle: const Text('Download all data as CSV'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _exportData(context);
            },
          ),

          const Divider(),

          // Automated Reports Section
          _buildSectionHeader('Automated Reports'),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email Reports'),
            subtitle: const Text('Receive expense reports via email'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showAutomatedReportsSettings(context);
            },
          ),

          const Divider(),

          // About Section
          _buildSectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outlined),
            title: const Text('About App'),
            subtitle: const Text('Version 1.0.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showAboutDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to help
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to privacy policy
            },
          ),

          const Divider(),

          // Danger Zone
          _buildSectionHeader('Danger Zone'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Data',
                style: TextStyle(color: Colors.red)),
            subtitle:
                const Text('Delete all data from local and cloud storage'),
            onTap: () {
              _showClearDataConfirmation(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red)),
            onTap: () {
              _showLogoutConfirmation(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _showStorageInfo(BuildContext context) {
    final folders = ref.read(foldersProvider);
    final documents = ref.read(documentsProvider);
    final expenses = ref.read(expensesProvider);

    // Calculate total file size
    int totalSize = 0;
    int documentFilesCount = 0;

    for (var doc in documents) {
      try {
        final file = File(doc.localImagePath);
        if (file.existsSync()) {
          totalSize += file.lengthSync();
          documentFilesCount++;
        }
      } catch (e) {
        // Skip files that can't be accessed
      }
    }

    // Format size to human-readable format
    String formatBytes(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(2)} KB';
      }
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.storage),
              SizedBox(width: 12),
              Text('Storage Usage'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total Size Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.folder_special,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Total Storage Used',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatBytes(totalSize),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Detailed breakdown
                _buildStorageRow(
                  context,
                  Icons.folder,
                  'Folders',
                  '${folders.length}',
                  null,
                ),
                const SizedBox(height: 12),
                _buildStorageRow(
                  context,
                  Icons.description,
                  'Documents',
                  '${documents.length}',
                  '$documentFilesCount files',
                ),
                const SizedBox(height: 12),
                _buildStorageRow(
                  context,
                  Icons.receipt_long,
                  'Expenses',
                  '${expenses.length}',
                  null,
                ),
                const SizedBox(height: 12),
                _buildStorageRow(
                  context,
                  Icons.image,
                  'Document Images',
                  formatBytes(totalSize),
                  '$documentFilesCount images',
                ),

                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.blue, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Data is automatically backed up to cloud database when you make changes.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStorageRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    String? subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    // TODO: Implement data export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon')),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Pocket Organizer',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.folder_special, size: 48),
      children: [
        const Text('A complete document organizer and expense tracker app.'),
      ],
    );
  }

  void _showClearDataConfirmation(BuildContext context) async {
    // Get data counts
    final counts = DataClearService.getDataCounts();
    final totalItems =
        counts['folders']! + counts['documents']! + counts['expenses']!;

    // Step 1: Show warning dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 12),
              const Text('Clear All Data?'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'DANGER: This action cannot be undone!',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This will permanently delete ALL your data from:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone_android, size: 16),
                          const SizedBox(width: 8),
                          const Text('Local device storage'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.cloud, size: 16),
                          const SizedBox(width: 8),
                          const Text('Cloud database (MongoDB)'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Items to be deleted:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildCountRow('Folders', counts['folders']!),
                _buildCountRow('Documents', counts['documents']!),
                _buildCountRow('Expenses', counts['expenses']!),
                const Divider(),
                _buildCountRow('Total', totalItems, isBold: true),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You will need to authenticate with your password or fingerprint to proceed.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    // Step 2: Authenticate user
    final authenticated = await _authenticateUser();
    if (!authenticated || !context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Authentication failed - data not deleted'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Step 3: Show progress dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Deleting all data...'),
              SizedBox(height: 8),
              Text(
                'This may take a moment',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );

    // Step 4: Clear all data
    final result = await DataClearService.clearAllData();

    // Close progress dialog
    if (context.mounted) {
      Navigator.pop(context);
    }

    // Step 5: Show result and reload providers
    if (context.mounted) {
      if (result['success']) {
        // Reload all providers
        await ref.read(foldersProvider.notifier).loadFolders();
        await ref.read(documentsProvider.notifier).loadDocuments();
        await ref.read(expensesProvider.notifier).loadExpenses();

        final localDeleted = result['localItemsDeleted'] ?? 0;
        final cloudDeleted = result['cloudItemsDeleted'] ?? 0;
        final totalDeleted =
            result['totalItemsDeleted'] ?? (localDeleted + cloudDeleted);
        final isPartialSuccess = result['partialSuccess'] == true;
        final warning = result['warning'];

        if (isPartialSuccess && warning != null) {
          // Show partial success warning
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Partial Success'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📱 Local: $localDeleted items deleted\n☁️ Cloud: Failed to delete\n\n⚠️ $warning',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        } else {
          // Show full success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('All data deleted successfully!'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📱 Local: $localDeleted items\n☁️ Cloud: $cloudDeleted items\n✅ Total: $totalDeleted items',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${result['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildCountRow(String label, int count, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: count > 0 ? Colors.red : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _authenticateUser() async {
    try {
      // Check if biometric is enabled and available
      final biometricEnabled =
          HiveService.getSetting('biometric_enabled', defaultValue: false)
              as bool;

      if (biometricEnabled) {
        // Try biometric authentication first
        try {
          final authenticated = await _localAuth.authenticate(
            localizedReason: 'Authenticate to delete all data',
            options: const AuthenticationOptions(
              stickyAuth: true,
              biometricOnly: false, // Allow PIN/pattern as fallback
              useErrorDialogs: true,
              sensitiveTransaction: true,
            ),
          );

          if (authenticated) {
            print('✅ [ClearData] Authenticated via biometric');
            return true;
          }
        } catch (e) {
          print('⚠️ [ClearData] Biometric auth failed: $e');
          // Fall through to password authentication
        }
      }

      // Fallback to password authentication
      if (!mounted) return false;

      final password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final passwordController = TextEditingController();
          return AlertDialog(
            title: const Text('Enter Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please enter your account password to confirm deletion:',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    Navigator.pop(context, value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, passwordController.text);
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (password == null || password.isEmpty) {
        print('⚠️ [ClearData] Password authentication cancelled');
        return false;
      }

      // Verify password with Firebase
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        print('❌ [ClearData] No user logged in');
        return false;
      }

      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        print('✅ [ClearData] Authenticated via password');
        return true;
      } catch (e) {
        print('❌ [ClearData] Password authentication failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incorrect password'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    } catch (e) {
      print('❌ [ClearData] Authentication error: $e');
      return false;
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    // Check last sync time
    final lastSyncTimestamp =
        HiveService.getSetting('last_sync_time', defaultValue: 0) as int;
    final lastSync = lastSyncTimestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp)
        : null;

    final bool hasRecentSync =
        lastSync != null && DateTime.now().difference(lastSync).inHours < 24;

    // Check if there are pending changes in the queue (NEW!)
    final bool hasPendingChanges = SmartSyncService.hasPendingChanges;

    // Show sync warning if: no recent sync OR has pending changes
    final bool needsSync = !hasRecentSync || hasPendingChanges;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                needsSync ? Icons.warning_amber_rounded : Icons.logout,
                color: needsSync ? Colors.orange : Colors.blue,
              ),
              const SizedBox(width: 12),
              const Text('Log Out?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (needsSync) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasPendingChanges
                              ? 'You have unsaved changes!'
                              : lastSync == null
                                  ? 'You haven\'t synced your data yet!'
                                  : 'Last sync: ${_formatTimeDifference(lastSync)}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '⚠️ Your local data will be cleared after logout.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unsynchronized changes may be lost. We recommend syncing before logging out.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ] else ...[
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last synced: ${_formatTimeDifference(lastSync)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your data is safely backed up to the cloud.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (needsSync)
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  // Trigger sync first
                  await _performSync();
                  // Then show logout dialog again
                  if (context.mounted) {
                    _showLogoutConfirmation(context);
                  }
                },
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Sync & Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                // Clear local data
                await HiveService.clearAllData();

                // Close user-specific boxes
                await HiveService.closeUserBoxes();

                // Stop connectivity monitoring
                ConnectivityMonitorService.stopMonitoring();

                // Sign out from Firebase
                await ref.read(authServiceProvider).signOut();

                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text(needsSync ? 'Logout Anyway' : 'Log Out'),
            ),
          ],
        );
      },
    );
  }

  String _formatTimeDifference(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return DateFormat('MMM d, y').format(dateTime);
  }

  void _showAutomatedReportsSettings(BuildContext context) {
    // Get current settings
    bool dailyEnabled =
        HiveService.getSetting('daily_report_enabled', defaultValue: false)
            as bool;
    bool weeklyEnabled =
        HiveService.getSetting('weekly_report_enabled', defaultValue: false)
            as bool;
    bool monthlyEnabled =
        HiveService.getSetting('monthly_report_enabled', defaultValue: false)
            as bool;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.email_outlined, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('Automated Email Reports'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Receive automated expense reports via email',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    // Daily Report
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Daily Reports'),
                      subtitle: const Text('Sent every day at 9:00 AM'),
                      value: dailyEnabled,
                      onChanged: (value) async {
                        setState(() => dailyEnabled = value);
                        await HiveService.saveSetting(
                            'daily_report_enabled', value);
                        // Schedule or cancel daily reports using native AlarmManager
                        if (value) {
                          await NativeNetworkService.scheduleDailyEmailReport(
                              hour: 9, minute: 0); // 9:00 AM production
                        } else {
                          await NativeNetworkService.cancelDailyEmailReport();
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value
                                  ? '✅ Daily reports enabled'
                                  : '🛑 Daily reports disabled'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(),

                    // Weekly Report
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Weekly Reports'),
                      subtitle: const Text('Sent every Monday at 9:00 AM'),
                      value: weeklyEnabled,
                      onChanged: (value) async {
                        setState(() => weeklyEnabled = value);
                        await HiveService.saveSetting(
                            'weekly_report_enabled', value);
                        // Schedule or cancel weekly reports
                        await AutomatedReportService.scheduleWeeklyReport(
                            enabled: value);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value
                                  ? '✅ Weekly reports enabled'
                                  : '🛑 Weekly reports disabled'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(),

                    // Monthly Report
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Monthly Reports'),
                      subtitle:
                          const Text('Sent on 1st of every month at 9:00 AM'),
                      value: monthlyEnabled,
                      onChanged: (value) async {
                        setState(() => monthlyEnabled = value);
                        await HiveService.saveSetting(
                            'monthly_report_enabled', value);
                        // Schedule or cancel monthly reports
                        await AutomatedReportService.scheduleMonthlyReport(
                            enabled: value);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value
                                  ? '✅ Monthly reports enabled'
                                  : '🛑 Monthly reports disabled'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      // child: Row(
                      //   crossAxisAlignment: CrossAxisAlignment.start,
                      //   children: [
                      //     const Icon(Icons.info_outline,
                      //         color: Colors.blue, size: 20),
                      //     const SizedBox(width: 12),
                      //     Expanded(
                      //       child: Column(
                      //         crossAxisAlignment: CrossAxisAlignment.start,
                      //         children: [
                      //           const Text(
                      //             'Setup Required',
                      //             style: TextStyle(
                      //               fontWeight: FontWeight.bold,
                      //               color: Colors.blue,
                      //             ),
                      //           ),
                      //           const SizedBox(height: 4),
                      //           Text(
                      //             'Configure SMTP email settings in your .env file to enable automated reports. See ENV_SETUP.md for instructions.',
                      //             style: TextStyle(
                      //               fontSize: 12,
                      //               color: Colors.blue.shade700,
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   ],
                      // ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBackupScheduleOption(
    StateSetter setDialogState,
    String title,
    String subtitle,
    String value,
    IconData icon,
  ) {
    final isSelected = _autoSyncInterval == value;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.green : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: RadioListTile<String>(
        title: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? Colors.green : Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.green.shade900 : Colors.black87,
              ),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
          ),
        ),
        value: value,
        groupValue: _autoSyncInterval,
        onChanged: (String? newValue) async {
          if (newValue != null) {
            setDialogState(() {
              _autoSyncInterval = newValue;
            });
            setState(() {
              _autoSyncInterval = newValue;
            });
            await HiveService.saveSetting('auto_sync_interval', newValue);

            // Schedule auto-sync with native AlarmManager (like WhatsApp)
            if (newValue == 'manual') {
              // Disable auto-sync
              await NativeNetworkService.cancelPeriodicBackup();
            } else {
              // Parse interval to minutes
              int intervalMinutes;
              if (newValue == '2h') {
                intervalMinutes = 120; // 2 hours
              } else if (newValue == '6h') {
                intervalMinutes = 360; // 6 hours
              } else if (newValue == '8h') {
                intervalMinutes = 480; // 8 hours
              } else if (newValue == '12h') {
                intervalMinutes = 720; // 12 hours
              } else if (newValue == '24h') {
                intervalMinutes = 1440; // 24 hours
              } else {
                intervalMinutes = 360; // Default to 6 hours
              }

              // Check if exact alarm permission is granted (Android 12+)
              final canSchedule =
                  await NativeNetworkService.canScheduleExactAlarms();

              if (!canSchedule) {
                // Permission not granted - show dialog
                if (context.mounted) {
                  final shouldOpenSettings = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.alarm, color: Colors.orange),
                          SizedBox(width: 12),
                          Text('Permission Required'),
                        ],
                      ),
                      content: const Text(
                        'To enable automatic backups, Pocket Organizer needs permission to schedule exact alarms.\n\n'
                        'This ensures your data is backed up precisely at your chosen interval (e.g., every 2 hours).\n\n'
                        'Tap "Grant Permission" to open system settings.',
                        style: TextStyle(fontSize: 15, height: 1.4),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.settings),
                          label: const Text('Grant Permission'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );

                  if (shouldOpenSettings == true) {
                    await NativeNetworkService.requestExactAlarmPermission();

                    // Show info message
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '✅ Please enable "Alarms & reminders" permission, then return to the app',
                          ),
                          duration: Duration(seconds: 5),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                }
              }

              // Schedule with native AlarmManager
              await NativeNetworkService.schedulePeriodicBackup(
                intervalMinutes,
                wifiOnly: _syncOnWifiOnly,
              );
            }

            // Sync setting to MongoDB
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await UserSettingsSyncService.updateSetting(
                userId: user.uid,
                autoSyncInterval: _getIntervalHours(newValue),
              );
            }

            // Show confirmation
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Auto backup set to: $title'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        },
        activeColor: Colors.green,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  void _showAutomaticBackupSettings(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.backup, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Text('Automatic Backup'),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Backup status
                      FutureBuilder<int>(
                        future: Future.value(
                          HiveService.getSetting('last_backup_time',
                              defaultValue: 0) as int,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final lastBackupTime = snapshot.data ?? 0;
                          if (lastBackupTime > 0) {
                            final backupDate =
                                DateTime.fromMillisecondsSinceEpoch(
                                    lastBackupTime);
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Last Backup',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getRelativeTime(backupDate),
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy hh:mm a')
                                        .format(backupDate),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber,
                                      color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'No scheduled backup yet. Enable automatic backup below.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 24),

                      // Backup Now button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  setState(() => isLoading = true);

                                  try {
                                    await _performSync();

                                    // Rebuild the modal to show updated time
                                    setState(() => isLoading = false);

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.check_circle,
                                                  color: Colors.white),
                                              SizedBox(width: 12),
                                              Text(
                                                  'Backup completed successfully!'),
                                            ],
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.error,
                                                  color: Colors.white),
                                              const SizedBox(width: 12),
                                              Text(
                                                  'Backup failed: ${e.toString()}'),
                                            ],
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.backup, size: 24),
                          label: Text(
                            isLoading ? 'Backing up...' : 'Backup Now',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Backup Schedule Section
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              color: Colors.grey.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Backup Schedule',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose how often to automatically backup your data',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),

                      // Schedule options
                      _buildBackupScheduleOption(
                          setState,
                          'Manual Only',
                          'Backup only when you tap "Backup Now"',
                          'manual',
                          Icons.touch_app_outlined),
                      _buildBackupScheduleOption(setState, 'Every 2 hours',
                          '12 times a day', '2h', Icons.access_time),
                      _buildBackupScheduleOption(setState, 'Every 6 hours',
                          '4 times a day', '6h', Icons.access_time),
                      _buildBackupScheduleOption(setState, 'Every 8 hours',
                          '3 times a day', '8h', Icons.access_time),
                      _buildBackupScheduleOption(setState, 'Every 12 hours',
                          '2 times a day', '12h', Icons.schedule),
                      _buildBackupScheduleOption(setState, 'Once a day',
                          'Daily at midnight', '24h', Icons.calendar_today),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // WiFi-Only Toggle Section
                      Row(
                        children: [
                          Icon(Icons.wifi,
                              color: Colors.grey.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Network Preference',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: _syncOnWifiOnly
                              ? Colors.green.shade50
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _syncOnWifiOnly
                                ? Colors.green
                                : Colors.grey.shade300,
                            width: _syncOnWifiOnly ? 2 : 1,
                          ),
                        ),
                        child: SwitchListTile(
                          title: const Row(
                            children: [
                              Icon(Icons.wifi, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'WiFi Only',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            _syncOnWifiOnly
                                ? 'Backup only when connected to WiFi'
                                : 'Backup on WiFi or mobile data',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: _syncOnWifiOnly,
                          onChanged: (bool value) async {
                            setState(() {
                              _syncOnWifiOnly = value;
                            });

                            // Save to Hive
                            await HiveService.saveSetting(
                                'sync_on_wifi_only', value);

                            // Sync to MongoDB
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await UserSettingsSyncService.updateSetting(
                                userId: user.uid,
                                syncOnWifiOnly: value,
                              );
                            }

                            // If auto-sync is enabled, reschedule with new WiFi constraint
                            if (_autoSyncInterval != 'manual') {
                              int intervalMinutes;
                              if (_autoSyncInterval == '2h') {
                                intervalMinutes = 120;
                              } else if (_autoSyncInterval == '6h') {
                                intervalMinutes = 360;
                              } else if (_autoSyncInterval == '8h') {
                                intervalMinutes = 480;
                              } else if (_autoSyncInterval == '12h') {
                                intervalMinutes = 720;
                              } else if (_autoSyncInterval == '24h') {
                                intervalMinutes = 1440;
                              } else {
                                intervalMinutes = 360;
                              }

                              // Reschedule with new WiFi constraint
                              await NativeNetworkService.schedulePeriodicBackup(
                                intervalMinutes,
                                wifiOnly: value,
                              );
                            }

                            // Show confirmation
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    value
                                        ? '✅ Backup will only happen on WiFi'
                                        : '✅ Backup will happen on WiFi or mobile data',
                                  ),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          activeColor: Colors.green,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Info note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.blue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'How it works',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '• Your data is automatically backed up to the cloud\n'
                                    '• Login on any device to restore your data\n'
                                    '• Backup includes: expenses, documents, folders, settings\n'
                                    '• Images are stored separately in S3 (always available)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showWarrantyRemindersSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.alarm, color: Colors.orange),
                  SizedBox(width: 12),
                  Text('Warranty Reminders'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Get notified before your warranties expire',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),

                      // Enable/Disable Toggle
                      SwitchListTile(
                        title: const Text('Enable Reminders'),
                        subtitle: const Text(
                            'Receive notifications for expiring documents'),
                        value: _warrantyRemindersEnabled,
                        onChanged: (bool value) {
                          setDialogState(() {
                            _warrantyRemindersEnabled = value;
                          });
                          setState(() {
                            _warrantyRemindersEnabled = value;
                          });
                          HiveService.saveSetting(
                              'warranty_reminders_enabled', value);

                          // Sync to MongoDB for trigger to read
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            UserSettingsSyncService.updateSetting(
                              userId: user.uid,
                              warrantyRemindersEnabled: value,
                            );
                            print(
                                '✅ [Settings] Warranty reminders ${value ? 'enabled' : 'disabled'} and synced to MongoDB');
                          }
                        },
                      ),

                      if (_warrantyRemindersEnabled) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Remind me:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Reminder day options
                        _buildReminderDayCheckbox(
                          setDialogState,
                          30,
                          '30 days before',
                          'One month notice',
                          Icons.calendar_month,
                          Colors.green,
                        ),
                        _buildReminderDayCheckbox(
                          setDialogState,
                          14,
                          '14 days before',
                          'Two weeks notice',
                          Icons.calendar_today,
                          Colors.blue,
                        ),
                        _buildReminderDayCheckbox(
                          setDialogState,
                          7,
                          '7 days before',
                          'One week notice',
                          Icons.event,
                          Colors.orange,
                        ),
                        _buildReminderDayCheckbox(
                          setDialogState,
                          1,
                          '1 day before',
                          'Last day warning',
                          Icons.warning,
                          Colors.red,
                        ),

                        const SizedBox(height: 16),

                        // Info note
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.orange, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'How it works',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '• Set expiry dates on your documents\n'
                                      '• Get push notifications at selected intervals\n'
                                      '• Receive daily email digest of expiring items\n'
                                      '• View expiring documents on home page',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReminderDayCheckbox(
    StateSetter setDialogState,
    int days,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final bool isSelected = _warrantyReminderDays.contains(days);

    return CheckboxListTile(
      value: isSelected,
      onChanged: (bool? value) {
        setDialogState(() {
          if (value == true) {
            _warrantyReminderDays.add(days);
            _warrantyReminderDays
                .sort((a, b) => b.compareTo(a)); // Sort descending
          } else {
            _warrantyReminderDays.remove(days);
          }
        });
        setState(() {
          // Update main state
        });
        HiveService.saveSetting(
            'warranty_reminder_days', _warrantyReminderDays);

        // Sync to MongoDB for trigger to read
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          UserSettingsSyncService.updateSetting(
            userId: user.uid,
            warrantyReminderDays: _warrantyReminderDays,
          );
          print(
              '✅ [Settings] Warranty reminder days updated: $_warrantyReminderDays and synced to MongoDB');
        }
      },
      title: Text(title),
      subtitle: Text(subtitle),
      secondary: Icon(icon, color: color),
    );
  }
}
