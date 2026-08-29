import 'package:flutter/material.dart';
import '../audio/audio_controller.dart';

class MiniPlayerWidget extends StatelessWidget {
  final VoidCallback onTapExpand;

  const MiniPlayerWidget({
    super.key,
    required this.onTapExpand,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: audioController,
      builder: (context, _) {
        final songTitle = audioController.currentTitle;
        if (songTitle == null || songTitle.isEmpty) {
          return const SizedBox.shrink();
        }

        final position = audioController.position;
        final duration = audioController.duration;
        final progress = (duration.inMilliseconds > 0)
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        final isPlaying = audioController.isPlaying;
        final isLoading = audioController.isLoadingStream;
        final artist = audioController.currentArtist ?? 'Artista desconocido';
        final thumbnailUrl = audioController.currentThumbnailUrl;

        final colorScheme = Theme.of(context).colorScheme;

        return GestureDetector(
          onTap: onTapExpand,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Micro progress indicator bar
                  SizedBox(
                    height: 2.5,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        // Album Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                              ? Image.network(
                                  thumbnailUrl,
                                  width: 46,
                                  height: 46,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 46,
                                    height: 46,
                                    color: colorScheme.primary.withValues(alpha: 0.2),
                                    child: Icon(
                                      Icons.music_note,
                                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                                      size: 24,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 46,
                                  height: 46,
                                  color: colorScheme.primary.withValues(alpha: 0.2),
                                  child: Icon(
                                    Icons.music_note,
                                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                                    size: 24,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12.0),

                        // Title & Artist
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                songTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.0,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 12.0,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons: Play/Pause, Next
                        if (isLoading)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: colorScheme.onSurface,
                              size: 28.0,
                            ),
                            onPressed: () {
                              audioController.togglePlayPause();
                            },
                          ),

                        IconButton(
                          icon: Icon(
                            Icons.skip_next_rounded,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            size: 26.0,
                          ),
                          onPressed: () {
                            audioController.playNext();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
