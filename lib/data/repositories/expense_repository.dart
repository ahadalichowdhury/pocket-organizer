import 'package:uuid/uuid.dart';

import '../models/expense_model.dart';
import '../services/hive_service.dart';

class ExpenseRepository {
  final _uuid = const Uuid();

  /// Get all expenses
  List<ExpenseModel> getAllExpenses() {
    final expenses = HiveService.getAllExpenses();
    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  /// Get expense by ID
  ExpenseModel? getExpenseById(String id) {
    return HiveService.getExpense(id);
  }

  /// Create new expense
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
    final expense = ExpenseModel.create(
      id: _uuid.v4(),
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

    // Save to local storage
    await HiveService.addExpense(expense);

    return expense;
  }

  /// Update expense
  Future<void> updateExpense(ExpenseModel expense) async {
    final updatedExpense = expense.copyWith(updatedAt: DateTime.now());
    await HiveService.updateExpense(updatedExpense);
  }

  /// Delete expense
  Future<void> deleteExpense(String expenseId) async {
    await HiveService.deleteExpense(expenseId);
  }

  /// Get expenses by date range
  List<ExpenseModel> getExpensesByDateRange(DateTime start, DateTime end) {
    final expenses = HiveService.getExpensesByDateRange(start, end);
    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  /// Get expenses for today
  List<ExpenseModel> getTodayExpenses() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return getExpensesByDateRange(start, end);
  }

  /// Get expenses for this week
  List<ExpenseModel> getWeekExpenses() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final end = start.add(const Duration(days: 7));
    return getExpensesByDateRange(start, end);
  }

  /// Get expenses for this month
  List<ExpenseModel> getMonthExpenses() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return getExpensesByDateRange(start, end);
  }

  /// Get expenses by category
  List<ExpenseModel> getExpensesByCategory(String category) {
    final allExpenses = HiveService.getAllExpenses();
    return allExpenses
        .where((expense) => expense.category == category)
        .toList();
  }

  /// Get total expense for date range
  double getTotalExpense(DateTime start, DateTime end) {
    final expenses = getExpensesByDateRange(start, end);
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Get total expense by category for date range
  Map<String, double> getExpensesByCategories(DateTime start, DateTime end) {
    final expenses = getExpensesByDateRange(start, end);
    final categoryTotals = <String, double>{};

    for (var expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0.0) + expense.amount;
    }

    return categoryTotals;
  }

  /// Get daily expenses for a month (for charts)
  Map<DateTime, double> getDailyExpenses(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final expenses = getExpensesByDateRange(start, end);

    final dailyTotals = <DateTime, double>{};

    for (var expense in expenses) {
      final dateKey = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0.0) + expense.amount;
    }

    return dailyTotals;
  }

  /// Get monthly expenses for a year (for charts)
  Map<int, double> getMonthlyExpenses(int year) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final expenses = getExpensesByDateRange(start, end);

    final monthlyTotals = <int, double>{};

    for (var expense in expenses) {
      monthlyTotals[expense.date.month] =
          (monthlyTotals[expense.date.month] ?? 0.0) + expense.amount;
    }

    return monthlyTotals;
  }

  /// Get expense statistics
  Map<String, dynamic> getExpenseStats(DateTime start, DateTime end) {
    final expenses = getExpensesByDateRange(start, end);

    if (expenses.isEmpty) {
      return {
        'total': 0.0,
        'average': 0.0,
        'count': 0,
        'highest': 0.0,
        'lowest': 0.0,
        'categories': <String, double>{},
      };
    }

    final amounts = expenses.map((e) => e.amount).toList();
    amounts.sort();

    return {
      'total': getTotalExpense(start, end),
      'average': amounts.reduce((a, b) => a + b) / amounts.length,
      'count': expenses.length,
      'highest': amounts.last,
      'lowest': amounts.first,
      'categories': getExpensesByCategories(start, end),
    };
  }

  /// Search expenses
  List<ExpenseModel> searchExpenses(String query) {
    final allExpenses = HiveService.getAllExpenses();
    final lowerQuery = query.toLowerCase();

    return allExpenses.where((expense) {
      return expense.category.toLowerCase().contains(lowerQuery) ||
          (expense.storeName?.toLowerCase().contains(lowerQuery) ?? false) ||
          (expense.note?.toLowerCase().contains(lowerQuery) ?? false) ||
          expense.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }
}
