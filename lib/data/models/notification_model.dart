import 'package:hive/hive.dart';

part 'notification_model.g.dart';

@HiveType(typeId: 3)
class NotificationModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String message;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  bool isRead;

  @HiveField(5)
  final String type; // 'budget_alert', 'document_expiry', 'general'

  @HiveField(6)
  final Map<String, dynamic>? data; // Additional data like expense amount, etc.

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.type = 'general',
    this.data,
  });

  factory NotificationModel.create({
    required String id,
    required String title,
    required String message,
    String type = 'general',
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      createdAt: DateTime.now(),
      isRead: false,
      type: type,
      data: data,
    );
  }

  NotificationModel copyWith({
    String? title,
    String? message,
    bool? isRead,
    String? type,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      data: data ?? this.data,
    );
  }
}
