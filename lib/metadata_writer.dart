import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

class MetadataWriter {
  static Future<bool> writeMetadata(File file, Map<String, String> metadata) async {
    final extension = path.extension(file.path).toLowerCase();
    
    try {
      if (extension == '.png') {
        return await _writePngMetadata(file, metadata);
      }
      // TODO: Add support for JPEG and WebP writing
      return false;
    } catch (e) {
      print('Error writing metadata: $e');
      return false;
    }
  }

  static Future<bool> _writePngMetadata(File file, Map<String, String> metadata) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return false;
      }

      // Create a new image with updated text data
      final newImage = img.Image.from(image);
      
      // Clear existing text data
      newImage.textData?.clear();
      newImage.textData ??= <String, String>{};

      // Add PNG text chunks from metadata
      for (var entry in metadata.entries) {
        if (entry.key.startsWith('PNG Text: ')) {
          final textKey = entry.key.substring('PNG Text: '.length);
          if (entry.value.isNotEmpty) {
            newImage.textData![textKey] = entry.value;
          }
        }
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
      };

      for (var entry in metadata.entries) {
        if (commonMappings.containsKey(entry.key) && entry.value.isNotEmpty) {
          newImage.textData![commonMappings[entry.key]!] = entry.value;
        }
      }

      // Encode the image back to PNG
      final newBytes = img.encodePng(newImage);
      
      // Create backup file
      final backupFile = File('${file.path}.backup');
      await file.copy(backupFile.path);
      
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
          'Artist',
          'Copyright',
          'Description', 
          'Software',
          'PNG Text: Title',
          'PNG Text: Author',
          'PNG Text: Description',
          'PNG Text: Comment',
          'PNG Text: Source',
          'PNG Text: Software',
          'PNG Text: Disclaimer',
          'PNG Text: Warning',
          'PNG Text: Creation Time',
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
        return [
          'Artist',
          'Copyright', 
          'Description',
        ];
      default:
        return [];
    }
  }

  static bool isFieldEditable(String fieldName, String fileType) {
    return getEditableFields(fileType).contains(fieldName);
  }
}
