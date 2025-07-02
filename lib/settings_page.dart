import 'package:flutter/material.dart';

import 'settings_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsManager _settingsManager = SettingsManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.palette,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Appearance',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Theme Mode Selection
                  Text(
                    'Theme Mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.settings_brightness),
                      ),
                    ],
                    selected: {_settingsManager.themeMode},
                    onSelectionChanged: (Set<ThemeMode> selection) {
                      _settingsManager.setThemeMode(selection.first);
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 24),

                  // Accent Color Selection
                  Text(
                    'Accent Color',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 10,
                      itemBuilder: (context, index) {
                        final colors = [
                          Colors.blue,
                          Colors.red,
                          Colors.green,
                          Colors.orange,
                          Colors.purple,
                          Colors.teal,
                          Colors.pink,
                          Colors.indigo,
                          Colors.brown,
                          Colors.cyan,
                        ];
                        final color = colors[index];
                        final isSelected =
                            _settingsManager.accentColor.value == color.value;

                        return Padding(
                          padding: EdgeInsets.only(
                            right: index < colors.length - 1 ? 12 : 0,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              _settingsManager.setAccentColor(color);
                              setState(() {});
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 24,
                                    )
                                  : null,
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

          const SizedBox(height: 16),

          // PNG Settings Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.image,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'PNG Settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // PNG Optimization Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enable PNG Compression',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'When disabled, PNG files will be saved without compression for maximum quality.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _settingsManager.pngOptimizationEnabled,
                        onChanged: (value) {
                          _settingsManager.setPngOptimizationEnabled(value);
                          setState(() {});
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // PNG Compression Level Slider
                  AnimatedOpacity(
                    opacity: _settingsManager.pngOptimizationEnabled
                        ? 1.0
                        : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Compression Level',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${_settingsManager.pngCompressionLevel}',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Lower',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Expanded(
                              child: Slider(
                                min: 0,
                                max: 9,
                                divisions: 9,
                                value: _settingsManager.pngCompressionLevel
                                    .toDouble(),
                                onChanged:
                                    _settingsManager.pngOptimizationEnabled
                                    ? (value) {
                                        _settingsManager.setPngCompressionLevel(
                                          value.toInt(),
                                        );
                                        setState(() {});
                                      }
                                    : null,
                              ),
                            ),
                            Text(
                              'Higher',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Text(
                          'Higher compression reduces file size but may take longer to save.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // About Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'About',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Meta Edit v1.0.0',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A Flutter application for viewing and editing image metadata across multiple formats including JPEG, PNG, and WebP.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.code,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Built with Flutter',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Made with love for photographers and developers',
                        style: Theme.of(context).textTheme.bodySmall,
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
