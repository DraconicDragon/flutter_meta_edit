import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'metadata_reader.dart';
import 'metadata_writer.dart';
import 'settings_manager.dart';
import 'settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsManager().loadSettings();
  runApp(const MetaEditApp());
}

class MetaEditApp extends StatelessWidget {
  const MetaEditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsManager(),
      builder: (context, child) {
        final settingsManager = SettingsManager();
        return MaterialApp(
          title: 'Meta Edit - Image Metadata Viewer & Editor',
          theme: settingsManager.getLightTheme(),
          darkTheme: settingsManager.getDarkTheme(),
          themeMode: settingsManager.themeMode,
          home: const MetaEditHomePage(),
        );
      },
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
  bool _isFileInfoExpanded = true;
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

      final metadata = await MetadataReader.readMetadata(file);

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
      final updatedMetadata = <String, String>{};
      for (var entry in _controllers.entries) {
        updatedMetadata[entry.key] = entry.value.text;
      }

      // Write metadata back to file
      final success = await MetadataWriter.writeMetadata(
        _selectedFile!,
        updatedMetadata,
      );

      if (success) {
        // Reload metadata to reflect changes
        await _loadImageMetadata(_selectedFile!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Metadata saved successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              'Failed to save metadata. Writing to this file format may not be supported yet.';
        });
      }
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
        .where(
          (entry) =>
              entry.key.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              entry.value.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  Widget _buildCompactReadOnlyField(String key, String value) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied "$key" to clipboard'),
            duration: const Duration(seconds: 2),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(
              _getIconForField(key),
              size: 14,
              color: _getColorForField(key),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: Text(
                key,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: _getColorForField(key),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                value,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.copy, size: 12, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String key,
    String value,
    TextEditingController controller,
  ) {
    final fileType = _selectedFile != null
        ? path.extension(_selectedFile!.path).substring(1)
        : '';
    final isEditable =
        MetadataReader.isFieldEditable(key) &&
        MetadataWriter.isFieldEditable(key, fileType);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForField(key),
                  size: 16,
                  color: _getColorForField(key),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    key,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _getColorForField(key),
                    ),
                  ),
                ),
                if (!isEditable)
                  Tooltip(
                    message: 'This field is read-only for $fileType files',
                    child: Icon(Icons.lock, size: 16, color: Colors.grey[500]),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                TextField(
                  controller: controller,
                  maxLines: value.length > 100 ? null : 1,
                  enabled: isEditable,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.fromLTRB(12, 12, 44, 12),
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: isEditable ? null : Colors.grey[600],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: controller.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied "$key" to clipboard'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      );
                    },
                    tooltip: 'Copy to clipboard',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForField(String key) {
    if (key.contains('File')) return Icons.folder;
    if (key.contains('Image') ||
        key.contains('Width') ||
        key.contains('Height') ||
        key.contains('Format')) {
      return Icons.image;
    }
    if (key.contains('Camera') || key.contains('Lens')) return Icons.camera_alt;
    if (key.contains('Exposure') ||
        key.contains('ISO') ||
        key.contains('Focal') ||
        key.contains('Flash')) {
      return Icons.settings;
    }
    if (key.contains('GPS') || key.contains('Location')) {
      return Icons.location_on;
    }
    if (key.contains('Date') || key.contains('Time')) return Icons.schedule;
    return Icons.info;
  }

  Color _getColorForField(String key) {
    if (key.contains('File')) return Colors.blue;
    if (key.contains('Image') ||
        key.contains('Width') ||
        key.contains('Height') ||
        key.contains('Format')) {
      return Colors.green;
    }
    if (key.contains('Camera') || key.contains('Lens')) return Colors.orange;
    if (key.contains('Exposure') ||
        key.contains('ISO') ||
        key.contains('Focal') ||
        key.contains('Flash')) {
      return Colors.purple;
    }
    if (key.contains('GPS') || key.contains('Location')) return Colors.red;
    if (key.contains('Date') || key.contains('Time')) return Colors.teal;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meta Edit - Image Metadata Viewer & Editor'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
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

                          if (MetadataReader.isSupportedFile(file.path)) {
                            await _loadImageMetadata(file);
                          } else {
                            setState(() {
                              _errorMessage =
                                  'Unsupported file type. Please select a JPG, PNG, or WebP image.';
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
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.3),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _selectedFile!,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                child: const Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.error_outline,
                                                      color: Colors.red,
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'Cannot preview image',
                                                    ),
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
                                    border: Border.all(
                                      color: Colors.green.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              path.basename(
                                                _selectedFile!.path,
                                              ),
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
                                      Row(
                                        children: [
                                          Text(
                                            'Click to select different image',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontSize: 12,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${_metadata.length} fields',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 64,
                                  color: _isDragOver
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _isDragOver
                                      ? 'Drop your image here'
                                      : 'Drag & drop an image\nor click to select',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: _isDragOver
                                        ? Colors.blue
                                        : Colors.grey[600],
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
                            Expanded(
                              child: Text(
                                'Metadata Fields',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                            if (_metadata.isNotEmpty && !_isLoading) ...[
                              Text(
                                '${_filteredMetadata.length} fields',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _saveMetadata,
                                icon: const Icon(Icons.save, size: 16),
                                label: const Text('Save'),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.error.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
                                    ),
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
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Readonly fields section
                                if (_filteredMetadata.any(
                                  (entry) => MetadataReader.getReadOnlyFields()
                                      .contains(entry.key),
                                )) ...[
                                  Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ExpansionTile(
                                      initiallyExpanded: _isFileInfoExpanded,
                                      onExpansionChanged: (expanded) {
                                        setState(() {
                                          _isFileInfoExpanded = expanded;
                                        });
                                      },
                                      leading: Icon(
                                        Icons.info_outline,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      title: Text(
                                        'File Information',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      subtitle: Text(
                                        '${_filteredMetadata.where((entry) => MetadataReader.getReadOnlyFields().contains(entry.key)).length} fields',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            0,
                                            16,
                                            16,
                                          ),
                                          child: Column(
                                            children: _filteredMetadata
                                                .where(
                                                  (entry) =>
                                                      MetadataReader.getReadOnlyFields()
                                                          .contains(entry.key),
                                                )
                                                .map(
                                                  (entry) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 4,
                                                        ),
                                                    child:
                                                        _buildCompactReadOnlyField(
                                                          entry.key,
                                                          entry.value,
                                                        ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],

                                // Editable fields section
                                if (_filteredMetadata.any(
                                  (entry) => !MetadataReader.getReadOnlyFields()
                                      .contains(entry.key),
                                )) ...[
                                  Text(
                                    'Metadata Fields',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: ListView(
                                      children: _filteredMetadata
                                          .where(
                                            (entry) =>
                                                !MetadataReader.getReadOnlyFields()
                                                    .contains(entry.key),
                                          )
                                          .map((entry) {
                                            final controller =
                                                _controllers[entry.key]!;
                                            return _buildEditableField(
                                              entry.key,
                                              entry.value,
                                              controller,
                                            );
                                          })
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ],
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
              border: Border(
                top: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_selectedFile != null) ...[
                    Icon(Icons.image, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        path.basename(_selectedFile!.path),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${_metadata.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        'Ready - Select an image to view metadata',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (_isLoading) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
