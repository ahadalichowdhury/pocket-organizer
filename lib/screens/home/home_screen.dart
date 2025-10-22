import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/document_model.dart';
import '../../data/services/hive_service.dart';
import '../../providers/app_providers.dart';
import '../../widgets/document_tile.dart';
import '../../widgets/folder_card.dart';
import '../documents/expiring_documents_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _getCurrencySymbol() {
    return HiveService.getSetting('currency_symbol', defaultValue: '\$')
        as String;
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(foldersProvider);
    final documentsNotifier = ref.watch(documentsProvider.notifier);
    final expenses =
        ref.watch(expensesProvider); // Watch the actual expense list
    final user = ref.watch(currentUserProvider);

    final recentDocuments = documentsNotifier.getRecentDocuments(7);
    final expiringDocuments = documentsNotifier.getExpiringDocuments(30);

    // Calculate today's expenses from the actual expense list
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final todayExpenses = expenses
        .where((e) =>
            e.date.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
            e.date.isBefore(now.add(const Duration(days: 1))))
        .toList();

    // Calculate this month's total from the actual expense list
    final startOfMonth = DateTime(now.year, now.month, 1);
    final monthExpenses = expenses
        .where((e) =>
            e.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))))
        .fold(0.0, (sum, expense) => sum + expense.amount);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pocket Organizer'),
            if (user != null)
              Text(
                'Hello, ${user.displayName ?? user.email}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.pushNamed(context, '/notifications');
                },
              ),
              // Unread notification badge
              Positioned(
                right: 8,
                top: 8,
                child: HiveService.getUnreadNotificationCount() > 0
                    ? Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${HiveService.getUnreadNotificationCount()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(foldersProvider.notifier).loadFolders();
          ref.read(documentsProvider.notifier).loadDocuments();
          ref.read(expensesProvider.notifier).loadExpenses();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Stats
              _buildQuickStats(
                context,
                totalFolders: folders.length,
                totalDocuments: recentDocuments.length,
                monthExpenses: monthExpenses,
              ),
              const SizedBox(height: 24),

              // Expense Summary
              if (todayExpenses.isNotEmpty) ...[
                _buildSectionHeader(context, 'Today\'s Expenses', () {
                  Navigator.pushNamed(context, '/expenses');
                }),
                const SizedBox(height: 12),
                // Show only 2 latest expenses (non-clickable)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: todayExpenses.take(2).length,
                  itemBuilder: (context, index) {
                    final expense = todayExpenses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              expense.category.isNotEmpty
                                  ? expense.category[0]
                                  : '💰',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        title: Text(
                          expense.storeName ?? expense.category,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${expense.category} • ${expense.paymentMethod}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                        trailing: Text(
                          '${_getCurrencySymbol()}${expense.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        // No onTap - items are non-clickable
                        enabled: false,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Expiring Documents Alert
              if (expiringDocuments.isNotEmpty) ...[
                _buildSectionHeader(context, 'Expiring Soon', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExpiringDocumentsScreen(),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  color: Colors.orange.shade50,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExpiringDocumentsScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange.shade700,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${expiringDocuments.length} document${expiringDocuments.length != 1 ? 's' : ''} expiring soon',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Within next 30 days',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.orange.shade700,
                              ),
                            ],
                          ),
                          if (expiringDocuments.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  _getUrgencyEmoji(_getMostUrgentDocument(expiringDocuments)),
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Most urgent: ${_getMostUrgentDocument(expiringDocuments)?.title ?? "Unknown"}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _getDaysUntilExpiry(_getMostUrgentDocument(expiringDocuments)),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Recent Documents
              _buildSectionHeader(context, 'Recent Documents', () {
                Navigator.pushNamed(context, '/documents');
              }),
              const SizedBox(height: 12),
              if (recentDocuments.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No documents yet',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to capture your first document',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentDocuments.take(2).length,
                  itemBuilder: (context, index) {
                    return DocumentTile(
                      document: recentDocuments[index],
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/document-details',
                          arguments: recentDocuments[index].id,
                        );
                      },
                    );
                  },
                ),
              const SizedBox(height: 24),

              // Quick Access Folders
              _buildSectionHeader(context, 'Quick Access', () {
                Navigator.pushNamed(context, '/folders');
              }),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: folders.take(4).length,
                itemBuilder: (context, index) {
                  return FolderCard(
                    folder: folders[index],
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/folder-details',
                        arguments: folders[index].id,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_fab',
        onPressed: () {
          Navigator.pushNamed(context, '/capture-document');
        },
        icon: const Icon(Icons.camera_alt),
        label: const Text('Capture'),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, VoidCallback onViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        TextButton(
          onPressed: onViewAll,
          child: const Text('View All'),
        ),
      ],
    );
  }

  Widget _buildQuickStats(
    BuildContext context, {
    required int totalFolders,
    required int totalDocuments,
    required double monthExpenses,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.folder,
            label: 'Folders',
            value: totalFolders.toString(),
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.description,
            label: 'Documents',
            value: totalDocuments.toString(),
            color: Colors.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.account_balance_wallet,
            label: 'This Month',
            value: '${_getCurrencySymbol()}${monthExpenses.toStringAsFixed(0)}',
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Get the most urgent document (closest to expiry)
  DocumentModel? _getMostUrgentDocument(List<DocumentModel> documents) {
    if (documents.isEmpty) return null;

    return documents.reduce((a, b) {
      if (a.expiryDate == null) return b;
      if (b.expiryDate == null) return a;

      final now = DateTime.now();
      final daysA = a.expiryDate!.difference(now).inDays;
      final daysB = b.expiryDate!.difference(now).inDays;

      return daysA < daysB ? a : b;
    });
  }

  /// Get days until expiry text
  String _getDaysUntilExpiry(DocumentModel? doc) {
    if (doc?.expiryDate == null) return '';

    final now = DateTime.now();
    final days = doc!.expiryDate!.difference(now).inDays;

    if (days < 0) return 'Expired';
    if (days == 0) return 'Today!';
    if (days == 1) return '1 day';
    return '$days days';
  }

  /// Get urgency emoji
  String _getUrgencyEmoji(DocumentModel? doc) {
    if (doc?.expiryDate == null) return '🟢';

    final now = DateTime.now();
    final days = doc!.expiryDate!.difference(now).inDays;

    if (days < 0) return '⚫'; // Expired
    if (days <= 1) return '🔴'; // Critical
    if (days <= 7) return '🟠'; // Soon
    if (days <= 30) return '🟡'; // Upcoming
    return '🟢'; // Valid
  }
}
