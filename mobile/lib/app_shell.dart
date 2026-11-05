import 'package:flutter/material.dart';

import 'account_screen.dart';
import 'app_controller.dart';
import 'app_theme.dart';
import 'discovery.dart';
import 'discovery_screen.dart';
import 'home_screen.dart';
import 'models.dart';
import 'player_controls.dart';
import 'playlist_screen.dart';
import 'settings_screen.dart';

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
  static const _library = 2, _playlists = 3;
  int _tab = 0, _shareSequence = 0;
  bool _initialized = false;
  MusicController get _music => widget.controller;

  @override
  void initState() {
    super.initState();
    _updateTab();
    _music.addListener(_updateTab);
    widget.discovery.selectGenre(0);
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

  void _showProfile(AccountProfile account) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hồ sơ', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              _AccountAvatar(account: account, size: 88),
              const SizedBox(height: 16),
              Text(
                account.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (account.username.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '@${account.username}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.muted),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SongImage(song: song, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist,
                          style: TextStyle(color: context.palette.muted),
                        ),
                        if (song.durationMs > 0)
                          Text(
                            formatTime(song.durationMs),
                            style: TextStyle(color: context.palette.muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: playButtonStyle(context),
                onPressed: () => Navigator.pop(context, 'play'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Nghe trực tuyến'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'download'),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Tải offline'),
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

  Future<void> _addToPlaylist(OfflineTrack track) async {
    final playlists = _music.snapshot.playlists;
    if (playlists.isEmpty) {
      _select(_playlists);
      await createLocalPlaylist(context, _music, initialTrack: track);
      return;
    }
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Thêm vào playlist'),
        children: [
          for (final playlist in playlists)
            SimpleDialogOption(
              onPressed: playlist.trackIds.contains(track.id)
                  ? null
                  : () => Navigator.pop(context, playlist.id),
              child: ListTile(
                leading: Icon(
                  playlist.trackIds.contains(track.id)
                      ? Icons.check_rounded
                      : Icons.queue_music_rounded,
                ),
                title: Text(playlist.name),
                subtitle: playlist.trackIds.contains(track.id)
                    ? const Text('Đã thêm')
                    : null,
              ),
            ),
        ],
      ),
    );
    if (id != null && mounted) await _music.addToPlaylist(id, track);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_music, widget.discovery]),
    builder: (context, _) {
      final account = _music.snapshot.account;
      final pages = [
        DiscoveryScreen(
          controller: widget.discovery,
          playing: _music.playback.isPlaying,
          motion: _music.snapshot.preferences.motion,
          onMotion: (motion) => _music.updatePreferences({'motion': motion}),
          online: _music.snapshot.networkAvailable,
          onLibrary: () => _select(_library),
          onSong: _song,
          onPlay: _playSong,
        ),
        SearchScreen(
          controller: widget.discovery,
          onSong: _song,
          onPlay: _playSong,
        ),
        HomeScreen(controller: _music, onAddToPlaylist: _addToPlaylist),
        PlaylistScreen(controller: _music),
        HomeScreen(
          controller: _music,
          soundCloud: true,
          onAddToPlaylist: _addToPlaylist,
        ),
      ];
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 64,
          titleSpacing: 16,
          title: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/logo.jpg',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BCMusic',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                    Text(
                      account?.name ?? 'Chào mừng bạn',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
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
                  ? const Icon(Icons.account_circle_outlined)
                  : _AccountAvatar(account: account),
              onSelected: (action) {
                if (action == 'signOut') {
                  _music.signOut();
                } else if (action == 'profile' && account != null) {
                  _showProfile(account);
                } else {
                  _showAccount(register: action == 'register');
                }
              },
              itemBuilder: (_) => account == null
                  ? const [
                      PopupMenuItem(value: 'signIn', child: Text('Đăng nhập')),
                      PopupMenuItem(value: 'register', child: Text('Đăng ký')),
                    ]
                  : [
                      const PopupMenuItem(
                        value: 'profile',
                        child: Text('Hồ sơ'),
                      ),
                      const PopupMenuItem(
                        value: 'signOut',
                        child: Text('Đăng xuất'),
                      ),
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
              icon: const Icon(Icons.settings_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: 'Tùy chọn BCMusic',
              onSelected: (value) {
                if (value == 'link') {
                  _paste();
                } else if (value == 'web') {
                  _music.openWebsite();
                } else {
                  showAboutDialog(
                    context: context,
                    applicationName: 'BCMusic',
                    applicationVersion: '1.2.3',
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'link', child: Text('Nhập link bài hát')),
                PopupMenuItem(value: 'web', child: Text('Mở web BCMusic')),
                PopupMenuItem(value: 'about', child: Text('Về ứng dụng')),
              ],
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Column(
          children: [
            if (_music.openingSource)
              const LinearProgressIndicator(
                semanticsLabel: 'Đang chuẩn bị phát',
              ),
            if ((_music.snapshot.accountError ?? _music.error)
                case final error?)
              Material(
                color: context.palette.selection,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                        child: Semantics(liveRegion: true, child: Text(error)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng thông báo',
                      onPressed: _music.snapshot.accountError == null
                          ? _music.clearError
                          : _music.clearAccountError,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SafeArea(
                top: false,
                bottom: false,
                child: IndexedStack(
                  index: _tab,
                  children: [
                    for (final (index, page) in pages.indexed)
                      ExcludeFocus(
                        excluding: index != _tab,
                        child: TickerMode(enabled: index == _tab, child: page),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_music.playback.trackId != null)
                PlayerControls(
                  controller: _music,
                  onDownload: (url) {
                    _select(_library);
                    _music.inspect(url);
                  },
                  onAddToPlaylist: _addToPlaylist,
                ),
              const Divider(height: 1),
              NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: _select,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Trang chủ',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_rounded),
                    label: 'Tìm kiếm',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.library_music_outlined),
                    selectedIcon: Icon(Icons.library_music_rounded),
                    label: 'Thư viện',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.queue_music_rounded),
                    label: 'Playlist',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.cloud_outlined),
                    selectedIcon: Icon(Icons.cloud_rounded),
                    label: 'SoundCloud',
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

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.account, this.size = 32});

  final AccountProfile account;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = account.name.trim();
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: context.palette.raised,
      foregroundColor: context.palette.text,
      child: name.isEmpty
          ? const Icon(Icons.person_outline_rounded, size: 18)
          : Text(
              name.characters.first.toUpperCase(),
              maxLines: 1,
              style: TextStyle(fontSize: size * .42),
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
