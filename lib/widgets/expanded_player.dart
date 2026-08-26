import 'dart:ui';
import 'package:flutter/material.dart';
import '../audio/audio_controller.dart';

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

        return Scaffold(
          backgroundColor: const Color(0xFF0F0B1A),
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
                        const Color(0xFF4C1D95).withValues(alpha: 0.45),
                        const Color(0xFF0F0B1A),
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
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: widget.onClose,
                          ),
                          Column(
                            children: [
                              Text(
                                'REPRODUCIENDO DE',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                album,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white,
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
                              color: const Color(0xFFA855F7).withValues(alpha: 0.3),
                              blurRadius: 36,
                              spreadRadius: -4,
                              offset: const Offset(0, 16),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
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
                                  style: const TextStyle(
                                    color: Colors.white,
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
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: _isLiked ? const Color(0xFFEC4899) : Colors.white60,
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
                              activeTrackColor: const Color(0xFFA855F7),
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                              thumbColor: Colors.white,
                              overlayColor: const Color(0xFFA855F7).withValues(alpha: 0.2),
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
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
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
                              color: isShuffle ? const Color(0xFFA855F7) : Colors.white60,
                              size: 24,
                            ),
                            onPressed: () {
                              audioController.toggleShuffle();
                            },
                          ),

                          // Previous Button
                          IconButton(
                            icon: const Icon(
                              Icons.skip_previous_rounded,
                              color: Colors.white,
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
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFA855F7),
                                  Color(0xFF7C3AED),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFA855F7).withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 3,
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(
                                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 38,
                                    ),
                                    onPressed: () {
                                      audioController.togglePlayPause();
                                    },
                                  ),
                          ),

                          // Next Button
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next_rounded,
                              color: Colors.white,
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
                              color: isLoop ? const Color(0xFFA855F7) : Colors.white60,
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
                          const Icon(
                            Icons.volume_down_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                activeTrackColor: Colors.white70,
                                inactiveTrackColor: Colors.white12,
                                thumbColor: Colors.white,
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
                              Icons.queue_music_rounded,
                              color: _showQueueSheet ? const Color(0xFFA855F7) : Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                _showQueueSheet = !_showQueueSheet;
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
