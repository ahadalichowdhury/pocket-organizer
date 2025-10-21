import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../widgets/document_tile.dart';

class FolderDetailsScreen extends ConsumerWidget {
  final String folderId;

  const FolderDetailsScreen({
    super.key,
    required this.folderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Try to find the folder, return null if not found (e.g., during deletion)
    final folders = ref.watch(foldersProvider);
    final folder = folders.cast<dynamic>().firstWhere(
          (f) => f.id == folderId,
          orElse: () => null,
        );

    // If folder is not found (deleted), navigate back
    if (folder == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
      // Return empty scaffold while navigating
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final documents = ref
        .watch(documentsProvider)
        .where((doc) => doc.folderId == folderId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showFolderOptions(context, ref, folder);
            },
          ),
        ],
      ),
      body: documents.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No documents yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capture a document to add it here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/capture-document');
                    },
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Capture Document'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                return DocumentTile(
                  document: documents[index],
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/document-details',
                      arguments: documents[index].id,
                    );
                  },
                  onLongPress: () {
                    _showDocumentOptions(context, ref, documents[index]);
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'folder_details_fab',
        onPressed: () {
          Navigator.pushNamed(context, '/capture-document');
        },
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  void _showFolderOptions(BuildContext context, WidgetRef ref, folder) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename Folder'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameFolderDialog(context, ref, folder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Folder Info'),
                onTap: () {
                  Navigator.pop(context);
                  _showFolderInfoDialog(context, ref, folder);
                },
              ),
              // Show delete option for all folders (including system folders)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Folder',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await _showDeleteFolderConfirmation(context, ref, folder);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeleteFolderConfirmation(
      BuildContext context, WidgetRef ref, folder) async {
    final documents = ref
        .read(documentsProvider)
        .where((doc) => doc.folderId == folder.id)
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 12),
            Text('Delete Folder?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${folder.name}"?'),
            const SizedBox(height: 12),
            if (documents.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This folder contains ${documents.length} document(s). They will also be deleted!',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final folderName = folder.name;
        final success =
            await ref.read(foldersProvider.notifier).deleteFolder(folder.id);

        if (context.mounted) {
          if (success) {
            // Success message will show on folders screen after auto-navigation
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Text('Folder "$folderName" deleted'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete folder'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting folder: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showRenameFolderDialog(BuildContext context, WidgetRef ref, folder) {
    final nameController = TextEditingController(text: folder.name);
    String? selectedIcon = folder.iconName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Rename Folder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Folder Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Icon',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: DocumentType.allTypes.map((type) {
                        final icon = DocumentType.getIconForType(type);
                        final isSelected = selectedIcon == icon;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedIcon = icon;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.2)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              icon,
                              style: TextStyle(
                                fontSize: 24,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
                    if (nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a folder name'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final updatedFolder = folder.copyWith(
                      name: nameController.text,
                      iconName: selectedIcon,
                      updatedAt: DateTime.now(),
                    );
                    await ref
                        .read(foldersProvider.notifier)
                        .updateFolder(updatedFolder);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Folder renamed successfully'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
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

  void _showFolderInfoDialog(BuildContext context, WidgetRef ref, folder) {
    // Get documents in this folder to calculate size
    final documents = ref
        .read(documentsProvider)
        .where((doc) => doc.folderId == folder.id)
        .toList();

    // Calculate total folder size
    int totalSize = 0;
    for (var doc in documents) {
      try {
        final file = File(doc.localImagePath);
        if (file.existsSync()) {
          totalSize += file.lengthSync();
        }
      } catch (e) {
        // Skip files that can't be accessed
      }
    }

    // Format size to human-readable format
    String formatBytes(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
      if (bytes < 1024 * 1024 * 1024)
        return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (folder.iconName != null) ...[
              Text(folder.iconName!, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                folder.name,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (folder.description != null &&
                  folder.description!.isNotEmpty) ...[
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  folder.description!,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
              ],
              _buildInfoRow(
                icon: Icons.description,
                label: 'Documents',
                value: '${folder.documentCount}',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.storage,
                label: 'Folder Size',
                value: formatBytes(totalSize),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.calendar_today,
                label: 'Created',
                value:
                    DateFormat('MMM d, yyyy • h:mm a').format(folder.createdAt),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.update,
                label: 'Last Updated',
                value:
                    DateFormat('MMM d, yyyy • h:mm a').format(folder.updatedAt),
              ),
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
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
    );
  }

  void _showDocumentOptions(BuildContext context, WidgetRef ref, document) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_move),
                title: const Text('Move to Another Folder'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement move
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Document?'),
                      content: const Text(
                          'This action cannot be undone. The document will be permanently deleted.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await ref
                        .read(documentsProvider.notifier)
                        .deleteDocument(document.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Document deleted')),
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
}
