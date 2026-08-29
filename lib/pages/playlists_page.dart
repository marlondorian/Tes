import 'package:flutter/material.dart';
import 'package:macos_native_widgets/gtk/gtk_scaffold.dart';
import 'package:macos_native_widgets/gtk/native_appbar.dart';
import '../models/music_models.dart';
import 'playlist_detail_page.dart';
import '../audio/audio_controller.dart';

final List<PlaylistModel> samplePlaylists = [
  PlaylistModel(
    id: 'pl1',
    title: 'Éxitos Mundiales',
    description: 'Las canciones más populares del momento',
    coverUrl:
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60',
    category: 'Éxitos',
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
      const SongItem(
        id: 'hTWKbfoikeg',
        title: 'Numb',
        artist: 'Linkin Park',
        album: 'Meteora',
        duration: Duration(minutes: 3, seconds: 7),
        thumbnailUrl: 'https://img.youtube.com/vi/hTWKbfoikeg/maxresdefault.jpg',
      ),
    ],
  ),
  PlaylistModel(
    id: 'pl2',
    title: 'Chill & Relax',
    description: 'Música suave para desconectar y relajarse',
    coverUrl:
        'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=500&auto=format&fit=crop&q=60',
    category: 'Chill',
    songs: [
      const SongItem(
        id: '1w7OgIMMRcE',
        title: 'Sweet Child O Mine',
        artist: 'Guns N Roses',
        album: 'Appetite for Destruction',
        duration: Duration(minutes: 5, seconds: 56),
        thumbnailUrl: 'https://img.youtube.com/vi/1w7OgIMMRcE/maxresdefault.jpg',
      ),
      const SongItem(
        id: 'kXYiU_JCYtU',
        title: 'Numb / Encore',
        artist: 'Jay-Z & Linkin Park',
        album: 'Collision Course',
        duration: Duration(minutes: 3, seconds: 25),
        thumbnailUrl: 'https://img.youtube.com/vi/kXYiU_JCYtU/maxresdefault.jpg',
      ),
    ],
  ),
  PlaylistModel(
    id: 'pl3',
    title: 'Coding & Focus Zone',
    description: 'Ritmos instrumentales para mantener el flujo de trabajo',
    coverUrl:
        'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&auto=format&fit=crop&q=60',
    category: 'Focus',
    songs: [
      const SongItem(
        id: 'L_jWHffIx5E',
        title: 'Teen Spirit Lo-Fi Edit',
        artist: 'Nirvana',
        album: 'Remix Vault',
        duration: Duration(minutes: 4, seconds: 12),
        thumbnailUrl: 'https://img.youtube.com/vi/L_jWHffIx5E/maxresdefault.jpg',
      ),
    ],
  ),
  PlaylistModel(
    id: 'pl4',
    title: 'Workout Energy boost',
    description: 'Beats intensos para tu entrenamiento diario',
    coverUrl:
        'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60',
    category: 'Workout',
    songs: [
      const SongItem(
        id: 'hTWKbfoikeg',
        title: 'Numb Remix',
        artist: 'Linkin Park',
        album: 'Reanimation',
        duration: Duration(minutes: 3, seconds: 30),
        thumbnailUrl: 'https://img.youtube.com/vi/hTWKbfoikeg/maxresdefault.jpg',
      ),
    ],
  ),
];

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  String _selectedCategory = 'Todas';

  final List<String> _categories = [
    'Todas',
    'Éxitos',
    'Chill',
    'Focus',
    'Workout',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filteredPlaylists = _selectedCategory == 'Todas'
        ? samplePlaylists
        : samplePlaylists
              .where((p) => p.category == _selectedCategory)
              .toList();

    return Scaffold(
      appBar: NativeAppBar(
        title: GtkHeaderTitle(title: '      Playlissts & Colecciones'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title
              const SizedBox(height: 12),

              // Category Selector Chips
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final category = _categories[idx];
                    final isSelected = category == _selectedCategory;
                    return ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: colorScheme.primary,
                      backgroundColor: colorScheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Playlist Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: filteredPlaylists.length,
                  itemBuilder: (context, index) {
                    final playlist = filteredPlaylists[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PlaylistDetailPage(playlist: playlist),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.06,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cover Image with Quick Play Action
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                      child: Image.network(
                                        playlist.coverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  color: colorScheme.primary
                                                      .withValues(alpha: 0.2),
                                                  child: Icon(
                                                    Icons.music_note,
                                                    color:
                                                        colorScheme.onSurface,
                                                    size: 40,
                                                  ),
                                                ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: FloatingActionButton.small(
                                      heroTag: 'play_btn_${playlist.id}',
                                      backgroundColor: colorScheme.primary,
                                      onPressed: () {
                                        if (playlist.songs.isNotEmpty) {
                                          audioController.playQueue(
                                            playlist.songs,
                                            initialIndex: 0,
                                          );
                                        }
                                      },
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        color: colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Playlist Title & Subtitle
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    playlist.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${playlist.trackCount} canciones',
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
