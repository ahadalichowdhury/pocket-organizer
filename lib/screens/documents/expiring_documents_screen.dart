import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/document_model.dart';
import '../../providers/app_providers.dart';

class ExpiringDocumentsScreen extends ConsumerStatefulWidget {
  const ExpiringDocumentsScreen({super.key});

  @override
  ConsumerState<ExpiringDocumentsScreen> createState() =>
      _ExpiringDocumentsScreenState();
}

class _ExpiringDocumentsScreenState
    extends ConsumerState<ExpiringDocumentsScreen> {
  String _sortBy = 'urgency'; // urgency, name, date

  /// Get urgency level for a document (0-3, lower is more urgent)
  int _getUrgencyLevel(DocumentModel doc) {
    if (doc.expiryDate == null) return 4;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(
      doc.expiryDate!.year,
      doc.expiryDate!.month,
      doc.expiryDate!.day,
    );

    final daysUntilExpiry = expiryDate.difference(today).inDays;

    if (daysUntilExpiry < 0) return 0; // Expired - most urgent
    if (daysUntilExpiry <= 1) return 1; // Critical (0-1 days)
    if (daysUntilExpiry <= 7) return 2; // Soon (2-7 days)
    if (daysUntilExpiry <= 30) return 3; // Upcoming (8-30 days)
    return 4; // Valid (30+ days) - least urgent
  }

  /// Get status badge emoji and color
  Map<String, dynamic> _getStatusBadge(DocumentModel doc) {
    final urgency = _getUrgencyLevel(doc);

    switch (urgency) {
      case 0: // Expired
        return {'emoji': '⚫', 'color': Colors.grey, 'label': 'Expired'};
      case 1: // Critical
        return {'emoji': '🔴', 'color': Colors.red, 'label': 'Critical'};
      case 2: // Soon
        return {'emoji': '🟠', 'color': Colors.orange, 'label': 'Soon'};
      case 3: // Upcoming
        return {
          'emoji': '🟡',
          'color': Colors.yellow.shade700,
          'label': 'Upcoming'
        };
      default: // Valid
        return {'emoji': '🟢', 'color': Colors.green, 'label': 'Valid'};
    }
  }

  /// Get days until expiry text
  String _getDaysText(DocumentModel doc) {
    if (doc.expiryDate == null) return 'No expiry date';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(
      doc.expiryDate!.year,
      doc.expiryDate!.month,
      doc.expiryDate!.day,
    );

    final daysUntilExpiry = expiryDate.difference(today).inDays;

    if (daysUntilExpiry < 0) {
      final daysExpired = -daysUntilExpiry;
      return 'Expired $daysExpired day${daysExpired != 1 ? 's' : ''} ago';
    } else if (daysUntilExpiry == 0) {
      return 'Expires today!';
    } else if (daysUntilExpiry == 1) {
      return 'Expires tomorrow';
    } else {
      return 'Expires in $daysUntilExpiry days';
    }
  }

  /// Sort documents by selected criteria
  List<DocumentModel> _sortDocuments(List<DocumentModel> docs) {
    final sortedDocs = List<DocumentModel>.from(docs);

    switch (_sortBy) {
      case 'urgency':
        sortedDocs.sort((a, b) {
          final urgencyA = _getUrgencyLevel(a);
          final urgencyB = _getUrgencyLevel(b);
          return urgencyA.compareTo(urgencyB);
        });
        break;
      case 'name':
        sortedDocs.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'date':
        sortedDocs.sort((a, b) {
          if (a.expiryDate == null && b.expiryDate == null) return 0;
          if (a.expiryDate == null) return 1;
          if (b.expiryDate == null) return -1;
          return a.expiryDate!.compareTo(b.expiryDate!);
        });
        break;
    }

    return sortedDocs;
  }

  @override
  Widget build(BuildContext context) {
    // Watch the documents state (not the notifier) to auto-rebuild on changes
    // ignore: unused_local_variable
    final documents = ref.watch(documentsProvider);
    final documentsNotifier = ref.read(documentsProvider.notifier);

    // Get expiring documents from the watched state
    final expiringDocuments = documentsNotifier
        .getExpiringDocuments(365); // Get all with expiry dates
    final sortedDocuments = _sortDocuments(expiringDocuments);

    // Group by urgency
    final expired =
        sortedDocuments.where((d) => _getUrgencyLevel(d) == 0).toList();
    final critical =
        sortedDocuments.where((d) => _getUrgencyLevel(d) == 1).toList();
    final soon =
        sortedDocuments.where((d) => _getUrgencyLevel(d) == 2).toList();
    final upcoming =
        sortedDocuments.where((d) => _getUrgencyLevel(d) == 3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiring Documents'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'urgency',
                child: Row(
                  children: [
                    Icon(
                      Icons.priority_high,
                      color: _sortBy == 'urgency'
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort by Urgency'),
                    if (_sortBy == 'urgency') ...[
                      const Spacer(),
                      Icon(Icons.check, color: Theme.of(context).primaryColor),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      color: _sortBy == 'name'
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort by Name'),
                    if (_sortBy == 'name') ...[
                      const Spacer(),
                      Icon(Icons.check, color: Theme.of(context).primaryColor),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: _sortBy == 'date'
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort by Date'),
                    if (_sortBy == 'date') ...[
                      const Spacer(),
                      Icon(Icons.check, color: Theme.of(context).primaryColor),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: expiringDocuments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No expiring documents',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All your documents are valid or have no expiry dates',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.read(documentsProvider.notifier).loadDocuments();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Summary Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expiry Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem(
                                  '⚫', 'Expired', expired.length, Colors.grey),
                              _buildSummaryItem('🔴', 'Critical',
                                  critical.length, Colors.red),
                              _buildSummaryItem(
                                  '🟠', 'Soon', soon.length, Colors.orange),
                              _buildSummaryItem('🟡', 'Upcoming',
                                  upcoming.length, Colors.yellow.shade700),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Legend
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '⚫ Expired  •  🔴 0-1 days  •  🟠 2-7 days  •  🟡 8-30 days',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Documents List
                  ...sortedDocuments.map((doc) {
                    final badge = _getStatusBadge(doc);
                    final daysText = _getDaysText(doc);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: _getUrgencyLevel(doc) <= 2 ? 3 : 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              (badge['color'] as Color).withOpacity(0.2),
                          child: Text(
                            badge['emoji'],
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Text(
                          doc.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              daysText,
                              style: TextStyle(
                                color: badge['color'],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (doc.expiryDate != null)
                              Text(
                                'Expiry: ${DateFormat('MMM d, y').format(doc.expiryDate!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (badge['color'] as Color).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                badge['label'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: badge['color'],
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/document-details',
                            arguments: doc.id,
                          );
                        },
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryItem(String emoji, String label, int count, Color color) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
