import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';

class CaptureDocumentScreen extends ConsumerStatefulWidget {
  const CaptureDocumentScreen({super.key});

  @override
  ConsumerState<CaptureDocumentScreen> createState() =>
      _CaptureDocumentScreenState();
}

class _CaptureDocumentScreenState extends ConsumerState<CaptureDocumentScreen> {
  File? _imageFile;
  bool _isProcessing = false;

  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedFolderId;
  String? _selectedType;
  DateTime? _expiryDate;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          // Set default title
          _titleController.text =
              'Document ${DateTime.now().toLocal().toString().split(' ')[0]}';
          // Set default type
          _selectedType = DocumentType.uncategorized;
        });

        // Auto-select folder based on type
        _autoSelectFolder();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _autoSelectFolder() {
    // Find folder for selected type
    final folders = ref.read(foldersProvider);
    final folder = folders.cast<dynamic>().firstWhere(
          (f) => f.name.toLowerCase() == _selectedType?.toLowerCase(),
          orElse: () => null,
        );

    if (folder != null) {
      setState(() => _selectedFolderId = folder.id);
    }
  }

  Future<void> _saveDocument() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (_selectedFolderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a folder')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await ref.read(documentsProvider.notifier).createDocument(
            title: _titleController.text,
            documentType: _selectedType ?? DocumentType.uncategorized,
            folderId: _selectedFolderId!,
            localImagePath: _imageFile!.path,
            notes: _notesController.text,
            expiryDate: _expiryDate,
            ocrText: null,
            tags: null,
            classificationConfidence: null,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Document saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(foldersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Document'),
        actions: [
          if (_imageFile != null && !_isProcessing)
            TextButton(
              onPressed: _saveDocument,
              child: const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Preview
            if (_imageFile == null)
              _buildImagePicker(context)
            else
              _buildImagePreview(),

            if (_isProcessing) ...[
              const SizedBox(height: 24),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Saving document...'),
                  ],
                ),
              ),
            ],

            if (_imageFile != null && !_isProcessing) ...[
              const SizedBox(height: 24),

              // Title
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Enter document title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 16),

              // Document Type
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Document Type *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: DocumentType.allTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Text(
                          DocumentType.getIconForType(type),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(type),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value;
                  });
                  _autoSelectFolder();
                },
              ),
              const SizedBox(height: 16),

              // Folder Selection
              DropdownButtonFormField<String>(
                value: _selectedFolderId,
                decoration: const InputDecoration(
                  labelText: 'Folder *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder),
                ),
                items: folders.map((folder) {
                  return DropdownMenuItem(
                    value: folder.id,
                    child: Row(
                      children: [
                        Text(
                          folder.iconName ?? '📁',
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(folder.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedFolderId = value);
                },
              ),
              const SizedBox(height: 16),

              // Notes
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Add any additional notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Expiry Date
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _expiryDate == null
                      ? 'Set Expiry Date (Optional)'
                      : 'Expiry: ${_expiryDate!.toLocal().toString().split(' ')[0]}',
                ),
                trailing: _expiryDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _expiryDate = null);
                        },
                      )
                    : null,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) {
                    setState(() => _expiryDate = date);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Icon(
              Icons.image_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Capture or select a document image',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _imageFile!,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _imageFile = null;
                      _titleController.clear();
                      _notesController.clear();
                      _selectedFolderId = null;
                      _selectedType = null;
                      _expiryDate = null;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              'Image selected',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
