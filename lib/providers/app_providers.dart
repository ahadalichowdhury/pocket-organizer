import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/document_model.dart';
import '../data/models/expense_model.dart';
import '../data/models/folder_model.dart';
import '../data/repositories/document_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/folder_repository.dart';
import '../data/services/auth_service.dart';
import '../data/services/document_sync_service.dart';
import '../data/services/folder_sync_service.dart';
import '../data/services/hive_service.dart';
import '../data/services/local_auth_service.dart';

// Services
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final localAuthServiceProvider =
    Provider<LocalAuthService>((ref) => LocalAuthService());

// Repositories
final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository();
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final folderRepository = ref.watch(folderRepositoryProvider);
  return DocumentRepository(folderRepository);
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

// Auth State
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) => user,
    orElse: () => null,
  );
});

// Folders
final foldersProvider =
    StateNotifierProvider<FoldersNotifier, List<FolderModel>>((ref) {
  final repository = ref.watch(folderRepositoryProvider);
  return FoldersNotifier(repository);
});

class FoldersNotifier extends StateNotifier<List<FolderModel>> {
  final FolderRepository _repository;

  FoldersNotifier(this._repository) : super([]) {
    loadFolders();
  }

  Future<void> loadFolders() async {
    state = _repository.getAllFolders();
  }

  Future<void> initializeDefaultFolders() async {
    await _repository.initializeDefaultFolders();
    await loadFolders();
  }

  Future<FolderModel> createFolder({
    required String name,
    String? description,
    String? iconName,
  }) async {
    final folder = await _repository.createFolder(
      name: name,
      description: description,
      iconName: iconName,
    );
    await loadFolders();
    return folder;
  }

  Future<void> updateFolder(FolderModel folder) async {
    await _repository.updateFolder(folder);
    await loadFolders();
  }

  Future<bool> deleteFolder(String folderId) async {
    try {
      final success = await _repository.deleteFolder(folderId);
      if (success) {
        await loadFolders();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Sync folders from MongoDB
  Future<void> syncFromMongoDB() async {
    await FolderSyncService.performFullSync();
    await loadFolders();
  }

  /// Perform full sync (upload and download)
  Future<void> performFullSync() async {
    await FolderSyncService.performFullSync();
    await loadFolders();
  }
}

// Documents
final documentsProvider =
    StateNotifierProvider<DocumentsNotifier, List<DocumentModel>>((ref) {
  final repository = ref.watch(documentRepositoryProvider);
  return DocumentsNotifier(
    repository,
    () => ref.read(foldersProvider.notifier).loadFolders(),
  );
});

class DocumentsNotifier extends StateNotifier<List<DocumentModel>> {
  final DocumentRepository _repository;
  final Future<void> Function() _refreshFolders;

  DocumentsNotifier(this._repository, this._refreshFolders) : super([]) {
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    state = _repository.getAllDocuments();
  }

  List<DocumentModel> getDocumentsByFolder(String folderId) {
    return _repository.getDocumentsByFolder(folderId);
  }

  Future<DocumentModel> createDocument({
    required String title,
    required String folderId,
    required String localImagePath,
    required String documentType,
    String? ocrText,
    List<String>? tags,
    double? classificationConfidence,
    DateTime? expiryDate,
    String? notes,
  }) async {
    final document = await _repository.createDocument(
      title: title,
      folderId: folderId,
      localImagePath: localImagePath,
      documentType: documentType,
      ocrText: ocrText,
      tags: tags,
      classificationConfidence: classificationConfidence,
      expiryDate: expiryDate,
      notes: notes,
    );

    // Reload documents to update the list
    await loadDocuments();

    // Reload folders to update document counts
    await _refreshFolders();

    print(
        '✅ [DocumentsNotifier] Document created, documents and folders refreshed');
    return document;
  }

  Future<void> updateDocument(DocumentModel document) async {
    await _repository.updateDocument(document);
    await loadDocuments();
  }

  Future<void> updateDocumentImage(DocumentModel document) async {
    await _repository.updateDocumentImage(document);
    await loadDocuments();
  }

  Future<void> moveDocument(String documentId, String newFolderId) async {
    await _repository.moveDocument(documentId, newFolderId);
    await loadDocuments();
    await _refreshFolders(); // Refresh folder counts
  }

  Future<void> deleteDocument(String documentId) async {
    await _repository.deleteDocument(documentId);
    await loadDocuments();
    await _refreshFolders(); // Refresh folder counts
  }

  List<DocumentModel> searchDocuments(String query) {
    return _repository.searchDocuments(query);
  }

  List<DocumentModel> getExpiringDocuments(int daysAhead) {
    return _repository.getExpiringDocuments(daysAhead);
  }

  List<DocumentModel> getRecentDocuments(int days) {
    return _repository.getRecentDocuments(days);
  }

  /// Sync documents from MongoDB
  Future<void> syncFromMongoDB() async {
    await DocumentSyncService.performFullSync();
    await loadDocuments();
  }

  /// Perform full sync (upload and download)
  Future<void> performFullSync() async {
    await DocumentSyncService.performFullSync();
    await loadDocuments();
  }
}

// Expenses
final expensesProvider =
    StateNotifierProvider<ExpensesNotifier, List<ExpenseModel>>((ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return ExpensesNotifier(repository);
});

class ExpensesNotifier extends StateNotifier<List<ExpenseModel>> {
  final ExpenseRepository _repository;

  ExpensesNotifier(this._repository) : super([]) {
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    state = _repository.getAllExpenses();
  }

  Future<ExpenseModel> createExpense({
    required double amount,
    required String category,
    required String paymentMethod,
    required DateTime date,
    String? note,
    String? linkedDocumentId,
    String? storeName,
    List<String>? tags,
    bool isRecurring = false,
    String? recurringPeriod,
  }) async {
    final expense = await _repository.createExpense(
      amount: amount,
      category: category,
      paymentMethod: paymentMethod,
      date: date,
      note: note,
      linkedDocumentId: linkedDocumentId,
      storeName: storeName,
      tags: tags,
      isRecurring: isRecurring,
      recurringPeriod: recurringPeriod,
    );
    await loadExpenses();
    return expense;
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _repository.updateExpense(expense);
    await loadExpenses();
  }

  Future<void> deleteExpense(String expenseId) async {
    await _repository.deleteExpense(expenseId);
    await loadExpenses();
  }

  List<ExpenseModel> getTodayExpenses() {
    return _repository.getTodayExpenses();
  }

  List<ExpenseModel> getWeekExpenses() {
    return _repository.getWeekExpenses();
  }

  List<ExpenseModel> getMonthExpenses() {
    return _repository.getMonthExpenses();
  }

  double getTotalExpense(DateTime start, DateTime end) {
    return _repository.getTotalExpense(start, end);
  }

  Map<String, double> getExpensesByCategories(DateTime start, DateTime end) {
    return _repository.getExpensesByCategories(start, end);
  }

  Map<String, dynamic> getExpenseStats(DateTime start, DateTime end) {
    return _repository.getExpenseStats(start, end);
  }

  List<ExpenseModel> searchExpenses(String query) {
    return _repository.searchExpenses(query);
  }
}

// Theme Mode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, bool>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(false) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    // Load saved theme mode from Hive
    final isDark =
        HiveService.getSetting('is_dark_mode', defaultValue: false) as bool;
    state = isDark;
  }

  void setDarkMode(bool isDark) {
    state = isDark;
    // Save to Hive
    HiveService.saveSetting('is_dark_mode', isDark);
  }

  void toggleTheme() {
    setDarkMode(!state);
  }
}
