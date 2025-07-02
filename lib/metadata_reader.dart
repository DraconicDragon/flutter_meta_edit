import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

class MetadataReader {
  static Future<Map<String, String>> readMetadataFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final metadata = <String, String>{};
      final extension = fileName.split('.').last.toLowerCase();

      // Add comprehensive file info (same as desktop version)
      metadata['File Name'] = fileName;
      metadata['File Size'] = '${(bytes.length / 1024).toStringAsFixed(1)} KB';
      metadata['File Type'] = extension.toUpperCase();

      // Get current date as "Last Modified" since we can't get actual file date on web
      final now = DateTime.now();
      metadata['Last Modified'] =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      // Decode image to get detailed info
      final image = img.decodeImage(bytes);
      if (image != null) {
        metadata['Image Width'] = '${image.width}';
        metadata['Image Height'] = '${image.height}';
        metadata['Image Format'] = extension.toUpperCase();
        metadata['Megapixels'] =
            '${((image.width * image.height) / 1000000).toStringAsFixed(1)} MP';

        // Add bit depth and color info if available
        if (image.palette != null) {
          metadata['Color Type'] = 'Palette';
          metadata['Bit Depth'] = '8';
        } else if (image.numChannels == 1) {
          metadata['Color Type'] = 'Grayscale';
          metadata['Bit Depth'] = '8';
        } else if (image.numChannels == 3) {
          metadata['Color Type'] = 'RGB';
          metadata['Bit Depth'] = '24';
        } else if (image.numChannels == 4) {
          metadata['Color Type'] = 'RGBA';
          metadata['Bit Depth'] = '32';
        }
      }

      // Extract format-specific metadata
      if (extension == 'jpg' || extension == 'jpeg') {
        await _extractJpegMetadataFromBytes(bytes, metadata);
      } else if (extension == 'png') {
        await _extractPngMetadataFromBytes(bytes, metadata, image);
      } else if (extension == 'webp') {
        await _extractWebpMetadataFromBytes(bytes, metadata);
      }

      return metadata;
    } catch (e) {
      return {'Error': 'Failed to read metadata: $e'};
    }
  }

  static Future<void> _extractJpegMetadataFromBytes(
    Uint8List bytes,
    Map<String, String> metadata,
  ) async {
    try {
      final exifData = await readExifFromBytes(bytes);

      if (exifData.isNotEmpty) {
        for (var entry in exifData.entries) {
          final key = entry.key;
          final value = entry.value;

          String readableKey = _getReadableExifTag(key);
          String readableValue = value.toString();

          metadata[readableKey] = readableValue;
        }
      }
    } catch (e) {
      metadata['EXIF Error'] = 'Could not read EXIF data: $e';
    }
  }

  static Future<void> _extractPngMetadataFromBytes(
    Uint8List bytes,
    Map<String, String> metadata,
    img.Image? image,
  ) async {
    try {
      if (image?.textData != null && image!.textData!.isNotEmpty) {
        for (var entry in image.textData!.entries) {
          metadata['PNG Text: ${entry.key}'] = entry.value;
        }
      }

      try {
        final exifData = await readExifFromBytes(bytes);
        if (exifData.isNotEmpty) {
          for (var entry in exifData.entries) {
            final key = entry.key;
            final value = entry.value;

            String readableKey = _getReadableExifTag(key);
            String readableValue = value.toString();

            metadata[readableKey] = readableValue;
          }
        }
      } catch (e) {
        // PNG might not have EXIF data, that's okay
      }
    } catch (e) {
      metadata['PNG Error'] = 'Could not read PNG text chunks: $e';
    }
  }

  static Future<void> _extractWebpMetadataFromBytes(
    Uint8List bytes,
    Map<String, String> metadata,
  ) async {
    try {
      final exifData = await readExifFromBytes(bytes);
      if (exifData.isNotEmpty) {
        for (var entry in exifData.entries) {
          final key = entry.key;
          final value = entry.value;

          String readableKey = _getReadableExifTag(key);
          String readableValue = value.toString();

          metadata[readableKey] = readableValue;
        }
      }
    } catch (e) {
      // WebP might not have EXIF data, that's okay
    }
  }

  // Helper method to convert EXIF tags to readable names
  static String _getReadableExifTag(String tag) {
    const Map<String, String> tagNames = {
      'Image Make': 'Camera Make',
      'Image Model': 'Camera Model',
      'Image Software': 'Software',
      'Image DateTime': 'Date Taken',
      'Image Artist': 'Artist',
      'Image Copyright': 'Copyright',
      'Image Description': 'Description',
      'EXIF ExposureTime': 'Exposure Time',
      'EXIF FNumber': 'F-Number',
      'EXIF ISO': 'ISO Speed',
      'EXIF ISOSpeedRatings': 'ISO Speed',
      'EXIF DateTimeOriginal': 'Date Original',
      'EXIF DateTimeDigitized': 'Date Digitized',
      'EXIF ExposureBiasValue': 'Exposure Bias',
      'EXIF MaxApertureValue': 'Max Aperture',
      'EXIF SubjectDistance': 'Subject Distance',
      'EXIF MeteringMode': 'Metering Mode',
      'EXIF LightSource': 'Light Source',
      'EXIF Flash': 'Flash',
      'EXIF FocalLength': 'Focal Length',
      'EXIF ColorSpace': 'Color Space',
      'EXIF ExifImageWidth': 'EXIF Image Width',
      'EXIF ExifImageLength': 'EXIF Image Height',
      'EXIF WhiteBalance': 'White Balance',
      'EXIF DigitalZoomRatio': 'Digital Zoom',
      'EXIF FocalLengthIn35mmFilm': 'Focal Length (35mm)',
      'EXIF SceneCaptureType': 'Scene Type',
      'EXIF GainControl': 'Gain Control',
      'EXIF Contrast': 'Contrast',
      'EXIF Saturation': 'Saturation',
      'EXIF Sharpness': 'Sharpness',
      'GPS GPSLatitude': 'GPS Latitude',
      'GPS GPSLongitude': 'GPS Longitude',
      'GPS GPSAltitude': 'GPS Altitude',
      'GPS GPSTimeStamp': 'GPS Time',
      'GPS GPSDateStamp': 'GPS Date',
    };

    return tagNames[tag] ?? tag;
  }

  static Future<Map<String, String>> readMetadata(File file) async {
    final extension = path.extension(file.path).toLowerCase();
    Map<String, String> metadata = {};

    // Add basic file information first
    final stat = await file.stat();
    metadata['File Name'] = path.basename(file.path);
    metadata['File Size'] = '${(stat.size / 1024).toStringAsFixed(2)} KB';
    metadata['File Path'] = file.path;
    metadata['Last Modified'] = stat.modified.toString();
    metadata['File Type'] = extension.toUpperCase().substring(1);

    try {
      if (extension == '.jpg' || extension == '.jpeg') {
        final jpegMeta = await _readJpegMetadata(file);
        metadata.addAll(jpegMeta);
      } else if (extension == '.png') {
        final pngMeta = await _readPngMetadata(file);
        metadata.addAll(pngMeta);
      } else if (extension == '.webp') {
        final webpMeta = await _readWebpMetadata(file);
        metadata.addAll(webpMeta);
      }
    } catch (e) {
      metadata['Error'] = 'Failed to read metadata: $e';
    }

    return metadata;
  }

  static Future<Map<String, String>> _readJpegMetadata(File file) async {
    Map<String, String> metadata = {};

    try {
      final bytes = await file.readAsBytes();
      final exifData = await readExifFromBytes(bytes);

      if (exifData.isNotEmpty) {
        // Common EXIF tags with user-friendly names
        final friendlyNames = {
          'EXIF Make': 'Camera Make',
          'EXIF Model': 'Camera Model',
          'EXIF DateTime': 'Date Taken',
          'EXIF DateTimeOriginal': 'Original Date',
          'EXIF DateTimeDigitized': 'Digitized Date',
          'EXIF ExposureTime': 'Exposure Time',
          'EXIF FNumber': 'F-Number',
          'EXIF ISOSpeedRatings': 'ISO Speed',
          'EXIF FocalLength': 'Focal Length',
          'EXIF Flash': 'Flash',
          'EXIF WhiteBalance': 'White Balance',
          'EXIF ExposureProgram': 'Exposure Program',
          'EXIF MeteringMode': 'Metering Mode',
          'EXIF LensModel': 'Lens Model',
          'EXIF ColorSpace': 'Color Space',
          'EXIF ExifImageWidth': 'Image Width',
          'EXIF ExifImageLength': 'Image Height',
          'EXIF Orientation': 'Orientation',
          'EXIF XResolution': 'X Resolution',
          'EXIF YResolution': 'Y Resolution',
          'EXIF ResolutionUnit': 'Resolution Unit',
          'EXIF Software': 'Software',
          'EXIF Artist': 'Artist',
          'EXIF Copyright': 'Copyright',
          'EXIF ImageDescription': 'Description',
          'GPS GPSLatitude': 'GPS Latitude',
          'GPS GPSLongitude': 'GPS Longitude',
          'GPS GPSAltitude': 'GPS Altitude',
        };

        for (var entry in exifData.entries) {
          final key = entry.key;
          final friendlyKey = friendlyNames[key] ?? key;
          final value = entry.value.toString();
          metadata[friendlyKey] = value;
        }
      }

      // Try to get image dimensions from the image data
      final image = img.decodeImage(bytes);
      if (image != null) {
        metadata['Image Width'] = image.width.toString();
        metadata['Image Height'] = image.height.toString();
        metadata['Image Format'] = 'JPEG';

        // Calculate megapixels
        final megapixels = (image.width * image.height / 1000000)
            .toStringAsFixed(1);
        metadata['Megapixels'] = '$megapixels MP';
      }
    } catch (e) {
      metadata['JPEG Error'] = 'Failed to read JPEG metadata: $e';
    }

    return metadata;
  }

  static Future<Map<String, String>> _readPngMetadata(File file) async {
    Map<String, String> metadata = {};

    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image != null) {
        metadata['Image Width'] = image.width.toString();
        metadata['Image Height'] = image.height.toString();
        metadata['Image Format'] = 'PNG';

        // Calculate megapixels
        final megapixels = (image.width * image.height / 1000000)
            .toStringAsFixed(1);
        metadata['Megapixels'] = '$megapixels MP';

        // PNG text chunks
        if (image.textData != null) {
          for (var entry in image.textData!.entries) {
            metadata['PNG Text: ${entry.key}'] = entry.value;
          }
        }

        // PNG specific metadata
        metadata['Bit Depth'] = '${image.numChannels * 8} bits';
        metadata['Color Type'] = _getPngColorType(image.numChannels);
      }

      // Try to read EXIF from PNG if present
      try {
        final exifData = await readExifFromBytes(bytes);
        if (exifData.isNotEmpty) {
          for (var entry in exifData.entries) {
            metadata['EXIF: ${entry.key}'] = entry.value.toString();
          }
        }
      } catch (e) {
        // EXIF might not be present in PNG
      }
    } catch (e) {
      metadata['PNG Error'] = 'Failed to read PNG metadata: $e';
    }

    return metadata;
  }

  static Future<Map<String, String>> _readWebpMetadata(File file) async {
    Map<String, String> metadata = {};

    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image != null) {
        metadata['Image Width'] = image.width.toString();
        metadata['Image Height'] = image.height.toString();
        metadata['Image Format'] = 'WebP';

        // Calculate megapixels
        final megapixels = (image.width * image.height / 1000000)
            .toStringAsFixed(1);
        metadata['Megapixels'] = '$megapixels MP';
      }

      // Try to read EXIF from WebP if present
      try {
        final exifData = await readExifFromBytes(bytes);
        if (exifData.isNotEmpty) {
          for (var entry in exifData.entries) {
            metadata['EXIF: ${entry.key}'] = entry.value.toString();
          }
        }
      } catch (e) {
        // EXIF might not be present in WebP
      }
    } catch (e) {
      metadata['WebP Error'] = 'Failed to read WebP metadata: $e';
    }

    return metadata;
  }

  static String _getPngColorType(int numChannels) {
    switch (numChannels) {
      case 1:
        return 'Grayscale';
      case 2:
        return 'Grayscale + Alpha';
      case 3:
        return 'RGB';
      case 4:
        return 'RGB + Alpha';
      default:
        return 'Unknown';
    }
  }

  static List<String> getSupportedExtensions() {
    return ['.jpg', '.jpeg', '.png', '.webp'];
  }

  static bool isSupportedFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return getSupportedExtensions().contains(extension);
  }

  /// Returns list of readonly metadata fields that should be displayed compactly
  static Set<String> getReadOnlyFields() {
    return {
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
      // Add more technical fields that shouldn't be edited
      'EXIF Image Width',
      'EXIF Image Height',
      'Color Space',
    };
  }

  /// Returns true if a field is editable (PNG text chunks, EXIF fields, etc.)
  static bool isFieldEditable(String fieldName) {
    // Read-only fields
    if (getReadOnlyFields().contains(fieldName)) {
      return false;
    }

    // PNG text chunks are always editable
    if (fieldName.startsWith('PNG Text:')) {
      return true;
    }

    // Common editable EXIF fields
    const editableExifFields = {
      'Artist',
      'Copyright',
      'Description',
      'Software',
      'Camera Make',
      'Camera Model',
      'Date Taken',
      'Date Original',
      'parameters',
      'UserComment',
      'ImageDescription',
    };

    return editableExifFields.contains(fieldName);
  }
}
