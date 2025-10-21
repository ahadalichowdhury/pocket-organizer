import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../models/folder_model.dart';
import '../services/document_sync_service.dart';
import '../services/folder_sync_service.dart';
import '../services/hive_service.dart';

class FolderRepository {
  final _uuid = const Uuid();

  /// Initialize default system folders
  Future<void> initializeDefaultFolders() async {
    final existingFolders = HiveService.getAllFolders();

    if (existingFolders.isEmpty) {
      final defaultFolders = [
        FolderModel.create(
          id: _uuid.v4(),
          name: DocumentType.warranty,
          description: 'Warranty documents and guarantees',
          iconName: '📜',
          isSystemFolder: true,
        ),
        FolderModel.create(
          id: _uuid.v4(),
          name: DocumentType.prescription,
          description: 'Medical prescriptions',
          iconName: '💊',
          isSystemFolder: true,
        ),
        FolderModel.create(
          id: _uuid.v4(),
          name: DocumentType.receipt,
          description: 'Purchase receipts',
          iconName: '🧾',
          isSystemFolder: true,
        ),
        FolderModel.create(
          id: _uuid.v4(),
          name: DocumentType.bill,
          description: 'Bills and invoices',
          iconName: '📄',
          isSystemFolder: true,
        ),
        FolderModel.create(
          id: _uuid.v4(),
          name: DocumentType.personalId,
          description: 'Personal identification documents',
          iconName: '🪪',
          isSystemFolder: true,
        ),
        FolderModel.create(
          id: _uuid.v4(),
          name: DocumentType.invoice,
          description: 'Business invoices',
          iconName: '📑',
          isSystemFolder: true,
        ),
        FolderModel.create(
          id: _uuid.v4(),
          name: DocumentType.uncategorized,
          description: 'Uncategorized documents',
          iconName: '📁',
          isSystemFolder: true,
        ),
      ];

      for (var folder in defaultFolders) {
        await HiveService.addFolder(folder);
      }
    }
  }

  /// Get all folders sorted by name
  List<FolderModel> getAllFolders() {
    final folders = HiveService.getAllFolders();
    folders.sort((a, b) => a.name.compareTo(b.name));
    return folders;
  }

  /// Get folder by ID
  FolderModel? getFolderById(String id) {
    return HiveService.getFolder(id);
  }

  /// Get folder by name (case-insensitive)
  FolderModel? getFolderByName(String name) {
    final folders = HiveService.getAllFolders();
    return folders.cast<FolderModel?>().firstWhere(
          (folder) => folder!.name.toLowerCase() == name.toLowerCase(),
          orElse: () => null,
        );
  }

  /// Create a new folder
  Future<FolderModel> createFolder({
    required String name,
    String? description,
    String? iconName,
  }) async {
    final folder = FolderModel.create(
      id: _uuid.v4(),
      name: name,
      description: description,
      iconName: iconName ?? '📁',
      isSystemFolder: false,
    );

    await HiveService.addFolder(folder);

    return folder;
  }

  /// Update folder
  Future<void> updateFolder(FolderModel folder) async {
    final updatedFolder = folder.copyWith(updatedAt: DateTime.now());
    await HiveService.updateFolder(updatedFolder);
  }

  /// Delete folder and all its documents
  Future<bool> deleteFolder(String folderId) async {
    final folder = HiveService.getFolder(folderId);

    if (folder == null) {
      return false;
    }

    try {
      // Get all documents in this folder
      final documents = HiveService.getAllDocuments()
          .where((doc) => doc.folderId == folderId)
          .toList();

      print(
          '🗑️ Deleting folder "${folder.name}" with ${documents.length} document(s)');

      // Delete all documents in the folder
      for (var document in documents) {
        print('   📄 Deleting document: ${document.title}');

        // Delete from local storage
        await HiveService.deleteDocument(document.id);

        // Delete from MongoDB
        await DocumentSyncService.deleteDocumentFromMongoDB(document.id);
      }

      // Delete the folder from local storage
      await HiveService.deleteFolder(folderId);

      // Delete from MongoDB
      await FolderSyncService.deleteFolderFromMongoDB(folderId);

      print('✅ Folder and all documents deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting folder: $e');
      return false;
    }
  }

  /// Update folder document count
  Future<void> updateFolderDocumentCount(String folderId, int count) async {
    final folder = HiveService.getFolder(folderId);
    if (folder != null) {
      final updatedFolder = folder.copyWith(
        documentCount: count,
        updatedAt: DateTime.now(),
      );
      await HiveService.updateFolder(updatedFolder);
    }
  }

  /// Get or create folder by name (for auto-categorization)
  Future<FolderModel> getOrCreateFolder(String name) async {
    var folder = getFolderByName(name);

    folder ??= await createFolder(
      name: name,
      iconName: DocumentType.getIconForType(name),
    );

    return folder;
  }
}
