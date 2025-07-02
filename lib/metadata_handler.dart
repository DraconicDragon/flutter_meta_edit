import 'dart:io';

import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

class MetadataHandler {
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
}
