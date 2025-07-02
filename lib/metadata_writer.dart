import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

import 'settings_manager.dart';

class MetadataWriter {
  static Future<bool> writeMetadata(
    File file,
    Map<String, String> metadata, {
    bool preserveImage = true,
  }) async {
    final extension = path.extension(file.path).toLowerCase();

    try {
      if (extension == '.png') {
        return await _writePngMetadata(
          file,
          metadata,
          preserveImage: preserveImage,
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

      // Get PNG optimization settings from SettingsManager
      final settingsManager = SettingsManager();
      final useOptimization = settingsManager.pngOptimizationEnabled;
      final compressionLevel = settingsManager.pngCompressionLevel;

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
