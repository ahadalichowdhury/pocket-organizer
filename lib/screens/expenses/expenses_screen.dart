import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// import 'package:uuid/uuid.dart'; // Not needed - using server-side notifications

import '../../core/constants/app_constants.dart';
import '../../data/models/expense_model.dart';
// import '../../data/models/notification_model.dart'; // Not needed - using server-side notifications
import '../../data/services/hive_service.dart';
import '../../data/services/user_settings_sync_service.dart';
import '../../providers/app_providers.dart';
import '../../widgets/expense_summary_card.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _selectedPeriod = 'Month'; // Day, Week, Month, Year
  String? _selectedCategoryFilter;
  String? _selectedPaymentFilter;
  String _searchQuery = '';

  // 🔕 Local notification plugins - not needed with server-side notifications
  // final FlutterLocalNotificationsPlugin _notificationsPlugin =
  //     FlutterLocalNotificationsPlugin();
  // final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    // _initializeNotifications(); // Not needed - using server-side notifications
  }

  /* COMMENTED OUT - Local notification initialization not needed
  Future<void> _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _notificationsPlugin.initialize(settings);
    print('💬 [Notifications] Initialized: $initialized');

    // Request permissions for Android 13+
    if (initialized == true) {
      final androidImpl =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        print('💬 [Notifications] Permission granted: $granted');
      }
    }
  }

  Future<void> _showNotification(String title, String body) async {
    try {
      print('💬 [Notifications] Attempting to show: $title');
      const androidDetails = AndroidNotificationDetails(
        'budget_alerts',
        'Budget Alerts',
        channelDescription: 'Notifications for budget limit alerts',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await _notificationsPlugin.show(0, title, body, details);
      print('✅ [Notifications] Notification shown successfully');
    } catch (e) {
      print('❌ [Notifications] Failed to show notification: $e');
    }
  }
  */ // END OF COMMENTED NOTIFICATION CODE

  @override
  Widget build(BuildContext context) {
    final allExpenses = ref.watch(expensesProvider);
    final expensesNotifier = ref.watch(expensesProvider.notifier);
    var expenses = _getExpensesForPeriod(allExpenses).cast<ExpenseModel>();

    // Apply filters
    if (_selectedCategoryFilter != null) {
      expenses = expenses
          .where((e) => e.category == _selectedCategoryFilter)
          .toList()
          .cast<ExpenseModel>();
    }
    if (_selectedPaymentFilter != null) {
      expenses = expenses
          .where((e) => e.paymentMethod == _selectedPaymentFilter)
          .toList()
          .cast<ExpenseModel>();
    }
    if (_searchQuery.isNotEmpty) {
      expenses = expenses
          .where((e) {
            return (e.storeName
                        ?.toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ??
                    false) ||
                e.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (e.note?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                    false);
          })
          .toList()
          .cast<ExpenseModel>();
    }

    final now = DateTime.now();
    final startDate = _getStartDate();
    final stats = expensesNotifier.getExpenseStats(startDate, now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Analytics',
            onPressed: () {
              Navigator.pushNamed(context, '/expense-analytics');
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog(context);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') {
                _exportExpensesToCSV(context, expenses);
              } else if (value == 'clear_filters') {
                setState(() {
                  _selectedCategoryFilter = null;
                  _selectedPaymentFilter = null;
                  _searchQuery = '';
                });
              } else if (value == 'statistics') {
                _showStatistics(context, expenses);
              } else if (value == 'budget_settings') {
                _showBudgetSettingsDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'budget_settings',
                child: Row(
                  children: [
                    Icon(Icons.savings),
                    SizedBox(width: 12),
                    Text('Budget Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 12),
                    Text('Export to CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'statistics',
                child: Row(
                  children: [
                    Icon(Icons.analytics),
                    SizedBox(width: 12),
                    Text('View Statistics'),
                  ],
                ),
              ),
              if (_selectedCategoryFilter != null ||
                  _selectedPaymentFilter != null ||
                  _searchQuery.isNotEmpty)
                const PopupMenuItem(
                  value: 'clear_filters',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all),
                      SizedBox(width: 12),
                      Text('Clear Filters'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: expenses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start tracking your expenses',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period Selector
                  _buildPeriodSelector(context),
                  const SizedBox(height: 16),

                  // Budget Limit Progress
                  _buildBudgetProgress(context, expenses),

                  // Summary Card
                  ExpenseSummaryCard(
                    expenses: expenses,
                    period: _selectedPeriod,
                  ),
                  const SizedBox(height: 24),

                  // Category Breakdown Chart
                  Text(
                    'Category Breakdown',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildCategoryChart(
                        stats['categories'] as Map<String, double>),
                  ),
                  const SizedBox(height: 24),

                  // Expense List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transactions',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${expenses.length} items',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      return ExpenseTile(
                        expense: expenses[index],
                        onTap: () {
                          _showExpenseDetails(context, expenses[index]);
                        },
                        onLongPress: () {
                          _showExpenseOptions(context, expenses[index]);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'expenses_fab',
        onPressed: () => _showAddExpenseDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['Day', 'Week', 'Month', 'Year'].map((period) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(period),
              selected: _selectedPeriod == period,
              onSelected: (selected) {
                setState(() => _selectedPeriod = period);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, double> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final sortedCategories = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return PieChart(
      PieChartData(
        sections: sortedCategories.map((entry) {
          return PieChartSectionData(
            value: entry.value,
            title:
                '${(entry.value / categories.values.reduce((a, b) => a + b) * 100).toStringAsFixed(0)}%',
            color: _getCategoryColor(entry.key),
            radius: 100,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  List<dynamic> _getExpensesForPeriod(List<ExpenseModel> allExpenses) {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Day':
        final startOfDay = DateTime(now.year, now.month, now.day);
        return allExpenses
            .where((e) =>
                e.date
                    .isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
                e.date.isBefore(now.add(const Duration(days: 1))))
            .toList();
      case 'Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startDate =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return allExpenses
            .where((e) =>
                e.date.isAfter(startDate.subtract(const Duration(seconds: 1))))
            .toList();
      case 'Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return allExpenses
            .where((e) => e.date
                .isAfter(startOfMonth.subtract(const Duration(seconds: 1))))
            .toList();
      case 'Year':
        final startOfYear = DateTime(now.year, 1, 1);
        return allExpenses
            .where((e) => e.date
                .isAfter(startOfYear.subtract(const Duration(seconds: 1))))
            .toList();
      default:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return allExpenses
            .where((e) => e.date
                .isAfter(startOfMonth.subtract(const Duration(seconds: 1))))
            .toList();
    }
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Day':
        return DateTime(now.year, now.month, now.day);
      case 'Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      case 'Month':
        return DateTime(now.year, now.month, 1);
      case 'Year':
        return DateTime(now.year, 1, 1);
      default:
        return DateTime(now.year, now.month, 1);
    }
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

  void _showAddExpenseDialog(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final storeNameController = TextEditingController();

    String selectedCategory = ExpenseCategory.food;
    String selectedPaymentMethod = PaymentMethod.cash;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '${_getCurrencySymbol()} ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: ExpenseCategory.allCategories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedCategory = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPaymentMethod,
                      decoration:
                          const InputDecoration(labelText: 'Payment Method'),
                      items: PaymentMethod.allMethods.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedPaymentMethod = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: storeNameController,
                      decoration: const InputDecoration(
                        labelText: 'Store Name (Optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (Optional)',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (amountController.text.isEmpty) {
                      return;
                    }

                    final amount = double.tryParse(amountController.text);
                    if (amount == null) {
                      return;
                    }

                    await ref.read(expensesProvider.notifier).createExpense(
                          amount: amount,
                          category: selectedCategory,
                          paymentMethod: selectedPaymentMethod,
                          date: selectedDate,
                          note: noteController.text.isEmpty
                              ? null
                              : noteController.text,
                          storeName: storeNameController.text.isEmpty
                              ? null
                              : storeNameController.text,
                        );

                    // Check budget alerts after adding expense
                    await _checkAllBudgetAlerts();

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Expense added successfully')),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showExpenseDetails(BuildContext context, ExpenseModel expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Category icon and amount
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(expense.category)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            ExpenseCategory.getIconForCategory(
                                expense.category),
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getCurrencySymbol()}${expense.amount.toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                          ),
                          Text(
                            expense.category,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Details
                  if (expense.storeName != null)
                    _buildDetailRow(
                        context, Icons.store, 'Store', expense.storeName!),
                  _buildDetailRow(context, Icons.payment, 'Payment Method',
                      expense.paymentMethod),
                  _buildDetailRow(context, Icons.calendar_today, 'Date',
                      DateFormat('MMMM d, yyyy').format(expense.date)),
                  _buildDetailRow(
                      context,
                      Icons.access_time,
                      'Created',
                      DateFormat('MMM d, yyyy • h:mm a')
                          .format(expense.createdAt)),
                  if (expense.note != null && expense.note!.isNotEmpty)
                    _buildDetailRow(context, Icons.note, 'Note', expense.note!),
                  if (expense.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.label, size: 20, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: expense.tags
                                  .map((tag) => Chip(
                                        label: Text(tag),
                                        padding: const EdgeInsets.all(4),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditExpenseDialog(context, expense);
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            final confirmed =
                                await _showDeleteConfirmation(context);
                            if (confirmed) {
                              await ref
                                  .read(expensesProvider.notifier)
                                  .deleteExpense(expense.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.white),
                                        SizedBox(width: 12),
                                        Text('Expense deleted successfully'),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExpenseOptions(BuildContext context, ExpenseModel expense) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Expense'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditExpenseDialog(context, expense);
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('Duplicate'),
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(expensesProvider.notifier).createExpense(
                        amount: expense.amount,
                        category: expense.category,
                        paymentMethod: expense.paymentMethod,
                        date: DateTime.now(),
                        note: expense.note,
                        storeName: expense.storeName,
                      );

                  // Check budget alerts after duplicating expense
                  await _checkAllBudgetAlerts();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Expense duplicated')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await _showDeleteConfirmation(context);
                  if (confirmed) {
                    await ref
                        .read(expensesProvider.notifier)
                        .deleteExpense(expense.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense deleted')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Expense'),
              content: const Text(
                  'Are you sure you want to delete this expense? This action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController(text: _searchQuery);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search Expenses'),
          content: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Search',
              hintText: 'Store name, category, note...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _searchQuery = '');
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _searchQuery = searchController.text);
                Navigator.pop(context);
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    String? tempCategoryFilter = _selectedCategoryFilter;
    String? tempPaymentFilter = _selectedPaymentFilter;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter Expenses'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: tempCategoryFilter == null,
                          onSelected: (selected) {
                            setDialogState(() => tempCategoryFilter = null);
                          },
                        ),
                        ...ExpenseCategory.allCategories.map((category) {
                          return FilterChip(
                            label: Text(category),
                            selected: tempCategoryFilter == category,
                            onSelected: (selected) {
                              setDialogState(() => tempCategoryFilter =
                                  selected ? category : null);
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Payment Method',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: tempPaymentFilter == null,
                          onSelected: (selected) {
                            setDialogState(() => tempPaymentFilter = null);
                          },
                        ),
                        ...PaymentMethod.allMethods.map((method) {
                          return FilterChip(
                            label: Text(method),
                            selected: tempPaymentFilter == method,
                            onSelected: (selected) {
                              setDialogState(() =>
                                  tempPaymentFilter = selected ? method : null);
                            },
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategoryFilter = null;
                      _selectedPaymentFilter = null;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategoryFilter = tempCategoryFilter;
                      _selectedPaymentFilter = tempPaymentFilter;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditExpenseDialog(BuildContext context, ExpenseModel expense) {
    final amountController =
        TextEditingController(text: expense.amount.toString());
    final noteController = TextEditingController(text: expense.note ?? '');
    final storeNameController =
        TextEditingController(text: expense.storeName ?? '');

    String selectedCategory = expense.category;
    String selectedPaymentMethod = expense.paymentMethod;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '${_getCurrencySymbol()} ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: ExpenseCategory.allCategories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedCategory = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedPaymentMethod,
                      decoration:
                          const InputDecoration(labelText: 'Payment Method'),
                      items: PaymentMethod.allMethods.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedPaymentMethod = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: storeNameController,
                      decoration: const InputDecoration(
                        labelText: 'Store Name (Optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (Optional)',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (amountController.text.isEmpty) {
                      return;
                    }

                    final amount = double.tryParse(amountController.text);
                    if (amount == null) {
                      return;
                    }

                    final updatedExpense = expense.copyWith(
                      amount: amount,
                      category: selectedCategory,
                      paymentMethod: selectedPaymentMethod,
                      note: noteController.text.isEmpty
                          ? null
                          : noteController.text,
                      storeName: storeNameController.text.isEmpty
                          ? null
                          : storeNameController.text,
                      updatedAt: DateTime.now(),
                    );

                    await ref
                        .read(expensesProvider.notifier)
                        .updateExpense(updatedExpense);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Expense updated successfully'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportExpensesToCSV(
      BuildContext context, List<ExpenseModel> expenses) async {
    try {
      // Create CSV content
      String csv = 'Date,Category,Store,Payment Method,Amount,Note\n';
      for (var expense in expenses) {
        final date = DateFormat('yyyy-MM-dd').format(expense.date);
        final store = expense.storeName ?? '';
        final note = expense.note?.replaceAll(',', ';') ?? '';
        csv +=
            '$date,${expense.category},$store,${expense.paymentMethod},${expense.amount},$note\n';
      }

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/expenses_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv');

      // Write to file
      await file.writeAsString(csv);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Expenses Export',
        subject:
            'My Expenses - ${DateFormat('MMM yyyy').format(DateTime.now())}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Expenses exported successfully'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatistics(BuildContext context, List<ExpenseModel> expenses) {
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available for statistics')),
      );
      return;
    }

    // Calculate statistics
    final total = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final average = total / expenses.length;
    final max = expenses.reduce((a, b) => a.amount > b.amount ? a : b);
    final min = expenses.reduce((a, b) => a.amount < b.amount ? a : b);

    // Category breakdown
    final categoryTotals = <String, double>{};
    for (var expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0.0) + expense.amount;
    }

    // Payment method breakdown
    final paymentTotals = <String, double>{};
    for (var expense in expenses) {
      paymentTotals[expense.paymentMethod] =
          (paymentTotals[expense.paymentMethod] ?? 0.0) + expense.amount;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Expense Statistics'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary stats
              _buildStatCard(
                  context,
                  'Total Spent',
                  '${_getCurrencySymbol()}${total.toStringAsFixed(2)}',
                  Icons.attach_money),
              _buildStatCard(
                  context,
                  'Average',
                  '${_getCurrencySymbol()}${average.toStringAsFixed(2)}',
                  Icons.trending_flat),
              _buildStatCard(
                  context,
                  'Highest',
                  '${_getCurrencySymbol()}${max.amount.toStringAsFixed(2)} (${max.category})',
                  Icons.arrow_upward),
              _buildStatCard(
                  context,
                  'Lowest',
                  '${_getCurrencySymbol()}${min.amount.toStringAsFixed(2)} (${min.category})',
                  Icons.arrow_downward),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Category breakdown
              const Text(
                'By Category',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...categoryTotals.entries.map((entry) {
                final percentage =
                    (entry.value / total * 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(ExpenseCategory.getIconForCategory(entry.key)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.key)),
                      Text(
                          '${_getCurrencySymbol()}${entry.value.toStringAsFixed(2)} ($percentage%)'),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Payment method breakdown
              const Text(
                'By Payment Method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...paymentTotals.entries.map((entry) {
                final percentage =
                    (entry.value / total * 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.key)),
                      Text(
                          '${_getCurrencySymbol()}${entry.value.toStringAsFixed(2)} ($percentage%)'),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context, String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetProgress(
      BuildContext context, List<ExpenseModel> expenses) {
    // Get budget settings
    final dailyLimit =
        HiveService.getSetting('daily_budget', defaultValue: 0.0) as double?;
    final weeklyLimit =
        HiveService.getSetting('weekly_budget', defaultValue: 0.0) as double?;
    final monthlyLimit =
        HiveService.getSetting('monthly_budget', defaultValue: 0.0) as double?;
    final alertThreshold =
        HiveService.getSetting('alert_threshold', defaultValue: 80.0) as double;

    // Skip if no limits are set
    if ((dailyLimit ?? 0) == 0 &&
        (weeklyLimit ?? 0) == 0 &&
        (monthlyLimit ?? 0) == 0) {
      return const SizedBox.shrink();
    }

    // Calculate total spent
    final total = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    // Determine which limit to show based on selected period
    if (_selectedPeriod == 'Day' && (dailyLimit ?? 0) > 0) {
      return _buildLimitCard(
        context,
        'Daily Budget',
        total,
        dailyLimit!,
        alertThreshold,
        Icons.today,
      );
    } else if (_selectedPeriod == 'Week' && (weeklyLimit ?? 0) > 0) {
      return _buildLimitCard(
        context,
        'Weekly Budget',
        total,
        weeklyLimit!,
        alertThreshold,
        Icons.calendar_view_week,
      );
    } else if (_selectedPeriod == 'Month' && (monthlyLimit ?? 0) > 0) {
      return _buildLimitCard(
        context,
        'Monthly Budget',
        total,
        monthlyLimit!,
        alertThreshold,
        Icons.calendar_month,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLimitCard(
    BuildContext context,
    String title,
    double spent,
    double limit,
    double alertThreshold,
    IconData icon,
  ) {
    final remaining = limit - spent;
    final percentage = (spent / limit).clamp(0.0, 1.0);

    // Calculate threshold as percentage of budget
    // For example: if alertThreshold=80, alert when spent >= 80% of limit
    final thresholdAmount = limit * (alertThreshold / 100);
    final shouldAlert = spent >= thresholdAmount && spent < limit;

    // Determine color based on spending
    Color progressColor;
    if (percentage >= 1.0) {
      progressColor = Colors.red;
    } else if (shouldAlert) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }

    // Check if we need to show alert
    // 🔕 LOCAL NOTIFICATIONS DISABLED - Using MongoDB Server-Side Notifications Instead
    // The MongoDB trigger will handle all budget alerts automatically when expenses sync
    // This prevents duplicate notifications (local + server)

    /* COMMENTED OUT - LOCAL NOTIFICATION CODE
    if (shouldAlert) {
      // Use separate alert tracking for each budget type to know when we last crossed threshold
      final alertKey =
          'last_budget_alert_${title.toLowerCase().replaceAll(' ', '_')}';
      final lastAlertAmount =
          HiveService.getSetting('${alertKey}_amount', defaultValue: 0.0)
              as double;

      print(
          '💬 [Budget Alert] Checking $title: spent=$spent, limit=$limit, remaining=$remaining');
      print(
          '💬 [Budget Alert] Threshold: ${alertThreshold}% = ${_getCurrencySymbol()}${thresholdAmount.toStringAsFixed(2)}');
      print(
          '💬 [Budget Alert] Should alert: $shouldAlert (spent $spent >= ${thresholdAmount.toStringAsFixed(2)})');
      print('💬 [Budget Alert] Last alert was at spent: $lastAlertAmount');

      // Alert every time we cross the threshold with a NEW expense
      // Only skip if the last alert amount is the same (prevent duplicate alerts on same amount)
      if (spent != lastAlertAmount) {
        print(
            '💬 [Budget Alert] ✅ Triggering notification for $title (new expense detected)');

        final percentageUsed = (percentage * 100).toStringAsFixed(0);
        final notificationTitle = '⚠️ Budget Alert - $title!';
        final notificationMessage =
            'You\'ve spent ${_getCurrencySymbol()}${spent.toStringAsFixed(2)} (${percentageUsed}%) of your ${_getCurrencySymbol()}${limit.toStringAsFixed(2)} $title. Only ${_getCurrencySymbol()}${remaining.toStringAsFixed(2)} remaining!';

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // Show push notification
          await _showNotification(notificationTitle, notificationMessage);

          // Save to notification center
          final notification = NotificationModel.create(
            id: _uuid.v4(),
            title: notificationTitle,
            message: notificationMessage,
            type: 'budget_alert',
            data: {
              'spent': spent,
              'limit': limit,
              'remaining': remaining,
              'period': title,
              'threshold': alertThreshold,
              'percentage': percentageUsed,
            },
          );
          await HiveService.addNotification(notification);
          print('💬 [Budget Alert] Notification saved to database');

          // Save the current spent amount to detect new expenses
          await HiveService.saveSetting('${alertKey}_amount', spent);
        });
      } else {
        print(
            '💬 [Budget Alert] ⏭️ Skipping $title - same amount as last alert (no new expense)');
      }
    } else {
      if (spent >= limit) {
        print(
            '💬 [Budget Alert] Budget exceeded - no alert (already over 100%)');
      } else {
        final percentageUsed = (percentage * 100).toStringAsFixed(0);
        print(
            '💬 [Budget Alert] No alert needed - spent $percentageUsed% (threshold is ${alertThreshold}%)');
      }
    }
    */ // END OF COMMENTED CODE - Now using server-side notifications only!

    return Card(
      color: progressColor.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: progressColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: progressColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(percentage * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spent',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    Text(
                      '${_getCurrencySymbol()}${spent.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Remaining',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    Text(
                      '${_getCurrencySymbol()}${remaining.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: remaining < 0 ? Colors.red : Colors.green,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Limit',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    Text(
                      '${_getCurrencySymbol()}${limit.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            if (percentage >= 1.0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Budget exceeded by ${_getCurrencySymbol()}${(-remaining).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (shouldAlert)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Alert threshold reached! ${_getCurrencySymbol()}${remaining.toStringAsFixed(2)} left',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showBudgetSettingsDialog(BuildContext context) {
    final dailyLimitController = TextEditingController(
      text: (HiveService.getSetting('daily_budget', defaultValue: 0.0)
                      as double?) ==
                  0.0 ||
              HiveService.getSetting('daily_budget', defaultValue: 0.0) == null
          ? ''
          : (HiveService.getSetting('daily_budget', defaultValue: 0.0)
                  as double)
              .toStringAsFixed(0),
    );
    final monthlyLimitController = TextEditingController(
      text: (HiveService.getSetting('monthly_budget', defaultValue: 0.0)
                      as double?) ==
                  0.0 ||
              HiveService.getSetting('monthly_budget', defaultValue: 0.0) ==
                  null
          ? ''
          : (HiveService.getSetting('monthly_budget', defaultValue: 0.0)
                  as double)
              .toStringAsFixed(0),
    );
    final weeklyLimitController = TextEditingController(
      text: (HiveService.getSetting('weekly_budget', defaultValue: 0.0)
                      as double?) ==
                  0.0 ||
              HiveService.getSetting('weekly_budget', defaultValue: 0.0) == null
          ? ''
          : (HiveService.getSetting('weekly_budget', defaultValue: 0.0)
                  as double)
              .toStringAsFixed(0),
    );
    final alertThresholdController = TextEditingController(
      text: (HiveService.getSetting('alert_threshold', defaultValue: 80.0)
              as double)
          .toStringAsFixed(0),
    );

    // Currency options
    final currencies = {
      '\$': 'USD - US Dollar',
      '€': 'EUR - Euro',
      '£': 'GBP - British Pound',
      '¥': 'JPY - Japanese Yen',
      '₹': 'INR - Indian Rupee',
      '৳': 'BDT - Bangladeshi Taka',
      'R\$': 'BRL - Brazilian Real',
      'C\$': 'CAD - Canadian Dollar',
      'A\$': 'AUD - Australian Dollar',
      'CHF': 'CHF - Swiss Franc',
      '¢': 'CNY - Chinese Yuan',
      '₽': 'RUB - Russian Ruble',
      '₩': 'KRW - South Korean Won',
      '₱': 'PHP - Philippine Peso',
      '₫': 'VND - Vietnamese Dong',
      'Rp': 'IDR - Indonesian Rupiah',
      '฿': 'THB - Thai Baht',
      'RM': 'MYR - Malaysian Ringgit',
      'S\$': 'SGD - Singapore Dollar',
      'kr': 'SEK - Swedish Krona',
    };

    String selectedCurrency =
        HiveService.getSetting('currency_symbol', defaultValue: '\$') as String;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.savings),
                  SizedBox(width: 12),
                  Text('Budget Settings'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set spending limits to track your budget',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 20),

                    // Currency Selector
                    DropdownButtonFormField<String>(
                      value: selectedCurrency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      items: currencies.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                              '${entry.key} - ${entry.value.split(' - ')[1]}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedCurrency = value!);
                      },
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: dailyLimitController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Daily Limit',
                        hintText: '0 = No limit',
                        prefixText: '$selectedCurrency ',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.today),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: weeklyLimitController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Weekly Limit',
                        hintText: '0 = No limit',
                        prefixText: '$selectedCurrency ',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.calendar_view_week),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: monthlyLimitController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Monthly Limit',
                        hintText: '0 = No limit',
                        prefixText: '$selectedCurrency ',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.calendar_month),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: alertThresholdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Alert Threshold (%)',
                        hintText: 'e.g., 80 for 80%',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notifications_active),
                        helperText:
                            'Alert when you\'ve spent this percentage of your budget',
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Example: If limit is $selectedCurrency 1000 and threshold is 80%, you\'ll be alerted when you spend $selectedCurrency 800 (80% of budget)',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final dailyLimit =
                        double.tryParse(dailyLimitController.text) ?? 0.0;
                    final weeklyLimit =
                        double.tryParse(weeklyLimitController.text) ?? 0.0;
                    final monthlyLimit =
                        double.tryParse(monthlyLimitController.text) ?? 0.0;
                    final alertThreshold =
                        double.tryParse(alertThresholdController.text) ?? 100.0;

                    // Validate alert threshold (must be between 0-100%)
                    if (alertThreshold < 0 || alertThreshold > 100) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.error, color: Colors.white),
                                SizedBox(width: 12),
                                Text('Alert threshold must be between 0-100%'),
                              ],
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return; // Don't save if invalid
                    }

                    // Save to Hive with correct keys
                    await HiveService.saveSetting(
                        'currency_symbol', selectedCurrency);
                    await HiveService.saveSetting(
                        'daily_budget', dailyLimit == 0.0 ? null : dailyLimit);
                    await HiveService.saveSetting('weekly_budget',
                        weeklyLimit == 0.0 ? null : weeklyLimit);
                    await HiveService.saveSetting('monthly_budget',
                        monthlyLimit == 0.0 ? null : monthlyLimit);
                    await HiveService.saveSetting(
                        'alert_threshold', alertThreshold);

                    // Sync to MongoDB
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await UserSettingsSyncService.updateSetting(
                        userId: user.uid,
                        currencySymbol: selectedCurrency,
                        dailyBudget: dailyLimit == 0.0 ? null : dailyLimit,
                        weeklyBudget: weeklyLimit == 0.0 ? null : weeklyLimit,
                        monthlyBudget:
                            monthlyLimit == 0.0 ? null : monthlyLimit,
                        alertThreshold: alertThreshold,
                      );
                    }

                    setState(() {}); // Refresh UI

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Budget settings saved & synced'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getCurrencySymbol() {
    return HiveService.getSetting('currency_symbol', defaultValue: '\$')
        as String;
  }

  /// Check all budget alerts (daily, weekly, monthly) after adding an expense
  /// This ensures notifications are sent regardless of which tab is currently active
  Future<void> _checkAllBudgetAlerts() async {
    final alertThreshold =
        HiveService.getSetting('alert_threshold', defaultValue: 80.0) as double;
    final expenses = ref.read(expensesProvider);

    // Check daily budget
    await _checkBudgetAlert(
      budgetKey: 'daily_budget',
      alertKey: 'last_budget_alert_daily_budget',
      title: 'Daily Budget',
      expenses: expenses,
      alertThreshold: alertThreshold,
      getDateRange: () {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        return (start, end);
      },
    );

    // Check weekly budget
    await _checkBudgetAlert(
      budgetKey: 'weekly_budget',
      alertKey: 'last_budget_alert_weekly_budget',
      title: 'Weekly Budget',
      expenses: expenses,
      alertThreshold: alertThreshold,
      getDateRange: () {
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekStartMidnight =
            DateTime(weekStart.year, weekStart.month, weekStart.day);
        final weekEnd = weekStartMidnight.add(const Duration(days: 7));
        return (weekStartMidnight, weekEnd);
      },
    );

    // Check monthly budget
    await _checkBudgetAlert(
      budgetKey: 'monthly_budget',
      alertKey: 'last_budget_alert_monthly_budget',
      title: 'Monthly Budget',
      expenses: expenses,
      alertThreshold: alertThreshold,
      getDateRange: () {
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1);
        return (monthStart, monthEnd);
      },
    );
  }

  /// Check a specific budget and send notification if threshold crossed
  Future<void> _checkBudgetAlert({
    required String budgetKey,
    required String alertKey,
    required String title,
    required List<ExpenseModel> expenses,
    required double alertThreshold,
    required (DateTime, DateTime) Function() getDateRange,
  }) async {
    // Get budget limit
    final budget = HiveService.getSetting(budgetKey) as double?;
    if (budget == null || budget == 0.0) return;

    // Get date range
    final (start, end) = getDateRange();

    // Calculate spent amount
    final periodExpenses = expenses.where((expense) {
      return expense.date.isAfter(start) && expense.date.isBefore(end);
    }).toList();

    final spent = periodExpenses.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    // Check if threshold crossed
    final thresholdAmount = budget * (alertThreshold / 100);
    final shouldAlert = spent >= thresholdAmount && spent < budget;

    if (shouldAlert) {
      final lastAlertAmount =
          HiveService.getSetting('${alertKey}_amount', defaultValue: 0.0)
              as double;

      // Only alert if this is a new amount (new expense added)
      if (spent != lastAlertAmount) {
        // Send notification
        await _sendBudgetNotification(
          title: '$title Alert',
          body:
              'You\'ve spent ${_getCurrencySymbol()}${spent.toStringAsFixed(2)} of ${_getCurrencySymbol()}${budget.toStringAsFixed(2)} (${alertThreshold.toInt()}% threshold reached)',
        );

        // Save the current spent amount
        await HiveService.saveSetting('${alertKey}_amount', spent);
      }
    }
  }

  /// Send a budget notification
  Future<void> _sendBudgetNotification({
    required String title,
    required String body,
  }) async {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'budget_alerts',
        'Budget Alerts',
        channelDescription: 'Notifications for budget threshold alerts',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        platformChannelSpecifics,
      );

      print('✅ [ExpenseScreen] Budget notification sent: $title');
    } catch (e) {
      print('❌ [ExpenseScreen] Failed to send notification: $e');
    }
  }
}
