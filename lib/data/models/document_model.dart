import 'package:hive/hive.dart';

part 'document_model.g.dart';

@HiveType(typeId: 1)
class DocumentModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final String folderId;

  @HiveField(3)
  final String localImagePath;

  @HiveField(4)
  String? cloudImageUrl;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  String? ocrText;

  @HiveField(8)
  String documentType;

  @HiveField(9)
  List<String> tags;

  @HiveField(10)
  double? classificationConfidence;

  @HiveField(11)
  String? linkedExpenseId;

  @HiveField(12)
  DateTime? expiryDate;

  @HiveField(13)
  String? notes;

  @HiveField(14)
  Map<String, dynamic>? metadata;

  DocumentModel({
    required this.id,
    required this.title,
    required this.folderId,
    required this.localImagePath,
    this.cloudImageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.ocrText,
    required this.documentType,
    this.tags = const [],
    this.classificationConfidence,
    this.linkedExpenseId,
    this.expiryDate,
    this.notes,
    this.metadata,
  });

  factory DocumentModel.create({
    required String id,
    required String title,
    required String folderId,
    required String localImagePath,
    required String documentType,
    String? ocrText,
    List<String>? tags,
    double? classificationConfidence,
    DateTime? expiryDate,
    String? notes,
  }) {
    final now = DateTime.now();
    return DocumentModel(
      id: id,
      title: title,
      folderId: folderId,
      localImagePath: localImagePath,
      createdAt: now,
      updatedAt: now,
      documentType: documentType,
      ocrText: ocrText,
      tags: tags ?? [],
      classificationConfidence: classificationConfidence,
      expiryDate: expiryDate,
      notes: notes,
    );
  }

  DocumentModel copyWith({
    String? title,
    String? folderId,
    String? localImagePath,
    String? cloudImageUrl,
    DateTime? updatedAt,
    String? ocrText,
    String? documentType,
    List<String>? tags,
    double? classificationConfidence,
    String? linkedExpenseId,
    DateTime? expiryDate,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return DocumentModel(
      id: id,
      title: title ?? this.title,
      folderId: folderId ?? this.folderId,
      localImagePath: localImagePath ?? this.localImagePath,
      cloudImageUrl: cloudImageUrl ?? this.cloudImageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ocrText: ocrText ?? this.ocrText,
      documentType: documentType ?? this.documentType,
      tags: tags ?? this.tags,
      classificationConfidence:
          classificationConfidence ?? this.classificationConfidence,
      linkedExpenseId: linkedExpenseId ?? this.linkedExpenseId,
      expiryDate: expiryDate ?? this.expiryDate,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'folderId': folderId,
      'localImagePath': localImagePath,
      'cloudImageUrl': cloudImageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'ocrText': ocrText,
      'documentType': documentType,
      'tags': tags,
      'classificationConfidence': classificationConfidence,
      'linkedExpenseId': linkedExpenseId,
      'expiryDate': expiryDate?.toIso8601String(),
      'notes': notes,
      'metadata': metadata,
    };
  }

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      title: json['title'] as String,
      folderId: json['folderId'] as String,
      localImagePath: json['localImagePath'] as String,
      cloudImageUrl: json['cloudImageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      ocrText: json['ocrText'] as String?,
      documentType: json['documentType'] as String,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      classificationConfidence: json['classificationConfidence'] as double?,
      linkedExpenseId: json['linkedExpenseId'] as String?,
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
      notes: json['notes'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
