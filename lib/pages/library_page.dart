import 'package:flutter/material.dart';
import '../audio/audio_controller.dart';
import '../models/music_models.dart';
import 'playlists_page.dart';
import 'playlist_detail_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final likedSongsPlaylist = PlaylistModel(
      id: 'liked_songs',
      title: 'Tus Me Gusta',
      description: 'Canciones que has marcado con me gusta',
      coverUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=60',
      category: 'Me gusta',
      songs: [
        const SongItem(
          id: 'L_jWHffIx5E',
          title: 'Smells Like Teen Spirit',
          artist: 'Nirvana',
          album: 'Nevermind',
          duration: Duration(minutes: 5, seconds: 1),
          thumbnailUrl: 'https://img.youtube.com/vi/L_jWHffIx5E/maxresdefault.jpg',
        ),
        const SongItem(
          id: 'fJ9rUzIMcZQ',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          album: 'A Night at the Opera',
          duration: Duration(minutes: 5, seconds: 55),
          thumbnailUrl: 'https://img.youtube.com/vi/fJ9rUzIMcZQ/maxresdefault.jpg',
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primary,
                    child: Icon(Icons.person, color: colorScheme.onPrimary),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu Biblioteca',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Colección personal & descargas',
                        style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.add_rounded,
                      color: colorScheme.onSurface,
                      size: 28,
                    ),
                    onPressed: () {
                      _showCreatePlaylistDialog(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Liked Songs Hero Banner Tile
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PlaylistDetailPage(playlist: likedSongsPlaylist),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: colorScheme.onPrimary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tus Me Gusta',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${likedSongsPlaylist.trackCount} canciones guardadas',
                              style: TextStyle(
                                color: colorScheme.onPrimary.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FloatingActionButton.small(
                        heroTag: 'play_liked_songs',
                        backgroundColor: colorScheme.onPrimary,
                        onPressed: () {
                          audioController.playQueue(
                            likedSongsPlaylist.songs,
                            initialIndex: 0,
                          );
                        },
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Library Shortcut Grid
              Row(
                children: [
                  Expanded(
                    child: _buildLibraryShortcutCard(
                      context: context,
                      icon: Icons.history_rounded,
                      title: 'Historial',
                      subtitle: 'Recientes',
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLibraryShortcutCard(
                      context: context,
                      icon: Icons.download_done_rounded,
                      title: 'Guardadas',
                      subtitle: 'Offline',
                      color: colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Custom User Playlists
              Text(
                'Tus Playlists',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: samplePlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = samplePlaylists[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          playlist.coverUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        playlist.title,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${playlist.trackCount} canciones • ${playlist.category}',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.54),
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PlaylistDetailPage(playlist: playlist),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryShortcutCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Nueva Playlist',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: TextField(
            controller: controller,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Nombre de la playlist',
              hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.38)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.54)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Crear', style: TextStyle(color: colorScheme.onPrimary)),
            ),
          ],
        );
      },
    );
  }
}
