import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../widgets/document_tile.dart';
import '../../widgets/expense_summary_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _searchType = 'All'; // All, Documents, Expenses

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final documentsNotifier = ref.watch(documentsProvider.notifier);
    final expensesNotifier = ref.watch(expensesProvider.notifier);

    final searchedDocuments = _searchQuery.isEmpty
        ? []
        : documentsNotifier.searchDocuments(_searchQuery);

    final searchedExpenses = _searchQuery.isEmpty
        ? []
        : expensesNotifier.searchExpenses(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search documents & expenses...',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Type Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: ['All', 'Documents', 'Expenses'].map((type) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: _searchType == type,
                    onSelected: (selected) {
                      setState(() => _searchType = type);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Search Results
          Expanded(
            child: _searchQuery.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Search for documents or expenses',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter keywords, tags, or text',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade500,
                                  ),
                        ),
                      ],
                    ),
                  )
                : (_searchType == 'All' || _searchType == 'Documents') &&
                        searchedDocuments.isEmpty &&
                        (_searchType == 'All' || _searchType == 'Expenses') &&
                        searchedExpenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try different keywords',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey.shade500,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Documents Section
                          if ((_searchType == 'All' ||
                                  _searchType == 'Documents') &&
                              searchedDocuments.isNotEmpty) ...[
                            Text(
                              'Documents (${searchedDocuments.length})',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            ...searchedDocuments.map((doc) {
                              return DocumentTile(
                                document: doc,
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/document-details',
                                    arguments: doc.id,
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 24),
                          ],

                          // Expenses Section
                          if ((_searchType == 'All' ||
                                  _searchType == 'Expenses') &&
                              searchedExpenses.isNotEmpty) ...[
                            Text(
                              'Expenses (${searchedExpenses.length})',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            ...searchedExpenses.map((expense) {
                              return ExpenseTile(
                                expense: expense,
                                onTap: () {
                                  // Show expense details
                                },
                              );
                            }),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
