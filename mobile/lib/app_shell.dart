import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account_screen.dart';
import 'app_config.dart';
import 'app_controller.dart';
import 'app_theme.dart';
import 'discovery.dart';
import 'discovery_screen.dart';
import 'home_screen.dart';
import 'models.dart';
import 'platform_bridge.dart';
import 'player_controls.dart';
import 'playlist_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'track_actions.dart';
import 'track_widgets.dart';
import 'update_checker.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.controller,
    required this.discovery,
  });
  final MusicController controller;
  final DiscoveryController discovery;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _library = 2;
  static const _playlists = 3;
  int _tab = 0, _shareSequence = 0;
  bool _initialized = false, _showingProfile = false;
  MusicController get _music => widget.controller;

  @override
  void initState() {
    super.initState();
    _updateTab();
    _music.addListener(_updateTab);
    widget.discovery.selectGenre(0);
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    final platform = _music.platform;
    if (kIsWeb || platform is! AndroidMusicPlatform) return;
    try {
      final version = await platform.getAppVersion();
      if (!mounted || version == null) return;
      final update = await checkForUpdate(currentVersion: version);
      if (!mounted || update == null) return;
      await showUpdateDialog(
        context,
        update,
        onDownload: update.downloadUrl.isEmpty
            ? null
            : () => unawaited(_openUpdate(platform, update.downloadUrl)),
      );
    } on PlatformException {
      // Update checks should not stop the app from starting.
    } on MissingPluginException {
      // The Android bridge is absent in the preview.
    }
  }

  Future<void> _openUpdate(AndroidMusicPlatform platform, String url) async {
    try {
      await platform.openUrl(url);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được link tải bản cập nhật.')),
      );
    }
  }

  @override
  void dispose() {
    _music.removeListener(_updateTab);
    super.dispose();
  }

  void _updateTab() {
    if (!_initialized && !_music.loading) {
      _initialized = true;
      if (!_music.snapshot.networkAvailable && _tab == 0) _select(_library);
    }
    final sequence = _music.snapshot.shareSequence;
    if (sequence > _shareSequence) {
      _shareSequence = sequence;
      _select(_library);
    }
  }

  void _select(int tab) {
    if (_tab != tab) setState(() => _tab = tab);
  }

  Future<void> _paste() async {
    final link = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const LinkInputSheet(),
    );
    if (link == null || !mounted) return;
    _select(_library);
    await _music.inspect(link);
  }

  void _showAccount({required bool register}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AccountScreen(controller: _music, register: register),
    );
  }

  Future<void> _showProfile() async {
    setState(() => _showingProfile = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(controller: _music)),
      );
    } finally {
      if (mounted) setState(() => _showingProfile = false);
    }
  }

  Future<void> _playSong(DiscoverySong song, List<DiscoverySong> queue) =>
      _music.playSource(
        song.sourceUrl,
        queue: queue.map((item) => item.sourceUrl),
        queueItems: queue.map(
          (item) => PlaybackQueueItem(
            url: item.sourceUrl,
            title: item.title,
            artist: item.artist,
            artworkUrl: item.thumbnail,
          ),
        ),
      );

  Future<void> _song(DiscoverySong song, List<DiscoverySong> queue) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SongImage(song: song, size: 68),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          song.artist,
                          style: TextStyle(
                            color: context.palette.muted,
                            fontSize: 13,
                          ),
                        ),
                        if (song.durationMs > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              formatTime(song.durationMs),
                              style: TextStyle(
                                color: context.palette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: playButtonStyle(context),
                onPressed: () => Navigator.pop(context, 'play'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Nghe trực tuyến'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'download'),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Tải bản nghe offline'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'download') {
      _select(_library);
      await _music.inspect(song.sourceUrl);
    } else if (action == 'play') {
      await _playSong(song, queue);
    }
  }

  Future<void> _addToPlaylist(OfflineTrack track) =>
      pickLocalPlaylist(context, _music, track);

  void _downloadSong(String url) {
    _select(_library);
    unawaited(_music.downloadSource(url));
  }

  Future<void> _discoveryTrackAction(
    TrackAction action,
    DiscoverySong song,
  ) async {
    final item = PlaybackQueueItem(
      url: song.sourceUrl,
      title: song.title,
      artist: song.artist,
      artworkUrl: song.thumbnail,
    );
    switch (action) {
      case TrackAction.share:
        await shareSong(context, _music, item.url);
      case TrackAction.playlist:
        await promptAddToPlaylist(
          context,
          _music,
          song: item,
          songId: song.id,
        );
      case TrackAction.queue:
        enqueueSong(context, _music, item);
      case TrackAction.info:
        await showTrackInfo(context, item, durationMs: song.durationMs);
      case TrackAction.remove:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_music, widget.discovery]),
    builder: (context, _) {
      final account = _music.snapshot.account;
      final platform = _music.platform;
      final playlistArtwork = _music.playingPlaylistArtwork;
      final track = _music.currentTrack;
      final artworkPath = track?.artworkPath;
      final artworkUrl = track?.artworkUrl ?? _music.currentSourceItem?.artworkUrl;
      final discArtwork = switch (playlistArtwork) {
        final artwork? => PlaylistArtwork(
          tracks: artwork.tracks,
          urls: artwork.urls,
          size: ListeningHero.discSize,
        ),
        _ when _music.playback.trackId != null &&
            (artworkPath?.isNotEmpty == true || artworkUrl?.isNotEmpty == true) =>
          TrackArtwork(path: artworkPath, url: artworkUrl, size: ListeningHero.discSize),
        _ => null,
      };
      final pages = [
        DiscoveryScreen(
          controller: widget.discovery,
          motion: _music.snapshot.preferences.motion,
          isPlaying: _music.playback.isPlaying,
          discArtwork: discArtwork,
          spectrum:
              _tab == 0 &&
                  _music.playback.isPlaying &&
                  platform is AndroidMusicPlatform
              ? platform.spectrum
              : null,
          online: _music.snapshot.networkAvailable,
          onLibrary: () => _select(_library),
          onSong: _song,
          onPlay: _playSong,
          onTrackAction: _discoveryTrackAction,
          onDownload: _downloadSong,
        ),
        SearchScreen(
          controller: widget.discovery,
          history: _music.snapshot.searchHistory,
          onRecordSearch: _music.recordSearch,
          onSong: _song,
          onPlay: _playSong,
          onTrackAction: _discoveryTrackAction,
        ),
        HomeScreen(controller: _music, onAddToPlaylist: _addToPlaylist),
        PlaylistScreen(
          controller: _music,
          active: _tab == _playlists && !_showingProfile,
        ),
        HomeScreen(
          controller: _music,
          soundCloud: true,
          onAddToPlaylist: _addToPlaylist,
          onPlaylist: () => _select(_playlists),
        ),
      ];

      return Scaffold(
        extendBody: true,
        appBar: AppBar(
          toolbarHeight: 64,
          titleSpacing: 18,
          title: Row(
            children: [
              // Logo .brand-logo từ App.tsx
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xffc3b7fb), Color(0xff8b7acd)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x30b5a4f0),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const Center(
                      child: EqualizerBars(
                        active: false,
                        color: Color(0xff211a36),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BCMusic',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: context.palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      getHeaderGreeting(account?.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Tài khoản',
              icon: account == null
                  ? Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xffdac4ab), Color(0xff7d5d5c)],
                        ),
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: Color(0xff3c2e31),
                      ),
                    )
                  : AccountAvatar(account: account),
              onSelected: (action) {
                if (action == 'signOut') {
                  _music.signOut();
                } else if (action == 'profile' && account != null) {
                  _showProfile();
                } else {
                  _showAccount(register: action == 'register');
                }
              },
              itemBuilder: (_) => account == null
                  ? const [
                      PopupMenuItem(value: 'signIn', child: Text('Đăng nhập')),
                      PopupMenuItem(value: 'register', child: Text('Đăng ký')),
                    ]
                  : const [
                      PopupMenuItem(value: 'profile', child: Text('Hồ sơ')),
                      PopupMenuItem(value: 'signOut', child: Text('Đăng xuất')),
                    ],
            ),
            IconButton(
              tooltip: 'Cài đặt',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => SettingsScreen(controller: _music),
              ),
              icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x0affffff),
                  border: Border.all(color: const Color(0x18ffffff)),
                ),
                child: const Icon(Icons.settings_outlined, size: 18),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Tùy chọn BCMusic',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (value) {
                if (value == 'link') {
                  _paste();
                } else if (value == 'web') {
                  _music.openWebsite();
                } else {
                  showAboutDialog(
                    context: context,
                    applicationName: 'BCMusic',
                    applicationVersion: '${BCMusicConfig.appVersion} · Liquid Glass',
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'link', child: Text('Nhập link bài hát')),
                PopupMenuItem(value: 'web', child: Text('Mở web BCMusic')),
                PopupMenuItem(value: 'about', child: Text('Về ứng dụng')),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.6, -1.0),
              radius: 1.2,
              colors: [Color(0x3839264a), Color(0x000b0d14)],
            ),
          ),
          child: Column(
            children: [
              if (_music.openingSource)
                const LinearProgressIndicator(
                  minHeight: 2,
                  semanticsLabel: 'Đang chuẩn bị phát',
                ),
              if ((_music.snapshot.accountError ?? _music.error)
                  case final error?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: LiquidGlassCard(
                    borderRadius: 13,
                    padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                    borderColor: const Color(0x45c0a3df),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng thông báo',
                          onPressed: _music.snapshot.accountError == null
                              ? _music.clearError
                              : _music.clearAccountError,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: _AnimatedTabStack(
                    index: _tab,
                    children: pages,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Builder(
            builder: (context) {
              final disableAnimations = MediaQuery.disableAnimationsOf(context);
              final hasTrack = _music.playback.trackId != null;
              return Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 240),
                      reverseDuration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        if (disableAnimations) return child;
                        final curved = animation.drive(
                          CurveTween(curve: Curves.easeOutCubic),
                        );
                        return SizeTransition(
                          sizeFactor: curved,
                          alignment: Alignment.topCenter,
                          child: FadeTransition(opacity: curved, child: child),
                        );
                      },
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          for (final previous in previousChildren)
                            IgnorePointer(
                              child: HeroMode(enabled: false, child: previous),
                            ),
                          ?currentChild,
                        ],
                      ),
                      child: hasTrack
                          ? Padding(
                              key: const ValueKey('mini-player'),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: PlayerControls(
                                controller: _music,
                                onDownload: _downloadSong,
                                onAddToPlaylist: _addToPlaylist,
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('mini-player-empty'),
                            ),
                    ),
                    GlassNavigationBar(
                      selectedIndex: _tab,
                      onDestinationSelected: _select,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

class _AnimatedTabStack extends StatefulWidget {
  const _AnimatedTabStack({
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<_AnimatedTabStack> createState() => _AnimatedTabStackState();
}

class _AnimatedTabStackState extends State<_AnimatedTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 230),
    value: 1.0,
  );
  double _direction = 1.0;

  @override
  void didUpdateWidget(covariant _AnimatedTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _direction = widget.index > oldWidget.index ? 1.0 : -1.0;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final opacity = disableAnimations
        ? const AlwaysStoppedAnimation<double>(1.0)
        : _controller.drive(
            Tween<double>(begin: 0.45, end: 1.0).chain(
              CurveTween(curve: Curves.easeOutCubic),
            ),
          );
    final position = disableAnimations
        ? const AlwaysStoppedAnimation<Offset>(Offset.zero)
        : _controller.drive(
            Tween<Offset>(
              begin: Offset(0.06 * _direction, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          );

    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: position,
        child: IndexedStack(
          index: widget.index,
          children: [
            for (final (i, page) in widget.children.indexed)
              ExcludeFocus(
                excluding: i != widget.index,
                child: TickerMode(
                  enabled: i == widget.index,
                  child: page,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const items = [
    (Icons.home_outlined, Icons.home_rounded, 'Trang chủ'),
    (Icons.search_rounded, Icons.search_rounded, 'Tìm kiếm'),
    (Icons.library_music_outlined, Icons.library_music_rounded, 'Thư viện'),
    (Icons.queue_music_rounded, Icons.queue_music_rounded, 'Playlist'),
    (Icons.cloud_outlined, Icons.cloud_rounded, 'SoundCloud'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final unselected = light ? palette.muted : const Color(0xffa7a9bb);
    return LiquidGlassCard(
      borderRadius: 23,
      blur: 32,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      gradient: light ? palette.surfaceGradient : const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xd9272a39), Color(0xed191d29)],
      ),
      borderColor: light ? palette.border : const Color(0x28bfc8e4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final (index, item) in items.indexed)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onDestinationSelected(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        width: 48,
                        height: 31,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: light && selectedIndex == index ? palette.selection : null,
                          gradient: !light && selectedIndex == index
                              ? const LinearGradient(
                                  colors: [
                                    Color(0x38c1a4e0),
                                    Color(0x20b2a3d5),
                                  ],
                                )
                              : null,
                          border: Border.all(
                            color: selectedIndex == index
                                ? (light ? palette.border : const Color(0x40c1ade5))
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          selectedIndex == index ? item.$2 : item.$1,
                          size: 20,
                          color: selectedIndex == index
                              ? (light ? palette.action : const Color(0xffe7dcfa))
                              : unselected,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selectedIndex == index
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selectedIndex == index
                              ? (light ? palette.action : const Color(0xffd4c4e8))
                              : unselected,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String getGreetingTimeOfDay([DateTime? time]) {
  final hour = (time ?? DateTime.now()).hour;
  if (hour >= 5 && hour < 11) return 'Chào buổi sáng';
  if (hour >= 11 && hour < 13) return 'Chào buổi trưa';
  if (hour >= 13 && hour < 18) return 'Chào buổi chiều';
  return 'Chào buổi tối';
}

String getHeaderGreeting(String? name, [DateTime? time]) {
  final greeting = getGreetingTimeOfDay(time);
  final displayName = name?.trim();
  if (displayName != null && displayName.isNotEmpty) {
    return '$greeting, $displayName';
  }
  return '$greeting, Người nghe nhạc';
}
