import 'package:flutter/material.dart';
import '../models/music_models.dart';
import 'playlist_detail_page.dart';
import '../audio/audio_controller.dart';

final List<PlaylistModel> samplePlaylists = [
  PlaylistModel(
    id: 'pl1',
    title: 'Éxitos Mundiales',
    description: 'Las canciones más populares del momento',
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60',
    category: 'Éxitos',
    songs: [
      const SongItem(
        id: 'L_jWHffIx5E',
        title: 'Smells Like Teen Spirit',
        artist: 'Nirvana',
        album: 'Nevermind',
        duration: Duration(minutes: 5, seconds: 1),
        thumbnailUrl: 'https://img.youtube.com/vi/L_jWHffIx5E/hqdefault.jpg',
      ),
      const SongItem(
        id: 'fJ9rUzIMcZQ',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        duration: Duration(minutes: 5, seconds: 55),
        thumbnailUrl: 'https://img.youtube.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
      ),
      const SongItem(
        id: 'hTWKbfoikeg',
        title: 'Numb',
        artist: 'Linkin Park',
        album: 'Meteora',
        duration: Duration(minutes: 3, seconds: 7),
        thumbnailUrl: 'https://img.youtube.com/vi/hTWKbfoikeg/hqdefault.jpg',
      ),
    ],
  ),
  PlaylistModel(
    id: 'pl2',
    title: 'Chill & Relax',
    description: 'Música suave para desconectar y relajarse',
    coverUrl: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=500&auto=format&fit=crop&q=60',
    category: 'Chill',
    songs: [
      const SongItem(
        id: '1w7OgIMMRcE',
        title: 'Sweet Child O Mine',
        artist: 'Guns N Roses',
        album: 'Appetite for Destruction',
        duration: Duration(minutes: 5, seconds: 56),
        thumbnailUrl: 'https://img.youtube.com/vi/1w7OgIMMRcE/hqdefault.jpg',
      ),
      const SongItem(
        id: 'kXYiU_JCYtU',
        title: 'Numb / Encore',
        artist: 'Jay-Z & Linkin Park',
        album: 'Collision Course',
        duration: Duration(minutes: 3, seconds: 25),
        thumbnailUrl: 'https://img.youtube.com/vi/kXYiU_JCYtU/hqdefault.jpg',
      ),
    ],
  ),
  PlaylistModel(
    id: 'pl3',
    title: 'Coding & Focus Zone',
    description: 'Ritmos instrumentales para mantener el flujo de trabajo',
    coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&auto=format&fit=crop&q=60',
    category: 'Focus',
    songs: [
      const SongItem(
        id: 'L_jWHffIx5E',
        title: 'Teen Spirit Lo-Fi Edit',
        artist: 'Nirvana',
        album: 'Remix Vault',
        duration: Duration(minutes: 4, seconds: 12),
        thumbnailUrl: 'https://img.youtube.com/vi/L_jWHffIx5E/hqdefault.jpg',
      ),
    ],
  ),
  PlaylistModel(
    id: 'pl4',
    title: 'Workout Energy boost',
    description: 'Beats intensos para tu entrenamiento diario',
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60',
    category: 'Workout',
    songs: [
      const SongItem(
        id: 'hTWKbfoikeg',
        title: 'Numb Remix',
        artist: 'Linkin Park',
        album: 'Reanimation',
        duration: Duration(minutes: 3, seconds: 30),
        thumbnailUrl: 'https://img.youtube.com/vi/hTWKbfoikeg/hqdefault.jpg',
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
    final filteredPlaylists = _selectedCategory == 'Todas'
        ? samplePlaylists
        : samplePlaylists.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Playlists Destacadas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Category Chip List
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final category = _categories[idx];
                    final isSelected = category == _selectedCategory;
                    return ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: const Color(0xFFA855F7),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFFA855F7) : Colors.transparent,
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
                            builder: (_) => PlaylistDetailPage(playlist: playlist),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
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
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.purple.shade900,
                                          child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white,
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
                                      backgroundColor: const Color(0xFFA855F7),
                                      onPressed: () {
                                        if (playlist.songs.isNotEmpty) {
                                          audioController.playQueue(playlist.songs, initialIndex: 0);
                                        }
                                      },
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${playlist.trackCount} canciones',
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
