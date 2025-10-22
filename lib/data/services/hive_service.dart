import 'package:hive_flutter/hive_flutter.dart';

import '../models/document_model.dart';
import '../models/expense_model.dart';
import '../models/folder_model.dart';
import '../models/notification_model.dart';

class HiveService {
  static const String _foldersBoxPrefix = 'folders';
  static const String _documentsBoxPrefix = 'documents';
  static const String _expensesBoxPrefix = 'expenses';
  static const String _notificationsBoxPrefix = 'notifications';
  static const String settingsBox = 'settings';

  static String? _currentUserId;
  static bool _isInitialized = false;

  /// Get current logged in user ID (null if no user logged in)
  static String? get currentUserId => _currentUserId;

  /// Initialize Hive (only registers adapters, doesn't open user boxes)
  static Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    // Register adapters (only once)
    try {
      Hive.registerAdapter(FolderModelAdapter());
      Hive.registerAdapter(DocumentModelAdapter());
      Hive.registerAdapter(ExpenseModelAdapter());
      Hive.registerAdapter(NotificationModelAdapter());
    } catch (e) {
      // Adapters already registered, ignore
      print('ℹ️ [Hive] Adapters already registered');
    }

    // Open global settings box (shared across users)
    if (!Hive.isBoxOpen(settingsBox)) {
      await Hive.openBox(settingsBox);
    }

    _isInitialized = true;
    print('✅ [Hive] Initialized');
  }

  /// Open boxes for a specific user
  static Future<void> openUserBoxes(String userId) async {
    if (!_isInitialized) await init();

    _currentUserId = userId;

    print('🔐 [Hive] Opening boxes for user: $userId');

    // Open user-specific boxes
    final foldersBoxName = '${_foldersBoxPrefix}_$userId';
    final documentsBoxName = '${_documentsBoxPrefix}_$userId';
    final expensesBoxName = '${_expensesBoxPrefix}_$userId';
    final notificationsBoxName = '${_notificationsBoxPrefix}_$userId';

    if (!Hive.isBoxOpen(foldersBoxName)) {
      await Hive.openBox<FolderModel>(foldersBoxName);
    }
    if (!Hive.isBoxOpen(documentsBoxName)) {
      await Hive.openBox<DocumentModel>(documentsBoxName);
    }
    if (!Hive.isBoxOpen(expensesBoxName)) {
      await Hive.openBox<ExpenseModel>(expensesBoxName);
    }
    if (!Hive.isBoxOpen(notificationsBoxName)) {
      await Hive.openBox<NotificationModel>(notificationsBoxName);
    }

    print('✅ [Hive] User boxes opened');
  }

  /// Close boxes for current user
  static Future<void> closeUserBoxes() async {
    if (_currentUserId == null) return;

    print('🔐 [Hive] Closing boxes for user: $_currentUserId');

    final foldersBoxName = '${_foldersBoxPrefix}_$_currentUserId';
    final documentsBoxName = '${_documentsBoxPrefix}_$_currentUserId';
    final expensesBoxName = '${_expensesBoxPrefix}_$_currentUserId';
    final notificationsBoxName = '${_notificationsBoxPrefix}_$_currentUserId';

    if (Hive.isBoxOpen(foldersBoxName)) {
      await Hive.box<FolderModel>(foldersBoxName).close();
    }
    if (Hive.isBoxOpen(documentsBoxName)) {
      await Hive.box<DocumentModel>(documentsBoxName).close();
    }
    if (Hive.isBoxOpen(expensesBoxName)) {
      await Hive.box<ExpenseModel>(expensesBoxName).close();
    }
    if (Hive.isBoxOpen(notificationsBoxName)) {
      await Hive.box<NotificationModel>(notificationsBoxName).close();
    }

    _currentUserId = null;
    print('✅ [Hive] User boxes closed');
  }

  /// Get user-specific box name
  static String _getUserBoxName(String boxPrefix) {
    if (_currentUserId == null) {
      throw Exception('[Hive] No user logged in. Call openUserBoxes() first.');
    }
    return '${boxPrefix}_$_currentUserId';
  }

  // Folder Operations
  static Box<FolderModel> getFoldersBox() {
    return Hive.box<FolderModel>(_getUserBoxName(_foldersBoxPrefix));
  }

  static Future<void> addFolder(FolderModel folder) async {
    final box = getFoldersBox();
    await box.put(folder.id, folder);
  }

  static FolderModel? getFolder(String id) {
    final box = getFoldersBox();
    return box.get(id);
  }

  static List<FolderModel> getAllFolders() {
    if (_currentUserId == null) return []; // Return empty list if no user
    final box = getFoldersBox();
    return box.values.toList();
  }

  static Future<void> updateFolder(FolderModel folder) async {
    final box = getFoldersBox();
    await box.put(folder.id, folder);
  }

  static Future<void> deleteFolder(String id) async {
    final box = getFoldersBox();
    await box.delete(id);
  }

  // Document Operations
  static Box<DocumentModel> getDocumentsBox() {
    return Hive.box<DocumentModel>(_getUserBoxName(_documentsBoxPrefix));
  }

  static Future<void> addDocument(DocumentModel document) async {
    final box = getDocumentsBox();
    await box.put(document.id, document);
  }

  static DocumentModel? getDocument(String id) {
    final box = getDocumentsBox();
    return box.get(id);
  }

  static List<DocumentModel> getAllDocuments() {
    if (_currentUserId == null) return []; // Return empty list if no user
    final box = getDocumentsBox();
    return box.values.toList();
  }

  static List<DocumentModel> getDocumentsByFolder(String folderId) {
    final box = getDocumentsBox();
    return box.values.where((doc) => doc.folderId == folderId).toList();
  }

  static Future<void> updateDocument(DocumentModel document) async {
    final box = getDocumentsBox();
    await box.put(document.id, document);
  }

  static Future<void> deleteDocument(String id) async {
    final box = getDocumentsBox();
    await box.delete(id);
  }

  // Expense Operations
  static Box<ExpenseModel> getExpensesBox() {
    return Hive.box<ExpenseModel>(_getUserBoxName(_expensesBoxPrefix));
  }

  static Future<void> addExpense(ExpenseModel expense) async {
    final box = getExpensesBox();
    await box.put(expense.id, expense);
  }

  static ExpenseModel? getExpense(String id) {
    final box = getExpensesBox();
    return box.get(id);
  }

  static List<ExpenseModel> getAllExpenses() {
    if (_currentUserId == null) return []; // Return empty list if no user
    final box = getExpensesBox();
    return box.values.toList();
  }

  static List<ExpenseModel> getExpensesByDateRange(
      DateTime start, DateTime end) {
    final box = getExpensesBox();
    return box.values
        .where((expense) =>
            expense.date.isAfter(start.subtract(const Duration(days: 1))) &&
            expense.date.isBefore(end.add(const Duration(days: 1))))
        .toList();
  }

  static Future<void> updateExpense(ExpenseModel expense) async {
    final box = getExpensesBox();
    await box.put(expense.id, expense);
  }

  static Future<void> deleteExpense(String id) async {
    final box = getExpensesBox();
    await box.delete(id);
  }

  // Settings Operations
  static Box getSettingsBox() {
    return Hive.box(settingsBox);
  }

  static Future<void> saveSetting(String key, dynamic value) async {
    final box = getSettingsBox();
    await box.put(key, value);
  }

  static dynamic getSetting(String key, {dynamic defaultValue}) {
    final box = getSettingsBox();
    return box.get(key, defaultValue: defaultValue);
  }

  // Notification Operations
  static Box<NotificationModel> getNotificationsBox() {
    return Hive.box<NotificationModel>(
        _getUserBoxName(_notificationsBoxPrefix));
  }

  static Future<void> addNotification(NotificationModel notification) async {
    final box = getNotificationsBox();
    await box.put(notification.id, notification);
  }

  static NotificationModel? getNotification(String id) {
    final box = getNotificationsBox();
    return box.get(id);
  }

  static List<NotificationModel> getAllNotifications() {
    final box = getNotificationsBox();
    return box.values.toList();
  }

  static Future<void> markNotificationAsRead(String id) async {
    final box = getNotificationsBox();
    final notification = box.get(id);
    if (notification != null) {
      notification.isRead = true;
      await box.put(id, notification);
    }
  }

  static Future<void> markAllNotificationsAsRead() async {
    final box = getNotificationsBox();
    for (var notification in box.values) {
      notification.isRead = true;
      await box.put(notification.id, notification);
    }
  }

  static Future<void> deleteNotification(String id) async {
    final box = getNotificationsBox();
    await box.delete(id);
  }

  static Future<void> clearOldNotifications(int daysToKeep) async {
    final box = getNotificationsBox();
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    final toDelete = box.values
        .where((n) => n.createdAt.isBefore(cutoffDate))
        .map((n) => n.id)
        .toList();

    for (var id in toDelete) {
      await box.delete(id);
    }
  }

  static int getUnreadNotificationCount() {
    if (_currentUserId == null) return 0;
    try {
      final box = getNotificationsBox();
      return box.values.where((n) => !n.isRead).length;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all data for current user (logout)
  static Future<void> clearAllData() async {
    if (_currentUserId == null) return;

    await getFoldersBox().clear();
    await getDocumentsBox().clear();
    await getExpensesBox().clear();
    await getNotificationsBox().clear();
  }

  static Future<void> close() async {
    await Hive.close();
  }
}
