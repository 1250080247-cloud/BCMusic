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
      final prefs = widget.controller.snapshot.preferences;
      final volume = _volume ?? prefs.volume.toDouble();

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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MAKE IT YOURS',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w600,
                            color: Color(0xffac92c1),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
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
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x14ffffff))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Âm lượng',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xffd1c7de),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1ac2a3e0),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0x33bfa0d9)),
                          ),
                          child: Text(
                            '${volume.round()}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xffceb7e4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.volume_up_rounded,
                          size: 20,
                          color: Color(0xffa89bb8),
                        ),
                        Expanded(
                          child: Slider(
                            value: volume,
                            max: 100,
                            activeColor: const Color(0xffb7a8d4),
                            inactiveColor: const Color(0x22ffffff),
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
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x14ffffff))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tốc độ phát',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xffd1c7de),
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
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x14ffffff))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chuyển bài mượt mà 5s',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xffd1c7de),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            prefs.crossfade
                                ? 'Giảm âm cuối bài, tăng âm đầu bài'
                                : 'Làm dịu khoảng chuyển giữa hai bài',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xff7f728f),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: prefs.crossfade,
                      activeThumbColor: const Color(0xfffaf4ff),
                      activeTrackColor: const Color(0xffb5a0cf),
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
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x14ffffff))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chất lượng tải xuống',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xffd1c7de),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Áp dụng cho các bài hát tải về nghe offline.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xff7f728f)),
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
                                        ? const Color(0x38a58bb3)
                                        : const Color(0xa1191c27),
                                    border: Border.all(
                                      color: prefs.downloadQuality == q.$1
                                          ? const Color(0x88b5a0d9)
                                          : context.palette.border,
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
                                          color: prefs.downloadQuality == q.$1
                                              ? const Color(0xffddd3f1)
                                              : const Color(0xff959aac),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        q.$3,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xff9d8eac),
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
                subtitle: const Text(
                  'Hiển thị chuyển động sóng âm trên trang khám phá',
                  style: TextStyle(fontSize: 11.5, color: Color(0xff7f728f)),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'BCMusic.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff9c92b1),
                      letterSpacing: -0.6,
                    ),
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'VERSION 1.3.0 · LIQUID GLASS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1.0,
                        color: Color(0xff766785),
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