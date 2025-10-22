import 'package:uuid/uuid.dart';

import '../models/document_model.dart';
import '../services/document_sync_service.dart';
import '../services/hive_service.dart';
import '../services/s3_storage_service.dart';
import 'folder_repository.dart';

class DocumentRepository {
  final _uuid = const Uuid();
  final FolderRepository _folderRepository;

  DocumentRepository(this._folderRepository);

  /// Get all documents
  List<DocumentModel> getAllDocuments() {
    final documents = HiveService.getAllDocuments();
    documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return documents;
  }

  /// Get document by ID
  DocumentModel? getDocumentById(String id) {
    return HiveService.getDocument(id);
  }

  /// Get documents by folder
  List<DocumentModel> getDocumentsByFolder(String folderId) {
    final documents = HiveService.getDocumentsByFolder(folderId);
    documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return documents;
  }

  /// Search documents by title, tags, or OCR text
  List<DocumentModel> searchDocuments(String query) {
    final allDocuments = HiveService.getAllDocuments();
    final lowerQuery = query.toLowerCase();

    return allDocuments.where((doc) {
      return doc.title.toLowerCase().contains(lowerQuery) ||
          doc.tags.any((tag) => tag.toLowerCase().contains(lowerQuery)) ||
          (doc.ocrText?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Create a new document
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
    final docId = _uuid.v4();

    final document = DocumentModel.create(
      id: docId,
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

    // Upload image to cloud storage FIRST (await it)
    print('📤 [DocumentRepo] Uploading image to S3...');
    final cloudUrl = await S3StorageService.uploadDocumentImage(
      localImagePath: localImagePath,
      documentId: docId,
    );

    // Update document with cloud URL
    final documentWithCloud = cloudUrl != null
        ? document.copyWith(cloudImageUrl: cloudUrl)
        : document;

    if (cloudUrl != null) {
      print('✅ [DocumentRepo] Image uploaded: $cloudUrl');
    } else {
      print(
          '⚠️ [DocumentRepo] Image upload failed, continuing with local only');
    }

    await HiveService.addDocument(documentWithCloud);

    // Update folder document count
    await _updateFolderCount(folderId);

    return documentWithCloud;
  }

  /// Update document
  Future<void> updateDocument(DocumentModel document) async {
    final updatedDocument = document.copyWith(updatedAt: DateTime.now());
    await HiveService.updateDocument(updatedDocument);

    // Sync to MongoDB in background (non-blocking)
    _syncDocumentToMongoDB(updatedDocument);
  }

  /// Sync document to MongoDB (background)
  void _syncDocumentToMongoDB(DocumentModel document) async {
    try {
      await DocumentSyncService.syncDocumentToMongoDB(document);
      print('✅ [DocumentRepo] Document synced to MongoDB: ${document.title}');
    } catch (e) {
      print('⚠️ [DocumentRepo] MongoDB sync failed (will retry later): $e');
    }
  }

  /// Update document image (after cropping)
  Future<void> updateDocumentImage(DocumentModel document) async {
    print('📤 [DocumentRepo] Uploading updated image to cloud storage...');

    // Upload the new/updated image
    final cloudUrl = await S3StorageService.uploadDocumentImage(
      localImagePath: document.localImagePath,
      documentId: document.id,
    );

    if (cloudUrl != null) {
      print('✅ [DocumentRepo] Image updated successfully');

      // Update document with new cloud URL
      final updatedDocument = document.copyWith(
        cloudImageUrl: cloudUrl,
        updatedAt: DateTime.now(),
      );

      await HiveService.updateDocument(updatedDocument);
    } else {
      print('⚠️ [DocumentRepo] Image upload failed');
    }
  }

  /// Move document to another folder
  Future<void> moveDocument(String documentId, String newFolderId) async {
    final document = HiveService.getDocument(documentId);

    if (document == null) {
      throw Exception('Document not found');
    }

    final oldFolderId = document.folderId;

    final updatedDocument = document.copyWith(
      folderId: newFolderId,
      updatedAt: DateTime.now(),
    );

    await HiveService.updateDocument(updatedDocument);

    // Update folder counts
    await _updateFolderCount(oldFolderId);
    await _updateFolderCount(newFolderId);
  }

  /// Delete document
  Future<void> deleteDocument(String documentId) async {
    final document = HiveService.getDocument(documentId);

    if (document == null) {
      return;
    }

    final folderId = document.folderId;

    // Delete from cloud storage
    print('🗑️ [DocumentRepo] Deleting image from S3...');
    await S3StorageService.deleteDocumentImage(documentId: documentId);

    await HiveService.deleteDocument(documentId);

    // Update folder document count
    await _updateFolderCount(folderId);
  }

  /// Link document to expense
  Future<void> linkToExpense(String documentId, String expenseId) async {
    final document = HiveService.getDocument(documentId);

    if (document != null) {
      final updatedDocument = document.copyWith(
        linkedExpenseId: expenseId,
        updatedAt: DateTime.now(),
      );
      await HiveService.updateDocument(updatedDocument);
    }
  }

  /// Get documents expiring soon (within specified days)
  List<DocumentModel> getExpiringDocuments(int daysAhead) {
    final allDocuments = HiveService.getAllDocuments();
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: daysAhead));

    return allDocuments.where((doc) {
      if (doc.expiryDate == null) return false;
      return doc.expiryDate!.isAfter(now) &&
          doc.expiryDate!.isBefore(futureDate);
    }).toList();
  }

  /// Get recent documents (last N days)
  List<DocumentModel> getRecentDocuments(int days) {
    final allDocuments = HiveService.getAllDocuments();
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    final recentDocs = allDocuments.where((doc) {
      return doc.createdAt.isAfter(cutoffDate);
    }).toList();

    recentDocs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recentDocs;
  }

  /// Update folder document count
  Future<void> _updateFolderCount(String folderId) async {
    final documents = HiveService.getDocumentsByFolder(folderId);
    await _folderRepository.updateFolderDocumentCount(
        folderId, documents.length);
  }

  /// Get documents by type
  List<DocumentModel> getDocumentsByType(String type) {
    final allDocuments = HiveService.getAllDocuments();
    return allDocuments.where((doc) => doc.documentType == type).toList();
  }

  /// Get documents by tags
  List<DocumentModel> getDocumentsByTag(String tag) {
    final allDocuments = HiveService.getAllDocuments();
    return allDocuments.where((doc) => doc.tags.contains(tag)).toList();
  }
}
