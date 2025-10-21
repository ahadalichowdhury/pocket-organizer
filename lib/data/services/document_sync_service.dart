import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart' as mongo;

import '../../core/config/mongodb_config.dart';
import '../models/document_model.dart';
import '../services/hive_service.dart';
import 'mongodb_service.dart';

class DocumentSyncService {
  /// Sync a single document to MongoDB
  static Future<bool> syncDocumentToMongoDB(DocumentModel document) async {
    if (kIsWeb) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final collection = await MongoDBService.getUserCollection(
          MongoDBConfig.documentsCollection);
      if (collection == null) return false;

      final data = {
        '_id': document.id,
        'userId': user.uid,
        'title': document.title,
        'folderId': document.folderId,
        'localImagePath': document.localImagePath,
        'cloudImageUrl': document.cloudImageUrl,
        'createdAt': document.createdAt.toIso8601String(),
        'updatedAt': document.updatedAt.toIso8601String(),
        'ocrText': document.ocrText,
        'documentType': document.documentType,
        'tags': document.tags,
        'classificationConfidence': document.classificationConfidence,
        'linkedExpenseId': document.linkedExpenseId,
        'expiryDate': document.expiryDate?.toIso8601String(),
        'notes': document.notes,
        'metadata': document.metadata,
      };

      // Use a compound query with $and to ensure both conditions match
      final query = {
        '\$and': [
          {'_id': document.id},
          {'userId': user.uid}
        ]
      };

      await collection.replaceOne(
        query,
        data,
        upsert: true,
      );

      return true;
    } catch (e) {
      print('❌ Error syncing document to MongoDB: $e');
      return false;
    }
  }

  /// Delete a document from MongoDB
  static Future<bool> deleteDocumentFromMongoDB(String documentId) async {
    if (kIsWeb) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final collection = await MongoDBService.getUserCollection(
          MongoDBConfig.documentsCollection);
      if (collection == null) return false;

      final query = {
        '\$and': [
          {'_id': documentId},
          {'userId': user.uid}
        ]
      };

      await collection.deleteOne(query);

      return true;
    } catch (e) {
      print('❌ Error deleting document from MongoDB: $e');
      return false;
    }
  }

  /// Sync all local documents to MongoDB
  static Future<int> syncAllDocumentsToMongoDB() async {
    if (kIsWeb) return 0;

    try {
      final documents = HiveService.getAllDocuments();
      int synced = 0;

      for (final document in documents) {
        final success = await syncDocumentToMongoDB(document);
        if (success) synced++;
      }

      print('✅ Synced $synced documents to MongoDB');
      return synced;
    } catch (e) {
      print('❌ Error syncing documents to MongoDB: $e');
      return 0;
    }
  }

  /// Download documents from MongoDB
  static Future<List<DocumentModel>> downloadDocumentsFromMongoDB() async {
    if (kIsWeb) return [];

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final collection = await MongoDBService.getUserCollection(
          MongoDBConfig.documentsCollection);
      if (collection == null) return [];

      final docs =
          await collection.find(mongo.where.eq('userId', user.uid)).toList();

      final documents = <DocumentModel>[];
      for (final doc in docs) {
        try {
          documents.add(DocumentModel(
            id: doc['_id'] as String,
            title: doc['title'] as String,
            folderId: doc['folderId'] as String,
            localImagePath: doc['localImagePath'] as String,
            cloudImageUrl: doc['cloudImageUrl'] as String?,
            createdAt: DateTime.parse(doc['createdAt'] as String),
            updatedAt: DateTime.parse(doc['updatedAt'] as String),
            ocrText: doc['ocrText'] as String?,
            documentType: doc['documentType'] as String,
            tags: List<String>.from(doc['tags'] ?? []),
            classificationConfidence:
                (doc['classificationConfidence'] as num?)?.toDouble(),
            linkedExpenseId: doc['linkedExpenseId'] as String?,
            expiryDate: doc['expiryDate'] != null
                ? DateTime.parse(doc['expiryDate'] as String)
                : null,
            notes: doc['notes'] as String?,
            metadata: doc['metadata'] as Map<String, dynamic>?,
          ));
        } catch (e) {
          print('⚠️ Error parsing document: $e');
        }
      }

      print('✅ Downloaded ${documents.length} documents from MongoDB');
      return documents;
    } catch (e) {
      print('❌ Error downloading documents from MongoDB: $e');
      return [];
    }
  }

  /// Perform full sync (upload local, download remote, merge without duplicates)
  static Future<bool> performFullSync() async {
    if (kIsWeb || !MongoDBService.isConnected) {
      print('ℹ️ MongoDB sync not available (web or not connected)');
      return false;
    }

    try {
      print('🔄 Starting document full sync...');

      // 1. Upload all local documents to MongoDB (upsert prevents duplicates in DB)
      await syncAllDocumentsToMongoDB();

      // 2. Download all documents from MongoDB
      final remoteDocuments = await downloadDocumentsFromMongoDB();

      // 3. Get all local document IDs for quick lookup
      final localDocuments = HiveService.getAllDocuments();
      final localDocumentIds = localDocuments.map((d) => d.id).toSet();

      print(
          'ℹ️ Local documents: ${localDocuments.length}, Remote documents: ${remoteDocuments.length}');

      // 4. Merge remote documents into local storage (avoid duplicates)
      int added = 0;
      int updated = 0;
      int skipped = 0;

      for (final remoteDoc in remoteDocuments) {
        if (localDocumentIds.contains(remoteDoc.id)) {
          // Document exists locally, check if remote is newer
          final localDoc = HiveService.getDocument(remoteDoc.id);
          if (localDoc != null &&
              remoteDoc.updatedAt.isAfter(localDoc.updatedAt)) {
            await HiveService.updateDocument(remoteDoc);
            updated++;
            print('   📝 Updated: ${remoteDoc.title}');
          } else {
            skipped++;
          }
        } else {
          // New document from server, add it locally
          await HiveService.addDocument(remoteDoc);
          added++;
          print('   ➕ Added: ${remoteDoc.title}');
        }
      }

      print('✅ Document sync completed');
      print('   Added: $added, Updated: $updated, Skipped: $skipped');
      return true;
    } catch (e) {
      print('❌ Error during document full sync: $e');
      return false;
    }
  }
}
