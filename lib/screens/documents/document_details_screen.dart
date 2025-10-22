import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/document_model.dart';
import '../../data/services/image_cache_service.dart';
import '../../providers/app_providers.dart';
import '../../widgets/full_screen_image_viewer.dart';

class DocumentDetailsScreen extends ConsumerWidget {
  final String documentId;

  const DocumentDetailsScreen({
    super.key,
    required this.documentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentsProvider);
    final document = documents.cast<dynamic>().firstWhere(
          (doc) => doc.id == documentId,
          orElse: () => null,
        );

    // If document is deleted, navigate back
    if (document == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final folders = ref.watch(foldersProvider);
    final folder = folders.cast<dynamic>().firstWhere(
          (f) => f.id == document.folderId,
          orElse: () => null,
        );

    if (folder == null) {
      return const Scaffold(
        body: Center(child: Text('Folder not found')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(document.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareDocument(context, document),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showDocumentOptions(context, ref, document, folder);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Image preview - tap to view fullscreen
          Expanded(
            child: Center(
              child: FutureBuilder<String?>(
                future: ImageCacheService.getLocalImagePath(
                  document.localImagePath,
                  document.cloudImageUrl,
                  document.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Loading image...',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasData && snapshot.data != null) {
                    final imagePath = snapshot.data!;
                    return GestureDetector(
                      onTap: () {
                        // Open full-screen image viewer
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => FullScreenImageViewer(
                              imagePath: imagePath,
                              title: document.title,
                            ),
                          ),
                        );
                      },
                      child: Hero(
                        tag: 'document_${document.id}',
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.file(
                              File(imagePath),
                              fit: BoxFit.contain,
                              key: ValueKey(
                                  '${document.id}_${document.updatedAt.millisecondsSinceEpoch}'),
                            ),
                            // Tap hint overlay
                            Positioned(
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.zoom_in,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Tap to view fullscreen',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
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

                  // No image available
                  return Container(
                    color: Colors.grey.shade900,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.white54,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Image not found',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Document info bottom sheet
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Document details
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        document.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getTypeColor(document.documentType)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          document.documentType,
                          style: TextStyle(
                            color: _getTypeColor(document.documentType),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info rows
                      _buildInfoRow(
                        Icons.folder,
                        'Folder',
                        folder.name,
                        context,
                      ),
                      _buildInfoRow(
                        Icons.calendar_today,
                        'Created',
                        DateFormat('MMM d, yyyy').format(document.createdAt),
                        context,
                      ),
                      if (document.expiryDate != null)
                        _buildInfoRow(
                          Icons.event_busy,
                          'Expires',
                          DateFormat('MMM d, yyyy')
                              .format(document.expiryDate!),
                          context,
                        ),
                      if (document.tags.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.label,
                                  size: 20, color: Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tags',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: document.tags
                                          .map<Widget>((tag) => Chip(
                                                label: Text(
                                                  tag,
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 0),
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ))
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (document.notes != null && document.notes!.isNotEmpty)
                        _buildInfoRow(
                          Icons.note,
                          'Notes',
                          document.notes!,
                          context,
                          maxLines: 5,
                        ),
                      if (document.ocrText != null &&
                          document.ocrText!.isNotEmpty)
                        _buildInfoRow(
                          Icons.text_fields,
                          'Extracted Text',
                          document.ocrText!,
                          context,
                          maxLines: 3,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    BuildContext context, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'warranty':
        return Colors.blue;
      case 'prescription':
        return Colors.red;
      case 'receipt':
        return Colors.green;
      case 'bill':
        return Colors.orange;
      case 'personal id':
        return Colors.purple;
      case 'invoice':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _showDocumentOptions(
    BuildContext context,
    WidgetRef ref,
    document,
    folder,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Save to Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  await _saveToGallery(context, document);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, ref, document);
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move),
                title: const Text('Move to Another Folder'),
                onTap: () async {
                  Navigator.pop(context);
                  await _showMoveToFolderDialog(context, ref, document);
                },
              ),
              if (document.expiryDate != null)
                ListTile(
                  leading:
                      const Icon(Icons.calendar_today, color: Colors.orange),
                  title: const Text('Edit Expiry Date'),
                  subtitle: Text(
                      'Current: ${DateFormat('MMM d, y').format(document.expiryDate!)}'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditExpiryDateDialog(context, ref, document);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context); // Close bottom sheet
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Document?'),
                      content: const Text(
                        'This action cannot be undone. The document will be permanently deleted.',
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
                    print('🗑️ Deleting document ${document.id}');

                    // FIRST: Navigate back from DocumentDetailsScreen to avoid "Bad state: No element"
                    if (context.mounted) {
                      Navigator.pop(context); // Close document details screen
                    }

                    // THEN: Delete the document from database
                    await ref
                        .read(documentsProvider.notifier)
                        .deleteDocument(document.id);

                    print('✅ Document deleted, invalidating providers...');
                    // Force refresh the providers
                    ref.invalidate(documentsProvider);
                    ref.invalidate(foldersProvider);

                    // Show success message
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Deleted successfully'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
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

  // Share document image
  Future<void> _shareDocument(BuildContext context, dynamic document) async {
    try {
      // Get cached image path
      final imagePath = await ImageCacheService.getLocalImagePath(
        document.localImagePath,
        document.cloudImageUrl,
        document.id,
      );

      if (imagePath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image file not found')),
          );
        }
        return;
      }

      await Share.shareXFiles(
        [XFile(imagePath)],
        text: '${document.title} - ${document.documentType}',
        subject: document.title,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  // Save document image to gallery
  Future<void> _saveToGallery(BuildContext context, dynamic document) async {
    try {
      // Get cached image path
      final imagePath = await ImageCacheService.getLocalImagePath(
        document.localImagePath,
        document.cloudImageUrl,
        document.id,
      );

      if (imagePath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image file not found')),
          );
        }
        return;
      }

      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saving to gallery...')),
        );
      }

      // Save to gallery using Gal package
      await Gal.putImage(imagePath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Image saved to gallery!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on GalException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.type.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Move document to another folder
  Future<void> _showMoveToFolderDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic document,
  ) async {
    final folders = ref.read(foldersProvider);
    String? selectedFolderId = document.folderId;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Move to Folder'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select a folder to move this document to:'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedFolderId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Folder',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder),
                      ),
                      items: folders.map((folder) {
                        return DropdownMenuItem(
                          value: folder.id,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.folder,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  folder.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedFolderId = value;
                        });
                      },
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
                  onPressed: () => Navigator.pop(context, selectedFolderId),
                  child: const Text('Move'),
                ),
              ],
            );
          },
        );
      },
    );

    print(
        '📋 Dialog result: $result, Current folder: ${document.folderId}, Same? ${result == document.folderId}');

    if (result != null && result != document.folderId) {
      print(
          '🔄 Moving document ${document.id} from ${document.folderId} to $result');

      await ref.read(documentsProvider.notifier).moveDocument(
            document.id,
            result,
          );

      print('✅ Document moved, invalidating providers...');
      // Force refresh the providers
      ref.invalidate(documentsProvider);
      ref.invalidate(foldersProvider);

      // Navigate back to folder list after move
      if (context.mounted) {
        Navigator.pop(context); // Go back to folder

        final newFolder = folders.firstWhere((f) => f.id == result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Moved to ${newFolder.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // Edit document (rename and crop)
  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic document,
  ) async {
    final TextEditingController titleController =
        TextEditingController(text: document.title);
    final TextEditingController notesController =
        TextEditingController(text: document.notes ?? '');

    String selectedType = document.documentType;
    DateTime? selectedExpiryDate = document.expiryDate;
    List<String> selectedTags = List<String>.from(document.tags);

    // Create a ValueNotifier to track document updates
    final documentNotifier = ValueNotifier<dynamic>(document);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ValueListenableBuilder(
              valueListenable: documentNotifier,
              builder: (context, currentDoc, child) {
                return AlertDialog(
                  title: const Text('Edit Document'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Document Name
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Document Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.title),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Document Type
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Document Type',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: DocumentType.allTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(
                                  '${DocumentType.getIconForType(type)} $type'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedType = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Expiry Date (for warranties and prescriptions)
                        if (selectedType == DocumentType.warranty ||
                            selectedType == DocumentType.prescription) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Expiry Date'),
                            subtitle: Text(
                              selectedExpiryDate != null
                                  ? '${selectedExpiryDate!.day}/${selectedExpiryDate!.month}/${selectedExpiryDate!.year}'
                                  : 'Tap to select',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: selectedExpiryDate ??
                                      DateTime.now()
                                          .add(const Duration(days: 365)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 3650)),
                                );
                                if (date != null) {
                                  setState(() => selectedExpiryDate = date);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Notes
                        TextField(
                          controller: notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notes),
                            hintText: 'Add additional details',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Tags
                        const Text(
                          'Tags',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...selectedTags.map((tag) => Chip(
                                  label: Text(tag),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                  onDeleted: () {
                                    setState(() => selectedTags.remove(tag));
                                  },
                                )),
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 18),
                              label: const Text('Add Tag'),
                              onPressed: () async {
                                final tag = await showDialog<String>(
                                  context: context,
                                  builder: (context) {
                                    final tagController =
                                        TextEditingController();
                                    return AlertDialog(
                                      title: const Text('Add Tag'),
                                      content: TextField(
                                        controller: tagController,
                                        decoration: const InputDecoration(
                                          labelText: 'Tag Name',
                                          border: OutlineInputBorder(),
                                        ),
                                        autofocus: true,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            final text =
                                                tagController.text.trim();
                                            if (text.isNotEmpty) {
                                              Navigator.pop(context, text);
                                            }
                                          },
                                          child: const Text('Add'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (tag != null &&
                                    !selectedTags.contains(tag)) {
                                  setState(() => selectedTags.add(tag));
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                        final newTitle = titleController.text.trim();
                        final newNotes = notesController.text.trim();

                        if (newTitle.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ Document name cannot be empty'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        // Use the latest document from documentNotifier (which has cropped image)
                        final updatedDoc = currentDoc.copyWith(
                          title: newTitle,
                          documentType: selectedType,
                          expiryDate: selectedExpiryDate,
                          notes: newNotes.isEmpty ? null : newNotes,
                          tags: selectedTags,
                          updatedAt: DateTime.now(), // Force UI refresh
                        );

                        await ref
                            .read(documentsProvider.notifier)
                            .updateDocument(updatedDoc);

                        if (context.mounted) {
                          Navigator.pop(context); // Close dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Document updated successfully'),
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
      },
    );
  }

  /// Show dialog to edit or remove expiry date
  static void _showEditExpiryDateDialog(
    BuildContext context,
    WidgetRef ref,
    DocumentModel document,
  ) {
    DateTime? selectedDate = document.expiryDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.orange),
                  SizedBox(width: 12),
                  Text('Edit Expiry Date'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set when this document expires (warranty, return policy, etc.)',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // Current expiry date display
                  if (selectedDate != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Expiry Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMMM d, y').format(selectedDate!),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_busy, color: Colors.grey.shade600),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No Expiry Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  'Click "Set Date" to add an expiry date',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ??
                                  DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          icon: const Icon(Icons.edit_calendar),
                          label: Text(
                              selectedDate == null ? 'Set Date' : 'Change'),
                        ),
                      ),
                      if (selectedDate != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              selectedDate = null;
                            });
                          },
                          icon: const Icon(Icons.clear, color: Colors.red),
                          label: const Text('Remove',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    print('📅 [ExpiryDate] Saving expiry date...');
                    print('   selectedDate: $selectedDate');
                    print('   clearExpiryDate: ${selectedDate == null}');

                    // Update document with new expiry date
                    final updatedDoc = document.copyWith(
                      expiryDate: selectedDate,
                      clearExpiryDate: selectedDate == null,
                      clearRemindersSent:
                          true, // Always reset reminders when changing/clearing date
                      clearLastReminderSent: true,
                      updatedAt: DateTime.now(),
                    );

                    print('   updatedDoc.expiryDate: ${updatedDoc.expiryDate}');

                    // Update the document
                    await ref
                        .read(documentsProvider.notifier)
                        .updateDocument(updatedDoc);

                    print('✅ [ExpiryDate] Document updated in provider');

                    if (context.mounted) {
                      Navigator.pop(context);

                      // Force provider to reload documents to ensure UI updates
                      await ref
                          .read(documentsProvider.notifier)
                          .loadDocuments();

                      print(
                          '✅ [ExpiryDate] Documents reloaded, UI should refresh now');

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.white),
                              const SizedBox(width: 12),
                              Text(selectedDate == null
                                  ? 'Expiry date removed ✅'
                                  : 'Expiry date updated ✅'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
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
}
