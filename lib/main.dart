import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'metadata_handler.dart';

void main() {
  runApp(const MetaEditApp());
}

class MetaEditApp extends StatelessWidget {
  const MetaEditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meta Edit - Image Metadata Viewer & Editor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MetaEditHomePage(),
    );
  }
}

class MetaEditHomePage extends StatefulWidget {
  const MetaEditHomePage({super.key});

  @override
  State<MetaEditHomePage> createState() => _MetaEditHomePageState();
}

class _MetaEditHomePageState extends State<MetaEditHomePage> {
  File? _selectedFile;
  Map<String, String> _metadata = {};
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDragOver = false;
  final Map<String, TextEditingController> _controllers = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await _loadImageMetadata(file);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadImageMetadata(File file) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _selectedFile = file;
        _metadata.clear();
        // Clear existing controllers
        for (var controller in _controllers.values) {
          controller.dispose();
        }
        _controllers.clear();
      });

      final metadata = await MetadataHandler.readMetadata(file);

      // Create controllers for each metadata field
      for (var entry in metadata.entries) {
        _controllers[entry.key] = TextEditingController(text: entry.value);
      }

      setState(() {
        _metadata = metadata;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error reading metadata: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMetadata() async {
    if (_selectedFile == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Update metadata map with controller values
      for (var entry in _controllers.entries) {
        _metadata[entry.key] = entry.value.text;
      }

      // Note: Actual metadata writing would require more complex implementation
      // For now, we'll just show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Metadata updated! (Note: Writing back to file not yet implemented)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving metadata: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<MapEntry<String, String>> get _filteredMetadata {
    if (_searchQuery.isEmpty) {
      return _metadata.entries.toList();
    }
    return _metadata.entries
        .where((entry) =>
            entry.key.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            entry.value.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meta Edit - Image Metadata Viewer & Editor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
          // Left side - Drop area / File picker
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: DropTarget(
                onDragEntered: (details) {
                  setState(() {
                    _isDragOver = true;
                  });
                },
                onDragExited: (details) {
                  setState(() {
                    _isDragOver = false;
                  });
                },
                onDragDone: (details) async {
                  setState(() {
                    _isDragOver = false;
                  });
                  
                  if (details.files.isNotEmpty) {
                    final file = File(details.files.first.path);
                    
                    if (MetadataHandler.isSupportedFile(file.path)) {
                      await _loadImageMetadata(file);
                    } else {
                      setState(() {
                        _errorMessage = 'Unsupported file type. Please select a JPG, PNG, or WebP image.';
                      });
                    }
                  }
                },
                child: GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isDragOver ? Colors.blue : Colors.grey,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: _isDragOver 
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.05),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_selectedFile != null) ...[
                          // Image preview
                          Expanded(
                            flex: 3,
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedFile!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error_outline, color: Colors.red),
                                          SizedBox(height: 8),
                                          Text('Cannot preview image'),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // File info
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        path.basename(_selectedFile!.path),
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Click to select a different image',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 64,
                            color: _isDragOver ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isDragOver 
                                ? 'Drop your image here'
                                : 'Drag & drop an image\nor click to select',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: _isDragOver ? Colors.blue : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Supports: JPG, PNG, WebP',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Right side - Metadata fields
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Metadata Fields',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      if (_metadata.isNotEmpty && !_isLoading) ...[
                        Text(
                          '${_filteredMetadata.length} fields',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _saveMetadata,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Changes'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Search bar
                  if (_metadata.isNotEmpty && !_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search metadata fields...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                  
                  if (_isLoading)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading metadata...'),
                        ],
                      ),
                    )
                  else if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_metadata.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No image selected',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Select an image to view and edit its metadata',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredMetadata.length,
                        itemBuilder: (context, index) {
                          final entry = _filteredMetadata[index];
                          final controller = _controllers[entry.key]!;
                          
                          // Categorize the metadata for better UI
                          final isFileInfo = ['File Name', 'File Size', 'File Path', 'Last Modified', 'File Type'].contains(entry.key);
                          final isImageInfo = ['Image Width', 'Image Height', 'Image Format', 'Megapixels', 'Bit Depth', 'Color Type'].contains(entry.key);
                          final isCameraInfo = ['Camera Make', 'Camera Model', 'Lens Model'].contains(entry.key);
                          final isPhotoSettings = ['Exposure Time', 'F-Number', 'ISO Speed', 'Focal Length', 'Flash', 'White Balance'].contains(entry.key);
                          
                          Color? categoryColor;
                          IconData? categoryIcon;
                          
                          if (isFileInfo) {
                            categoryColor = Colors.blue;
                            categoryIcon = Icons.folder;
                          } else if (isImageInfo) {
                            categoryColor = Colors.green;
                            categoryIcon = Icons.image;
                          } else if (isCameraInfo) {
                            categoryColor = Colors.orange;
                            categoryIcon = Icons.camera_alt;
                          } else if (isPhotoSettings) {
                            categoryColor = Colors.purple;
                            categoryIcon = Icons.settings;
                          }
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (categoryIcon != null) ...[
                                        Icon(
                                          categoryIcon,
                                          size: 16,
                                          color: categoryColor,
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: categoryColor,
                                          ),
                                        ),
                                      ),
                                      if (entry.value.length > 50)
                                        Icon(
                                          Icons.text_fields,
                                          size: 16,
                                          color: Colors.grey[500],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: controller,
                                    maxLines: entry.value.length > 100 ? null : 1,
                                    decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      suffixIcon: entry.value.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.copy, size: 16),
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(text: entry.value));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Copied "${entry.key}" to clipboard'),
                                                    duration: const Duration(seconds: 2),
                                                  ),
                                                );
                                              },
                                              tooltip: 'Copy to clipboard',
                                            )
                                          : null,
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
              ],
            ),
          ),
          // Status bar
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.3))),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_selectedFile != null) ...[
                    Icon(Icons.image, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      path.basename(_selectedFile!.path),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${_metadata.length} metadata fields',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ] else
                    Text(
                      'Ready - Select an image to view metadata',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  const Spacer(),
                  if (_isLoading)
                    Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Loading...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
