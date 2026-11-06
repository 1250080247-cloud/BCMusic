import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final MusicController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double? _volume;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final settings = widget.controller.snapshot.preferences;
      final volume = _volume ?? settings.volume.toDouble();
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cài đặt',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng cài đặt',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              'Các tuỳ chọn được lưu trên thiết bị này.',
              style: TextStyle(color: context.palette.muted),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Âm thanh',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text('Âm lượng ứng dụng · ${volume.round()}%'),
                    Slider(
                      value: volume,
                      max: 100,
                      divisions: 100,
                      semanticFormatterCallback: (value) => '${value.round()}%',
                      onChanged: (value) => setState(() => _volume = value),
                      onChangeEnd: (value) async {
                        await widget.controller.updatePreferences({
                          'volume': value.round(),
                        });
                        if (mounted) setState(() => _volume = null);
                      },
                    ),
                    const Text('Tốc độ phát'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final speed in AppPreferences.speeds)
                          ChoiceChip(
                            label: Text(playbackSpeedLabel(speed)),
                            selected: settings.speed == speed,
                            onSelected: (_) => widget.controller
                                .updatePreferences({'speed': speed}),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      settings.light
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    title: const Text('Giao diện sáng'),
                    value: settings.light,
                    onChanged: (value) =>
                        widget.controller.updatePreferences({'light': value}),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.album_outlined),
                    title: const Text('Chuyển động mâm đĩa'),
                    value: settings.motion,
                    onChanged: (value) =>
                        widget.controller.updatePreferences({'motion': value}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Center(child: Text('BCMusic · Phiên bản 1.2.5')),
            if (widget.controller.error case final error?)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    },
  );
}
