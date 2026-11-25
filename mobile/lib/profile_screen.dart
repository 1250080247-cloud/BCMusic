import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'models.dart';
import 'platform_bridge.dart';
import 'playlist_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});
  final MusicController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _imageUrl = TextEditingController();
  String? _pickedImage, _error;
  bool _editing = false, _saving = false, _picking = false;
  late Future<Map<String, dynamic>> _collections;
  int _youtubeRevision = 0;

  AndroidMusicPlatform? get _platform => switch (widget.controller.platform) {
    final AndroidMusicPlatform platform => platform,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _youtubeRevision = widget.controller.youtubeRevision;
    _collections = _loadCollections();
    unawaited(widget.controller.refreshYouTubeStatus());
  }

  @override
  void dispose() {
    _name.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadCollections() =>
      loadAccountCollections(_platform);

  void _refreshCollections() =>
      setState(() => _collections = _loadCollections());

  void _edit(AccountProfile account) {
    _name.text = account.name;
    _imageUrl.clear();
    setState(() {
      _editing = true;
      _pickedImage = null;
      _error = null;
    });
  }

  Future<void> _chooseImage() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final data = await _platform?.pickProfileImage();
      if (mounted && data != null) {
        _imageUrl.clear();
        setState(() => _pickedImage = data);
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Chưa đọc được ảnh.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final input = _imageUrl.text.trim();
    final uri = Uri.tryParse(input);
    if (name.isEmpty || name.length > 50) {
      setState(() => _error = 'Tên hiển thị phải từ 1 đến 50 ký tự.');
      return;
    }
    if (input.isNotEmpty &&
        (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty)) {
      setState(() => _error = 'Nhập URL ảnh HTTPS hợp lệ.');
      return;
    }
    final platform = _platform;
    if (platform == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await platform.updateProfile(
        name,
        image: input.isNotEmpty ? input : _pickedImage,
      );
      if (mounted) setState(() => _editing = false);
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Chưa lưu được hồ sơ.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final account = widget.controller.snapshot.account;
      final local = widget.controller.snapshot.playlists;
      final downloadedCount = widget.controller.tracks
          .where((t) => t.isReady)
          .length;
      if (widget.controller.youtubeRevision != _youtubeRevision) {
        _youtubeRevision = widget.controller.youtubeRevision;
        _collections = _loadCollections();
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Hồ sơ của bạn')),
        body: account == null
            ? const Center(child: Text('Bạn chưa đăng nhập.'))
            : SafeArea(
                top: false,
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _collections,
                  builder: (context, snapshot) {
                    final favorites = [
                      if (snapshot.data?['favorites'] case final List rows)
                        for (final row in rows.whereType<Map>())
                          ?readAccountSong(row),
                    ];
                    final playlists = AccountPlaylist.readAll(
                      snapshot.data?['playlists'],
                    );

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                      children: [
                        // Thẻ Hồ sơ Liquid Glass (.profile-avatar & .profile-stats trong App.tsx)
                        LiquidGlassCard(
                          borderRadius: 22,
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: _editing && _pickedImage != null
                                    ? ClipOval(
                                        child: Image.memory(
                                          base64Decode(
                                            _pickedImage!.split(',').last,
                                          ),
                                          width: 76,
                                          height: 76,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : AccountAvatar(account: account, size: 76),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'YOUR PERSONAL MUSIC SPACE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.8,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xffac92c1),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Chào ${account.name}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              if (account.username.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '@${account.username}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.palette.muted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),

                              // .profile-stats 3 cột
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border.symmetric(
                                    horizontal: BorderSide(
                                      color: Color(0x14ffffff),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _ProfileStatItem(
                                      value: '${favorites.length}',
                                      label: 'Bài yêu thích',
                                    ),
                                    _ProfileStatItem(
                                      value:
                                          '${playlists.length + local.length}',
                                      label: 'Playlist',
                                    ),
                                    _ProfileStatItem(
                                      value: '$downloadedCount',
                                      label: 'Bài offline',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (_editing) ...[
                                if (!kIsWeb)
                                  OutlinedButton.icon(
                                    onPressed: _saving || _picking
                                        ? null
                                        : _chooseImage,
                                    icon: const Icon(Icons.photo_outlined),
                                    label: const Text('Chọn ảnh đại diện'),
                                  ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _name,
                                  maxLength: 50,
                                  enabled: !_saving,
                                  decoration: const InputDecoration(
                                    labelText: 'Tên hiển thị',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _imageUrl,
                                  enabled: !_saving,
                                  keyboardType: TextInputType.url,
                                  decoration: const InputDecoration(
                                    labelText: 'URL ảnh đại diện (HTTPS)',
                                  ),
                                ),
                                if (_error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton(
                                        style: playButtonStyle(context),
                                        onPressed: _saving || _picking
                                            ? null
                                            : _save,
                                        child: Text(
                                          _saving ? 'Đang lưu…' : 'Lưu hồ sơ',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    TextButton(
                                      onPressed: _saving || _picking
                                          ? null
                                          : () => setState(
                                              () => _editing = false,
                                            ),
                                      child: const Text('Hủy'),
                                    ),
                                  ],
                                ),
                              ] else
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    shape: const StadiumBorder(),
                                    side: const BorderSide(
                                      color: Color(0x36c2b4dd),
                                    ),
                                  ),
                                  onPressed: _platform == null
                                      ? null
                                      : () => _edit(account),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Chỉnh sửa hồ sơ'),
                                ),
                            ],
                          ),
                        ),
                        if (widget.controller.youtubeStatus.available) ...[
                          const SizedBox(height: 16),
                          _YouTubeSyncCard(controller: widget.controller),
                        ],
                        const SizedBox(height: 24),

                        if (snapshot.connectionState != ConnectionState.done)
                          const LinearProgressIndicator(
                            semanticsLabel: 'Đang tải hồ sơ',
                          )
                        else if (snapshot.hasError)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                snapshot.error is PlatformException
                                    ? (snapshot.error as PlatformException)
                                              .message ??
                                          'Chưa tải được hồ sơ.'
                                    : 'Chưa tải được hồ sơ.',
                              ),
                              TextButton(
                                onPressed: _refreshCollections,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Bài hát yêu thích (${favorites.length})',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Làm mới bài đã tim',
                                onPressed: _refreshCollections,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (favorites.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Chưa có bài hát yêu thích.',
                                style: TextStyle(color: Color(0xff8e849e)),
                              ),
                            ),
                          for (final song in favorites)
                            accountSongTile(
                              widget.controller,
                              song,
                              favorites,
                            ),
                          const SizedBox(height: 22),
                          Text(
                            'Playlist tài khoản (${playlists.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (playlists.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Chưa có playlist trên web.',
                                style: TextStyle(color: Color(0xff8e849e)),
                              ),
                            ),
                          for (final playlist in playlists)
                            AccountPlaylistTile(
                              controller: widget.controller,
                              playlist: playlist,
                              onReturn: _refreshCollections,
                            ),
                        ],
                        const SizedBox(height: 22),
                        Text(
                          'Playlist offline (${local.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (local.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Chưa có playlist trên thiết bị.',
                              style: TextStyle(color: Color(0xff8e849e)),
                            ),
                          ),
                        for (final playlist in local)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.download_done_rounded,
                              color: Color(0xffc2abf3),
                            ),
                            title: Text(playlist.name),
                            subtitle: Text('${playlist.trackIds.length} bài hát'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlaylistDetail(
                                  controller: widget.controller,
                                  playlistId: playlist.id,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
      );
    },
  );
}

class _YouTubeSyncCard extends StatelessWidget {
  const _YouTubeSyncCard({required this.controller});

  final MusicController controller;

  String _formatSyncedAt(DateTime? dt) {
    if (dt == null) return 'Chưa đồng bộ lần nào';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return 'Đồng bộ gần nhất: $hh:$mm · $dd/$mo';
  }

  @override
  Widget build(BuildContext context) {
    final status = controller.youtubeStatus;
    final light = Theme.of(context).brightness == Brightness.light;
    final palette = context.palette;

    final String? badgeText = status.needsReconnect
        ? 'Cần kết nối lại'
        : status.connected
        ? 'Đang bật'
        : null;
    final Color badgeBg = status.needsReconnect
        ? (light ? const Color(0xfffff2e5) : const Color(0x33ffb74d))
        : (light ? const Color(0xffe9f7ef) : const Color(0x2e66bb6a));
    final Color badgeFg = status.needsReconnect
        ? (light ? const Color(0xffb25e09) : const Color(0xffffcc80))
        : (light ? const Color(0xff1e7e45) : const Color(0xff9be7a5));

    return LiquidGlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      gradient: light
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xfffff4f5), Color(0xfff5f3fa)],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xe62d1822), Color(0xe6191927)],
            ),
      borderColor: light ? const Color(0x4dd6455d) : const Color(0x4dff5c70),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.play_circle_filled_rounded,
                color: Color(0xffff5c70),
                size: 22,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Kết nối YouTube',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeFg,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (status.needsReconnect) ...[
            Text(
              'Phiên đồng bộ YouTube đã hết hạn sau 7 ngày. Kết nối lại để cập nhật Nhạc đã thích và playlist YouTube.',
              style: TextStyle(fontSize: 12.5, color: palette.muted),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: playButtonStyle(context),
              onPressed: controller.syncingYouTube
                  ? null
                  : () => controller.connectYouTube(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Kết nối lại YouTube'),
            ),
          ] else if (status.connected) ...[
            Text(
              '${_formatSyncedAt(status.lastSyncedAt)} · ${status.likedCount} bài đã thích · ${status.playlistCount} playlist',
              style: TextStyle(fontSize: 12.5, color: palette.muted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: playButtonStyle(context),
                  onPressed: controller.syncingYouTube
                      ? null
                      : () => controller.syncYouTubeNow(),
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: Text(
                    controller.syncingYouTube
                        ? 'Đang đồng bộ...'
                        : 'Đồng bộ ngay',
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: BorderSide(
                      color: light
                          ? const Color(0x57d6455d)
                          : const Color(0x57ff5c70),
                    ),
                  ),
                  onPressed: controller.syncingYouTube
                      ? null
                      : () => controller.disconnectYouTube(),
                  icon: const Icon(Icons.link_off_rounded, size: 18),
                  label: const Text('Ngắt kết nối'),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Đồng bộ Nhạc đã thích, playlist YouTube và gợi ý nghe nhạc cá nhân. Chỉ dùng quyền đọc youtube.readonly, không ảnh hưởng dữ liệu gốc.',
              style: TextStyle(fontSize: 12.5, color: palette.muted),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: playButtonStyle(context),
              onPressed: controller.syncingYouTube
                  ? null
                  : () => controller.connectYouTube(),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Kết nối tài khoản YouTube'),
            ),
          ],
          if (controller.youtubeError case final error?) ...[
            const SizedBox(height: 10),
            Text(
              error,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileStatItem extends StatelessWidget {
  const _ProfileStatItem({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xffd6bee7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xff9c8aa9)),
        ),
      ],
    ),
  );
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.account, this.size = 32});

  final AccountProfile account;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = account.name.trim();
    // Chuẩn màu .avatar trong index.css (#dac4ab -> #7d5d5c)
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffdac4ab), Color(0xff7d5d5c)],
        ),
        border: Border.all(color: const Color(0x33ffffff), width: 1.5),
      ),
      alignment: Alignment.center,
      child: name.isEmpty
          ? const Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: Color(0xff3c2e31),
            )
          : Text(
              name.characters.first.toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                fontSize: size * .42,
                fontWeight: FontWeight.w700,
                color: const Color(0xff3c2e31),
              ),
            ),
    );
    final uri = account.avatarUri;
    if (uri == null) return fallback;
    return ClipOval(
      child: Image.network(
        uri.toString(),
        width: size,
        height: size,
        cacheWidth: (size * 3).round(),
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        frameBuilder: (_, child, frame, synchronous) =>
            frame != null || synchronous ? child : fallback,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}