# Meta Edit - Image Metadata Viewer & Editor

A Flutter application for viewing and editing image metadata across multiple formats including JPEG, PNG, and WebP.

## Features

### 🖼️ Image Support

- **JPEG/JPG**: Full EXIF metadata support including camera settings, GPS data, and technical information
- **PNG**: Text chunks, image properties, and embedded EXIF data
- **WebP**: Basic image information and embedded EXIF data when available

### 🎯 User Interface

- **Drag & Drop**: Simply drag image files into the application
- **File Picker**: Click the drop area to browse and select images
- **Image Preview**: Visual preview of selected images
- **Search Functionality**: Filter metadata fields by name or value
- **Categorized Fields**: Color-coded metadata categories for easy navigation
- **Copy to Clipboard**: One-click copying of metadata values

### 📋 Metadata Categories

- **File Information**: File size, path, type, modification date
- **Image Properties**: Dimensions, format, megapixels, color information
- **Camera Data**: Make, model, lens information
- **Photo Settings**: Exposure, ISO, focal length, flash settings
- **Location Data**: GPS coordinates and altitude (when available)

## Installation

### Prerequisites

- Flutter SDK (3.9.0 or higher)
- Platform-specific development tools:
  - Linux: CMake, Ninja-build
  - Windows: Visual Studio
  - macOS: Xcode

### Setup

1. Clone or download the project
2. Navigate to the project directory
3. Install dependencies:

   ```bash
   flutter pub get
   ```

4. Run the application:

   ```bash
   flutter run -d <platform>
   ```

   Where `<platform>` can be `linux`, `windows`, `macos`, etc.

## Usage

### Loading Images

1. **Drag & Drop**: Drag an image file from your file manager into the left panel
2. **File Selection**: Click the left panel to open a file picker dialog
3. **Supported Formats**: JPG, JPEG, PNG, WebP

### Viewing Metadata

- Once an image is loaded, metadata fields appear in the right panel
- Fields are color-coded by category:
  - 🔵 Blue: File information
  - 🟢 Green: Image properties  
  - 🟠 Orange: Camera information
  - 🟣 Purple: Photo settings
- Use the search bar to filter specific metadata fields

### Editing Metadata

- Click on any text field to edit its value
- Changes are tracked automatically
- Click "Save Changes" to apply modifications (writing back to files is planned for future versions)

### Copying Data

- Use the copy button (📋) next to each field to copy values to clipboard
- Useful for transferring metadata between applications

## Technical Details

### Dependencies

- `file_picker`: Cross-platform file selection
- `desktop_drop`: Drag and drop functionality
- `exif`: EXIF metadata reading
- `image`: Image processing and format support
- `path`: Cross-platform path manipulation

### Architecture

- `main.dart`: Main UI and application logic
- `metadata_handler.dart`: Metadata extraction and processing
- Modular design for easy extension to new formats

## Future Enhancements

- [ ] Metadata writing back to files
- [ ] Support for additional formats (TIFF, RAW files)
- [ ] Batch processing capabilities
- [ ] Metadata comparison between images
- [ ] Export metadata to various formats (JSON, CSV, XML)
- [ ] Geolocation mapping for GPS data
- [ ] Thumbnail generation and grid view
- [ ] Metadata templates and presets

## License

This project is open source. See the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.
