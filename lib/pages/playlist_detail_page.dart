import 'package:flutter/material.dart';
import 'package:macos_native_widgets/gtk/gtk_scaffold.dart';
import 'package:macos_native_widgets/gtk/native_appbar.dart';
import '../audio/audio_controller.dart';
import '../models/music_models.dart';

class PlaylistDetailPage extends StatelessWidget {
  final PlaylistModel playlist;

  const PlaylistDetailPage({super.key, required this.playlist});

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours h $minutes min';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: NativeAppBar(
        leading: GtkHeaderAction(
          id: "playlist-back",
          onPressed: () {
            Navigator.pop(context);
          },
          iconName: "go-previous-symbolic",
        ),
        title: "",
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: const Color(0xFF0F0B1A),
      body: CustomScrollView(
        slivers: [
          // Collapsible Header Bar
          SliverAppBar(
            leading: SizedBox(),
            expandedHeight: 320.0,
            pinned: true,
            backgroundColor: const Color(0xFF1B152B),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6D28D9).withValues(alpha: 0.8),
                          const Color(0xFF0F0B1A),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      // Playlist Cover Image
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: playlist.coverUrl.isNotEmpty
                              ? Image.network(
                                  playlist.coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.purple.shade900,
                                        child: const Icon(
                                          Icons.library_music_rounded,
                                          color: Colors.white,
                                          size: 50,
                                        ),
                                      ),
                                )
                              : Container(
                                  color: Colors.purple.shade900,
                                  child: const Icon(
                                    Icons.library_music_rounded,
                                    color: Colors.white,
                                    size: 50,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        playlist.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${playlist.description} • ${playlist.trackCount} canciones, ${_formatDuration(playlist.totalDuration)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons: Play All & Shuffle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (playlist.songs.isNotEmpty) {
                          audioController.playQueue(
                            playlist.songs,
                            initialIndex: 0,
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Reproducir Todo',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA855F7),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: () {
                      if (playlist.songs.isNotEmpty) {
                        final shuffled = List<SongItem>.from(playlist.songs)
                          ..shuffle();
                        audioController.playQueue(shuffled, initialIndex: 0);
                      }
                    },
                    icon: const Icon(
                      Icons.shuffle_rounded,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Songs List
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = playlist.songs[index];
              return ListenableBuilder(
                listenable: audioController,
                builder: (context, _) {
                  final isCurrentPlaying =
                      audioController.currentVideoId == song.id;

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentPlaying
                          ? const Color(0xFFA855F7).withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: SizedBox(
                        width: 40,
                        child: Center(
                          child: isCurrentPlaying
                              ? const Icon(
                                  Icons.bar_chart_rounded,
                                  color: Color(0xFFA855F7),
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrentPlaying
                              ? const Color(0xFFA855F7)
                              : Colors.white,
                          fontWeight: isCurrentPlaying
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (song.duration != null)
                            Text(
                              '${song.duration!.inMinutes}:${(song.duration!.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white54,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      onTap: () {
                        audioController.playQueue(
                          playlist.songs,
                          initialIndex: index,
                        );
                      },
                    ),
                  );
                },
              );
            }, childCount: playlist.songs.length),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }
}
