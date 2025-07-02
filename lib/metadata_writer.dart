import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

import 'settings_manager.dart';

class MetadataWriter {
  static Future<bool> writeMetadata(
    File file,
    Map<String, String> metadata, {
    bool preserveImage = true,
  }) async {
    // Get settings before passing to isolate
    final settingsManager = SettingsManager();

    // Run in compute isolate to prevent UI blocking
    return await compute(_writeMetadataIsolate, {
      'filePath': file.path,
      'metadata': metadata,
      'preserveImage': preserveImage,
      'pngOptimizationEnabled': settingsManager.pngOptimizationEnabled,
      'pngCompressionLevel': settingsManager.pngCompressionLevel,
    });
  }

  // Isolate function for file writing
  static Future<bool> _writeMetadataIsolate(Map<String, dynamic> params) async {
    final String filePath = params['filePath'];
    final Map<String, String> metadata = Map<String, String>.from(
      params['metadata'],
    );
    final bool preserveImage = params['preserveImage'];
    // Pass compression settings as parameters to avoid accessing SettingsManager in isolate
    final bool pngOptimizationEnabled =
        params['pngOptimizationEnabled'] ?? false;
    final int pngCompressionLevel = params['pngCompressionLevel'] ?? 0;

    final file = File(filePath);
    final extension = path.extension(file.path).toLowerCase();

    try {
      if (extension == '.png') {
        return await _writePngMetadata(
          file,
          metadata,
          preserveImage: preserveImage,
          pngOptimizationEnabled: pngOptimizationEnabled,
          pngCompressionLevel: pngCompressionLevel,
        );
      }
      // TODO: Add support for JPEG and WebP writing
      return false;
    } catch (e) {
      print('Error writing metadata: $e');
      return false;
    }
  }

  static Future<bool> _writePngMetadata(
    File file,
    Map<String, String> metadata, {
    bool preserveImage = true,
    bool pngOptimizationEnabled = false,
    int pngCompressionLevel = 0,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        return false;
      }

      // Create a new image with updated text data
      // If preserveImage is true, we don't modify any image data
      final newImage = preserveImage
          ? img.Image.from(
              image,
            ) // This creates a copy preserving all image data
          : img.Image.from(image); // Same approach, ensuring no degradation

      // Initialize text data if null
      newImage.textData ??= <String, String>{};

      // Clear existing text data if we're replacing everything
      newImage.textData!.clear();

      // Add PNG text chunks from metadata
      for (var entry in metadata.entries) {
        if (entry.key.startsWith('PNG Text: ')) {
          final textKey = entry.key.substring('PNG Text: '.length);
          if (entry.value.isNotEmpty) {
            newImage.textData![textKey] = entry.value;
          }
        }
      }

      // Process special text chunk: parameters (common in AI-generated images)
      if (metadata.containsKey('parameters') &&
          metadata['parameters']!.isNotEmpty) {
        newImage.textData!['parameters'] = metadata['parameters']!;
      }

      // Add common metadata as PNG text chunks
      final commonMappings = {
        'Artist': 'Artist',
        'Copyright': 'Copyright',
        'Description': 'Description',
        'Software': 'Software',
        'Date Taken': 'Creation Time',
        'Camera Make': 'Camera Make',
        'Camera Model': 'Camera Model',
        'Comment': 'Comment',
        'Title': 'Title',
        'Author': 'Author',
      };

      for (var entry in metadata.entries) {
        if (commonMappings.containsKey(entry.key) && entry.value.isNotEmpty) {
          newImage.textData![commonMappings[entry.key]!] = entry.value;
        }
      }

      // Get PNG optimization settings from parameters (passed from main thread)
      final useOptimization = pngOptimizationEnabled;
      final compressionLevel = pngCompressionLevel;

      // Encode the image back to PNG
      // Use settings from SettingsManager for compression level
      final newBytes = img.encodePng(
        newImage,
        level: useOptimization
            ? compressionLevel
            : 0, // 0 = no compression, 9 = max compression
      );

      // Only create a backup if we're not creating a copy elsewhere
      if (!preserveImage) {
        // Create backup file
        final backupFile = File('${file.path}.backup');
        await file.copy(backupFile.path);
      }

      // Write the new file
      await file.writeAsBytes(newBytes);

      return true;
    } catch (e) {
      print('Error writing PNG metadata: $e');
      return false;
    }
  }

  static Future<Uint8List?> writeMetadataToBytes(
    Uint8List originalBytes,
    String fileName,
    Map<String, String> metadata, {
    bool preserveImage = true,
  }) async {
    // Get settings before passing to isolate
    final settingsManager = SettingsManager();

    // Run in compute isolate to prevent UI blocking
    return await compute(_writeMetadataToBytesIsolate, {
      'originalBytes': originalBytes,
      'fileName': fileName,
      'metadata': metadata,
      'preserveImage': preserveImage,
      'pngOptimizationEnabled': settingsManager.pngOptimizationEnabled,
      'pngCompressionLevel': settingsManager.pngCompressionLevel,
    });
  }

  // Isolate function for bytes writing
  static Future<Uint8List?> _writeMetadataToBytesIsolate(
    Map<String, dynamic> params,
  ) async {
    final Uint8List originalBytes = params['originalBytes'];
    final String fileName = params['fileName'];
    final Map<String, String> metadata = Map<String, String>.from(
      params['metadata'],
    );
    final bool preserveImage = params['preserveImage'];
    final bool pngOptimizationEnabled =
        params['pngOptimizationEnabled'] ?? false;
    final int pngCompressionLevel = params['pngCompressionLevel'] ?? 0;
    try {
      final extension = fileName.split('.').last.toLowerCase();

      switch (extension) {
        case 'png':
          return await _writePngMetadataToBytes(
            originalBytes,
            metadata,
            preserveImage: preserveImage,
            pngOptimizationEnabled: pngOptimizationEnabled,
            pngCompressionLevel: pngCompressionLevel,
          );
        case 'jpg':
        case 'jpeg':
          // For now, return original bytes for JPEG (can be implemented later)
          return originalBytes;
        case 'webp':
          // For now, return original bytes for WebP (can be implemented later)
          return originalBytes;
        default:
          return null;
      }
    } catch (e) {
      print('Error writing metadata to bytes: $e');
      return null;
    }
  }

  static Future<Uint8List?> _writePngMetadataToBytes(
    Uint8List originalBytes,
    Map<String, String> metadata, {
    bool preserveImage = true,
    bool pngOptimizationEnabled = false,
    int pngCompressionLevel = 0,
  }) async {
    try {
      // Decode the original image
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) return null;

      // Create new image with same data
      final newImage = img.Image.from(originalImage);

      // Initialize textData if it doesn't exist
      newImage.textData ??= <String, String>{};

      // Clear existing text chunks
      newImage.textData!.clear();

      // Add new metadata as text chunks
      for (var entry in metadata.entries) {
        String key = entry.key;
        String value = entry.value;

        // Skip read-only fields
        if (_isReadOnlyField(key)) {
          continue;
        }

        // Handle PNG text chunks
        if (key.startsWith('PNG Text: ')) {
          key = key.substring(10); // Remove "PNG Text: " prefix
        }

        // Map common metadata fields to PNG text chunk keywords
        switch (key) {
          case 'Artist':
            newImage.textData!['Author'] = value;
            break;
          case 'Copyright':
            newImage.textData!['Copyright'] = value;
            break;
          case 'Description':
            newImage.textData!['Description'] = value;
            break;
          case 'Software':
            newImage.textData!['Software'] = value;
            break;
          case 'parameters':
            newImage.textData!['parameters'] = value;
            break;
          default:
            // For other PNG text fields, use the key directly
            newImage.textData![key] = value;
            break;
        }
      }

      // Get PNG compression settings from parameters
      final compressionLevel = pngOptimizationEnabled ? pngCompressionLevel : 0;

      // Encode the image back to PNG bytes
      final encodedBytes = img.encodePng(newImage, level: compressionLevel);

      return Uint8List.fromList(encodedBytes);
    } catch (e) {
      print('Error writing PNG metadata to bytes: $e');
      return null;
    }
  }

  static List<String> getEditableFields(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'png':
        return [
          // Common fields
          'Artist',
          'Copyright',
          'Description',
          'Software',
          'parameters',

          // All PNG text fields are editable
          'PNG Text: Title',
          'PNG Text: Author',
          'PNG Text: Description',
          'PNG Text: Comment',
          'PNG Text: Source',
          'PNG Text: Software',
          'PNG Text: Disclaimer',
          'PNG Text: Warning',
          'PNG Text: Creation Time',
          'PNG Text: parameters',

          // Catch-all for any PNG text field
          // This ensures all PNG text fields are considered editable
          'PNG Text:',
        ];
      case 'jpg':
      case 'jpeg':
        return [
          'Artist',
          'Copyright',
          'Description',
          'Software',
          'Camera Make',
          'Camera Model',
        ];
      case 'webp':
        return ['Artist', 'Copyright', 'Description'];
      default:
        return [];
    }
  }

  static bool _isReadOnlyField(String key) {
    const readOnlyFields = {
      'File Name',
      'File Size',
      'File Path',
      'Last Modified',
      'File Type',
      'Image Width',
      'Image Height',
      'Image Format',
      'Megapixels',
      'Bit Depth',
      'Color Type',
      'EXIF Image Width',
      'EXIF Image Height',
      'Color Space',
    };
    return readOnlyFields.contains(key);
  }

  static bool isFieldEditable(String fieldName, String fileType) {
    // If it's a PNG text field, it's always editable
    if (fieldName.startsWith('PNG Text:') && fileType.toLowerCase() == 'png') {
      return true;
    }

    // For the 'parameters' field in PNG files (common in AI-generated images)
    if (fieldName == 'parameters' && fileType.toLowerCase() == 'png') {
      return true;
    }

    // Check the standard list
    return getEditableFields(fileType).contains(fieldName);
  }
}
