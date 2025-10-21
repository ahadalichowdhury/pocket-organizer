import 'package:hive/hive.dart';

part 'folder_model.g.dart';

@HiveType(typeId: 0)
class FolderModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  @HiveField(4)
  int documentCount;

  @HiveField(5)
  String? description;

  @HiveField(6)
  String? iconName;

  @HiveField(7)
  bool isSystemFolder;

  FolderModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.documentCount = 0,
    this.description,
    this.iconName,
    this.isSystemFolder = false,
  });

  factory FolderModel.create({
    required String id,
    required String name,
    String? description,
    String? iconName,
    bool isSystemFolder = false,
  }) {
    final now = DateTime.now();
    return FolderModel(
      id: id,
      name: name,
      createdAt: now,
      updatedAt: now,
      documentCount: 0,
      description: description,
      iconName: iconName,
      isSystemFolder: isSystemFolder,
    );
  }

  FolderModel copyWith({
    String? name,
    DateTime? updatedAt,
    int? documentCount,
    String? description,
    String? iconName,
  }) {
    return FolderModel(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      documentCount: documentCount ?? this.documentCount,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      isSystemFolder: isSystemFolder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'documentCount': documentCount,
      'description': description,
      'iconName': iconName,
      'isSystemFolder': isSystemFolder,
    };
  }

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      documentCount: json['documentCount'] as int? ?? 0,
      description: json['description'] as String?,
      iconName: json['iconName'] as String?,
      isSystemFolder: json['isSystemFolder'] as bool? ?? false,
    );
  }
}

