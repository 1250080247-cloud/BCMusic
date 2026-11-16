import 'package:flutter/material.dart';

import 'app_config.dart';
import 'app_controller.dart';
import 'app_theme.dart';
import 'backup_screen.dart';
import 'downloads_screen.dart';
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
      final prefs = widget.controller.snapshot.preferences;
      final volume = _volume ?? prefs.volume.toDouble();
      final palette = context.palette;
      final separator = BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      );

      const qualityOptions = [
        ('economy', 'Tiết kiệm', '~64 kbps'),
        ('standard', 'Tiêu chuẩn', '~128 kbps'),
        ('high', 'Chất lượng cao', '~160 kbps'),
      ];

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MAKE IT YOURS',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w600,
                            color: palette.pink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Cài đặt trải nghiệm',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Mọi giai điệu, theo cách của bạn.',
                style: TextStyle(color: context.palette.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 20),

              // 1. Âm lượng (.setting-block)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: separator,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Âm lượng',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: palette.selection,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.border),
                          ),
                          child: Text(
                            '${volume.round()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.volume_up_rounded,
                          size: 20,
                          color: palette.muted,
                        ),
                        Expanded(
                          child: Slider(
                            value: volume,
                            max: 100,
                            activeColor: palette.action,
                            inactiveColor: palette.border,
                            onChanged: (v) => setState(() => _volume = v),
                            onChangeEnd: (v) async {
                              await widget.controller.updatePreferences({
                                'volume': v.round(),
                              });
                              if (mounted) setState(() => _volume = null);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Tốc độ phát (.setting-chips)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: separator,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tốc độ phát',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final speed in AppPreferences.speeds)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: ChoiceChip(
                                showCheckmark: false,
                                label: Text(playbackSpeedLabel(speed)),
                                backgroundColor: palette.raised,
                                selectedColor: palette.selection,
                                labelStyle: TextStyle(color: palette.text),
                                selected: prefs.speed == speed,
                                onSelected: (_) => widget.controller
                                    .updatePreferences({'speed': speed}),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Chuyển bài mượt mà 5s (Crossfade)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: separator,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chuyển bài mượt mà 5s',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            prefs.crossfade
                                ? 'Giảm âm cuối bài, tăng âm đầu bài'
                                : 'Làm dịu khoảng chuyển giữa hai bài',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: prefs.crossfade,
                      activeThumbColor: palette.onAction,
                      activeTrackColor: palette.action,
                      onChanged: (value) => widget.controller.updatePreferences(
                        {'crossfade': value},
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Chất lượng tải xuống (.quality-chips)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: separator,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chất lượng tải xuống',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Áp dụng cho các bài hát tải về nghe offline.',
                      style: TextStyle(fontSize: 11.5, color: palette.muted),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final q in qualityOptions)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => widget.controller
                                    .updatePreferences({'downloadQuality': q.$1}),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: prefs.downloadQuality == q.$1
                                        ? palette.selection
                                        : palette.raised,
                                    border: Border.all(
                                      color: prefs.downloadQuality == q.$1
                                          ? palette.pink
                                          : palette.border,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        q.$2,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: palette.text,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        q.$3,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: palette.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Hiệu ứng chuyển động & Giao diện
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Hiệu ứng sóng nhạc',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Hiển thị đĩa xoay và sóng nhạc trên Trang chủ',
                  style: TextStyle(fontSize: 11.5, color: palette.muted),
                ),
                value: prefs.motion,
                onChanged: (value) =>
                    widget.controller.updatePreferences({'motion': value}),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Giao diện sáng',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                value: prefs.light,
                onChanged: (value) =>
                    widget.controller.updatePreferences({'light': value}),
              ),
              const SizedBox(height: 16),
              const Text(
                'DỮ LIỆU',
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 1.8,
                  color: Color(0xff8f84a9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.backup_outlined),
                title: const Text(
                  'Sao lưu & khôi phục playlist',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Playlist chỉ lưu trên máy này. Sao lưu để chuyển sang máy khác.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xff7f728f)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PlaylistBackupScreen(controller: widget.controller),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.storage_rounded),
                title: const Text(
                  'Dung lượng & bản tải',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Xem bài đã tải, xóa bản không cần và thử lại bản lỗi.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xff7f728f)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DownloadsScreen(controller: widget.controller),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BCMusic.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: palette.muted,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'VERSION ${BCMusicConfig.appVersion} · LIQUID GLASS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1.0,
                        color: palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
