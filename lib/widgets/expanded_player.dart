import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:dart_ytmusic_api/types.dart';
import '../audio/audio_controller.dart';
import '../pages/search_widget.dart';

class ExpandedPlayerWidget extends StatefulWidget {
  final VoidCallback onClose;

  const ExpandedPlayerWidget({
    super.key,
    required this.onClose,
  });

  @override
  State<ExpandedPlayerWidget> createState() => _ExpandedPlayerWidgetState();
}

class _ExpandedPlayerWidgetState extends State<ExpandedPlayerWidget> {
  bool _isLiked = false;
  bool _isDraggingSlider = false;
  double _dragValue = 0.0;
  bool _showQueueSheet = false;
  bool _showLyricsSheet = false;

  // Lyrics State
  TimedLyricsRes? _timedLyrics;
  List<_LrcLine>? _lrcLines;       // parsed from lrclib.net (LRC format)
  String? _plainLyrics;
  bool _isLoadingLyrics = false;
  String? _lyricsVideoId;
  String? _lyricsError;
  final ScrollController _lyricsScrollController = ScrollController();
  bool _lyricsSynced = true;
  bool _isProgrammaticScroll = false; // prevent auto-scroll from triggering re-sync
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _lyricsScrollController.addListener(_onLyricsScroll);
  }

  void _onLyricsScroll() {
    // Only disengage sync on real user-initiated scroll movement
    if (_isProgrammaticScroll) return;
    if (_lyricsScrollController.position.isScrollingNotifier.value) {
      if (_lyricsSynced) setState(() => _lyricsSynced = false);
    }
  }

  void _resyncLyrics() {
    setState(() {
      _lyricsSynced = true;
      _lastActiveIndex = -1; // force immediate re-scroll
    });
  }

  @override
  void dispose() {
    _lyricsScrollController.removeListener(_onLyricsScroll);
    _lyricsScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLyrics(String videoId) async {
    if (_lyricsVideoId == videoId) return;
    setState(() {
      _lyricsVideoId = videoId;
      _isLoadingLyrics = true;
      _timedLyrics = null;
      _lrcLines = null;
      _plainLyrics = null;
      _lyricsError = null;
      _lastActiveIndex = -1;
      _lyricsSynced = true;
    });

    final title = audioController.currentTitle ?? '';
    final artist = audioController.currentArtist ?? '';

    // 1. Try YT Music timed lyrics first
    try {
      final timed = await ytmusic.getTimedLyrics(videoId);
      if (timed != null && timed.timedLyricsData.isNotEmpty) {
        setState(() {
          _timedLyrics = timed;
          _isLoadingLyrics = false;
        });
        return;
      }
    } catch (_) {}

    // 2. Try lrclib.net (Musixmatch-sourced, LRC format, synced lyrics)
    try {
      final lrcLines = await _fetchLrcLib(title, artist);
      if (lrcLines != null && lrcLines.isNotEmpty) {
        setState(() {
          _lrcLines = lrcLines;
          _isLoadingLyrics = false;
        });
        return;
      }
    } catch (_) {}

    // 3. Fallback: plain YT Music lyrics
    try {
      final plain = await ytmusic.getLyrics(videoId);
      setState(() {
        _plainLyrics = plain;
        _isLoadingLyrics = false;
      });
    } catch (e) {
      setState(() {
        _lyricsError = 'No se pudieron cargar las letras';
        _isLoadingLyrics = false;
      });
    }
  }

  /// Fetches synced LRC lyrics from lrclib.net and parses them
  Future<List<_LrcLine>?> _fetchLrcLib(String title, String artist) async {
    if (title.isEmpty) return null;
    final uri = Uri.https('lrclib.net', '/api/get', {
      'track_name': title,
      'artist_name': artist,
    });
    final response = await http.get(uri, headers: {'Lrclib-Client': 'MusicApp/1.0'}).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as Map<String, dynamic>;
    final syncedLyrics = data['syncedLyrics'] as String?;
    if (syncedLyrics == null || syncedLyrics.isEmpty) {
      // Fall back to plain lyrics from lrclib if available
      final plain = data['plainLyrics'] as String?;
      if (plain != null && plain.isNotEmpty) {
        // Return null so _plainLyrics path is used instead
        return null;
      }
      return null;
    }
    return _parseLrc(syncedLyrics);
  }

  /// Parses standard LRC format: [mm:ss.xx] lyric line
  List<_LrcLine> _parseLrc(String lrc) {
    final lines = <_LrcLine>[];
    final pattern = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    for (final rawLine in lrc.split('\n')) {
      final match = pattern.firstMatch(rawLine.trim());
      if (match == null) continue;
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final centis = match.group(3)!;
      final ms = (centis.length == 2
          ? int.parse(centis) * 10
          : int.parse(centis));
      final startMs = (minutes * 60 + seconds) * 1000 + ms;
      final text = match.group(4)!.trim();
      lines.add(_LrcLine(startMs: startMs, text: text));
    }
    return lines;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: audioController,
      builder: (context, _) {
        final songTitle = audioController.currentTitle ?? 'Sin canción seleccionada';
        final artist = audioController.currentArtist ?? 'Artista desconocido';
        final album = audioController.currentAlbum ?? 'Álbum no especificado';
        final thumbnailUrl = audioController.currentThumbnailUrl;
        final videoId = audioController.currentVideoId;

        if (videoId != null && videoId != _lyricsVideoId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fetchLyrics(videoId);
          });
        }

        final position = audioController.position;
        final duration = audioController.duration;
        final isPlaying = audioController.isPlaying;
        final isLoading = audioController.isLoadingStream;
        final isShuffle = audioController.isShuffle;
        final isLoop = audioController.isLoop;
        final volume = audioController.volume;
        final queue = audioController.queue;
        final currentIndex = audioController.currentIndex;

        final currentPositionMs = _isDraggingSlider
            ? _dragValue
            : position.inMilliseconds.toDouble().clamp(
                0.0,
                duration.inMilliseconds > 0
                    ? duration.inMilliseconds.toDouble()
                    : 1.0,
              );

        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: Stack(
            children: [
              // Ambient Background Glow
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.4),
                      radius: 1.2,
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.35),
                        colorScheme.surface,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Header bar with collapse button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: colorScheme.onSurface,
                              size: 32,
                            ),
                            onPressed: widget.onClose,
                          ),
                          Column(
                            children: [
                              Text(
                                'REPRODUCIENDO DE',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                album,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: colorScheme.onSurface,
                            ),
                            onPressed: () {
                              _showSongOptions(context, songTitle, artist);
                            },
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Album Cover Art
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 340, maxWidth: 340),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 36,
                              spreadRadius: -4,
                              offset: const Offset(0, 16),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                              ? Image.network(
                                  thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildFallbackArt(),
                                )
                              : _buildFallbackArt(),
                        ),
                      ),

                      const Spacer(),

                      // Track Info & Favorite Toggle
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  songTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: _isLiked ? Colors.pinkAccent : colorScheme.onSurface.withValues(alpha: 0.6),
                              size: 28,
                            ),
                            onPressed: () {
                              setState(() {
                                _isLiked = !_isLiked;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Interactive Position Slider
                      Column(
                        children: [
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                              activeTrackColor: colorScheme.primary,
                              inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.15),
                              thumbColor: colorScheme.onSurface,
                              overlayColor: colorScheme.primary.withValues(alpha: 0.2),
                            ),
                            child: Slider(
                              min: 0.0,
                              max: duration.inMilliseconds > 0
                                  ? duration.inMilliseconds.toDouble()
                                  : 1.0,
                              value: currentPositionMs.clamp(
                                0.0,
                                duration.inMilliseconds > 0
                                    ? duration.inMilliseconds.toDouble()
                                    : 1.0,
                              ),
                              onChangeStart: (val) {
                                setState(() {
                                  _isDraggingSlider = true;
                                  _dragValue = val;
                                });
                              },
                              onChanged: (val) {
                                setState(() {
                                  _dragValue = val;
                                });
                              },
                              onChangeEnd: (val) {
                                audioController.seek(
                                  Duration(milliseconds: val.toInt()),
                                );
                                setState(() {
                                  _isDraggingSlider = false;
                                });
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(
                                    Duration(milliseconds: currentPositionMs.toInt()),
                                  ),
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Player Main Control Deck
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Shuffle Button
                          IconButton(
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: isShuffle ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6),
                              size: 24,
                            ),
                            onPressed: () {
                              audioController.toggleShuffle();
                            },
                          ),

                          // Previous Button
                          IconButton(
                            icon: Icon(
                              Icons.skip_previous_rounded,
                              color: colorScheme.onSurface,
                              size: 38,
                            ),
                            onPressed: () {
                              audioController.playPrevious();
                            },
                          ),

                          // Play / Pause Main Container
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.primary.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: isLoading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                                      strokeWidth: 3,
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(
                                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: colorScheme.onPrimary,
                                      size: 38,
                                    ),
                                    onPressed: () {
                                      audioController.togglePlayPause();
                                    },
                                  ),
                          ),

                          // Next Button
                          IconButton(
                            icon: Icon(
                              Icons.skip_next_rounded,
                              color: colorScheme.onSurface,
                              size: 38,
                            ),
                            onPressed: () {
                              audioController.playNext();
                            },
                          ),

                          // Repeat / Loop Button
                          IconButton(
                            icon: Icon(
                              Icons.repeat_rounded,
                              color: isLoop ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6),
                              size: 24,
                            ),
                            onPressed: () {
                              audioController.toggleLoop();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Bottom Volume & Queue Bar
                      Row(
                        children: [
                          Icon(
                            Icons.volume_down_rounded,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            size: 20,
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                activeTrackColor: colorScheme.onSurface.withValues(alpha: 0.7),
                                inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.12),
                                thumbColor: colorScheme.onSurface,
                              ),
                              child: Slider(
                                value: volume,
                                onChanged: (val) {
                                  audioController.setVolume(val);
                                },
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.volume_up_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(
                              Icons.lyrics_rounded,
                              color: _showLyricsSheet ? colorScheme.primary : Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                _showLyricsSheet = !_showLyricsSheet;
                                if (_showLyricsSheet) _showQueueSheet = false;
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.queue_music_rounded,
                              color: _showQueueSheet ? colorScheme.primary : Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                _showQueueSheet = !_showQueueSheet;
                                if (_showQueueSheet) _showLyricsSheet = false;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Synchronized Lyrics Overlay Sheet
              if (_showLyricsSheet)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.85),
                    child: SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.lyrics_rounded, color: colorScheme.primary),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Letras Sincronizadas',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _showLyricsSheet = false;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          Expanded(
                            child: _buildLyricsContent(context, position.inMilliseconds),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Queue Drawer Overlay (Up Next)
              if (_showQueueSheet)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'A continuación en la Cola',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _showQueueSheet = false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const Divider(color: Colors.white12),
                            Expanded(
                              child: queue.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No hay más canciones en la cola',
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: queue.length,
                                      itemBuilder: (context, idx) {
                                        final item = queue[idx];
                                        final isCurrent = idx == currentIndex;

                                        return ListTile(
                                          leading: ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: item.thumbnailUrl != null
                                                ? Image.network(
                                                    item.thumbnailUrl!,
                                                    width: 44,
                                                    height: 44,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        Container(color: Colors.deepPurple),
                                                  )
                                                : Container(
                                                    width: 44,
                                                    height: 44,
                                                    color: Colors.deepPurple,
                                                    child: const Icon(
                                                      Icons.music_note,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                          ),
                                          title: Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isCurrent
                                                  ? const Color(0xFFA855F7)
                                                  : Colors.white,
                                              fontWeight: isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          subtitle: Text(
                                            item.artist,
                                            maxLines: 1,
                                            style: const TextStyle(color: Colors.white54),
                                          ),
                                          trailing: isCurrent
                                              ? const Icon(
                                                  Icons.bar_chart_rounded,
                                                  color: Color(0xFFA855F7),
                                                )
                                              : null,
                                          onTap: () {
                                            audioController.playQueue(queue, initialIndex: idx);
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackArt() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade800,
            Colors.indigo.shade900,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 100,
          color: Colors.white38,
        ),
      ),
    );
  }

  Widget _buildLyricsContent(BuildContext context, int positionMs) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoadingLyrics) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Cargando letras...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    if (_timedLyrics != null && _timedLyrics!.timedLyricsData.isNotEmpty) {
      final lines = _timedLyrics!.timedLyricsData;

      // Find active line index
      int activeIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        final cue = lines[i].cueRange;
        if (cue != null) {
          if (positionMs >= cue.startTimeMilliseconds && positionMs <= cue.endTimeMilliseconds) {
            activeIndex = i;
            break;
          } else if (positionMs > cue.endTimeMilliseconds) {
            activeIndex = i;
          }
        }
      }

      // Auto-scroll to center the active line — guard with _isProgrammaticScroll
      if (_lyricsSynced && activeIndex >= 0 && activeIndex != _lastActiveIndex) {
        _lastActiveIndex = activeIndex;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_lyricsScrollController.hasClients) return;
          final viewportHeight = _lyricsScrollController.position.viewportDimension;
          final itemOffset = activeIndex * 54.0 + 40;
          final centeredOffset = (itemOffset - viewportHeight / 2 + 27).clamp(
            0.0,
            _lyricsScrollController.position.maxScrollExtent,
          );
          _isProgrammaticScroll = true;
          _lyricsScrollController
              .animateTo(
                centeredOffset,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              )
              .then((_) => _isProgrammaticScroll = false);
        });
      }

      return Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Ignore scroll events we triggered ourselves
              if (_isProgrammaticScroll) return false;
              if (notification is UserScrollNotification) {
                if (_lyricsSynced) setState(() => _lyricsSynced = false);
              }
              return false;
            },
            child: ListView.builder(
              controller: _lyricsScrollController,
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: MediaQuery.of(context).size.height * 0.35,
              ),
              itemCount: lines.length,
              itemBuilder: (context, idx) {
                final lineData = lines[idx];
                final text = lineData.lyricLine ?? '';
                final isActive = idx == activeIndex;
                final cue = lineData.cueRange;

                return GestureDetector(
                  onTap: cue != null
                      ? () {
                          audioController.seek(
                            Duration(milliseconds: cue.startTimeMilliseconds),
                          );
                          setState(() => _lyricsSynced = true);
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        fontSize: isActive ? 23 : 17,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        height: 1.4,
                      ),
                      child: Text(
                        text,
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Re-sync button — shown when user has scrolled away
          if (!_lyricsSynced)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _resyncLyrics,
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Volver al verso actual',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // lrclib.net synced LRC lyrics (Musixmatch-sourced)
    if (_lrcLines != null && _lrcLines!.isNotEmpty) {
      final lines = _lrcLines!;

      // Find active line index
      int activeIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        if (positionMs >= lines[i].startMs) {
          activeIndex = i;
        } else {
          break;
        }
      }

      // Auto-scroll
      if (_lyricsSynced && activeIndex >= 0 && activeIndex != _lastActiveIndex) {
        _lastActiveIndex = activeIndex;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_lyricsScrollController.hasClients) return;
          final viewportHeight = _lyricsScrollController.position.viewportDimension;
          final itemOffset = activeIndex * 54.0 + 40;
          final centeredOffset = (itemOffset - viewportHeight / 2 + 27).clamp(
            0.0,
            _lyricsScrollController.position.maxScrollExtent,
          );
          _isProgrammaticScroll = true;
          _lyricsScrollController
              .animateTo(centeredOffset,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic)
              .then((_) => _isProgrammaticScroll = false);
        });
      }

      return Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (_isProgrammaticScroll) return false;
              if (notification is UserScrollNotification) {
                if (_lyricsSynced) setState(() => _lyricsSynced = false);
              }
              return false;
            },
            child: ListView.builder(
              controller: _lyricsScrollController,
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: MediaQuery.of(context).size.height * 0.35,
              ),
              itemCount: lines.length,
              itemBuilder: (context, idx) {
                final line = lines[idx];
                final isActive = idx == activeIndex;

                return GestureDetector(
                  onTap: () {
                    audioController.seek(Duration(milliseconds: line.startMs));
                    setState(() => _lyricsSynced = true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
                        fontSize: isActive ? 23 : 17,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        height: 1.4,
                      ),
                      child: Text(line.text, textAlign: TextAlign.left),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!_lyricsSynced)
            Positioned(
              bottom: 24, left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _resyncLyrics,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location_rounded, color: Colors.white.withValues(alpha: 0.9), size: 16),
                        const SizedBox(width: 8),
                        Text('Volver al verso actual', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (_plainLyrics != null && _plainLyrics!.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Text(
          _plainLyrics!,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 18,
            height: 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            _lyricsError ?? 'No hay letras disponibles para esta canción',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showSongOptions(BuildContext context, String title, String artist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(artist, style: const TextStyle(color: Colors.white54)),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white70),
                title: const Text('Añadir a playlist', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white70),
                title: const Text('Ir al artista', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.white70),
                title: const Text('Compartir canción', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Simple data class for a parsed LRC lyric line
class _LrcLine {
  final int startMs;
  final String text;
  const _LrcLine({required this.startMs, required this.text});
}
