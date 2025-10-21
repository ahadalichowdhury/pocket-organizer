import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../data/models/expense_model.dart';
import '../data/services/hive_service.dart';

class ExpenseSummaryCard extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String period;

  const ExpenseSummaryCard({
    super.key,
    required this.expenses,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final total =
        expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
    final currencySymbol =
        HiveService.getSetting('currency_symbol', defaultValue: '\$') as String;

    final categoryTotals = <String, double>{};
    for (var expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0.0) + expense.amount;
    }

    final topCategory = categoryTotals.entries.isNotEmpty
        ? categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  period,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '$currencySymbol${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  context,
                  label: 'Transactions',
                  value: expenses.length.toString(),
                ),
                _buildStatItem(
                  context,
                  label: 'Average',
                  value:
                      '$currencySymbol${(total / expenses.length).toStringAsFixed(2)}',
                ),
                if (topCategory != null)
                  _buildStatItem(
                    context,
                    label: 'Top Category',
                    value: topCategory.key,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context,
      {required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final currencySymbol =
        HiveService.getSetting('currency_symbol', defaultValue: '\$') as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Category Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getCategoryColor(expense.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    ExpenseCategory.getIconForCategory(expense.category),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Expense Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.storeName ?? expense.category,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          expense.category,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          expense.paymentMethod,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                        ),
                      ],
                    ),
                    Text(
                      DateFormat('MMM d, yyyy').format(expense.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                '$currencySymbol${expense.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food':
        return Colors.orange;
      case 'Transport':
        return Colors.blue;
      case 'Health':
        return Colors.red;
      case 'Shopping':
        return Colors.purple;
      case 'Bills':
        return Colors.amber;
      case 'Entertainment':
        return Colors.pink;
      case 'Education':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}
