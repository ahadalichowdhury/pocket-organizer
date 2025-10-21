import 'package:hive/hive.dart';

part 'expense_model.g.dart';

@HiveType(typeId: 2)
class ExpenseModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  double amount;

  @HiveField(2)
  String category;

  @HiveField(3)
  String paymentMethod;

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  String? note;

  @HiveField(8)
  String? linkedDocumentId;

  @HiveField(9)
  String? storeName;

  @HiveField(10)
  List<String> tags;

  @HiveField(11)
  bool isRecurring;

  @HiveField(12)
  String? recurringPeriod;

  ExpenseModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.linkedDocumentId,
    this.storeName,
    this.tags = const [],
    this.isRecurring = false,
    this.recurringPeriod,
  });

  factory ExpenseModel.create({
    required String id,
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
  }) {
    final now = DateTime.now();
    return ExpenseModel(
      id: id,
      amount: amount,
      category: category,
      paymentMethod: paymentMethod,
      date: date,
      createdAt: now,
      updatedAt: now,
      note: note,
      linkedDocumentId: linkedDocumentId,
      storeName: storeName,
      tags: tags ?? [],
      isRecurring: isRecurring,
      recurringPeriod: recurringPeriod,
    );
  }

  ExpenseModel copyWith({
    double? amount,
    String? category,
    String? paymentMethod,
    DateTime? date,
    DateTime? updatedAt,
    String? note,
    String? linkedDocumentId,
    String? storeName,
    List<String>? tags,
    bool? isRecurring,
    String? recurringPeriod,
  }) {
    return ExpenseModel(
      id: id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
      linkedDocumentId: linkedDocumentId ?? this.linkedDocumentId,
      storeName: storeName ?? this.storeName,
      tags: tags ?? this.tags,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringPeriod: recurringPeriod ?? this.recurringPeriod,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'paymentMethod': paymentMethod,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'note': note,
      'linkedDocumentId': linkedDocumentId,
      'storeName': storeName,
      'tags': tags,
      'isRecurring': isRecurring,
      'recurringPeriod': recurringPeriod,
    };
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      paymentMethod: json['paymentMethod'] as String,
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      note: json['note'] as String?,
      linkedDocumentId: json['linkedDocumentId'] as String?,
      storeName: json['storeName'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurringPeriod: json['recurringPeriod'] as String?,
    );
  }
}

