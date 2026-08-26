import 'package:flutter/material.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import '../audio/audio_controller.dart';
import '../models/music_models.dart';
import 'playlists_page.dart';
import 'playlist_detail_page.dart';
import 'search_widget.dart'; // contains ytmusic instance

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  late final Future<List<HomeSection>> _sectionsFuture;

  final List<SongItem> _quickPicks = const [
    SongItem(
      id: 'L_jWHffIx5E',
      title: 'Smells Like Teen Spirit',
      artist: 'Nirvana',
      album: 'Nevermind',
      duration: Duration(minutes: 5, seconds: 1),
      thumbnailUrl: 'https://img.youtube.com/vi/L_jWHffIx5E/hqdefault.jpg',
    ),
    SongItem(
      id: 'fJ9rUzIMcZQ',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      album: 'A Night at the Opera',
      duration: Duration(minutes: 5, seconds: 55),
      thumbnailUrl: 'https://img.youtube.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
    ),
    SongItem(
      id: 'hTWKbfoikeg',
      title: 'Numb',
      artist: 'Linkin Park',
      album: 'Meteora',
      duration: Duration(minutes: 3, seconds: 7),
      thumbnailUrl: 'https://img.youtube.com/vi/hTWKbfoikeg/hqdefault.jpg',
    ),
    SongItem(
      id: '1w7OgIMMRcE',
      title: 'Sweet Child O Mine',
      artist: 'Guns N Roses',
      album: 'Appetite for Destruction',
      duration: Duration(minutes: 5, seconds: 56),
      thumbnailUrl: 'https://img.youtube.com/vi/1w7OgIMMRcE/hqdefault.jpg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _loadHomeSections();
  }

  Future<List<HomeSection>> _loadHomeSections() async {
    try {
      return await ytmusic.getHomeSections();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF8B5CF6),
                      Color(0xFF6D28D9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'FEATURED MIX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Midnight Soundscapes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Explora las mejores selecciones musicales del día.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        audioController.playQueue(_quickPicks, initialIndex: 0);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF6D28D9)),
                      label: const Text(
                        'Escuchar Ahora',
                        style: TextStyle(
                          color: Color(0xFF6D28D9),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Quick Picks Horizontal Scroll Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Selección Rápida',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _quickPicks.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final song = _quickPicks[index];
                    return GestureDetector(
                      onTap: () {
                        audioController.playQueue(_quickPicks, initialIndex: index);
                      },
                      child: SizedBox(
                        width: 130,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    song.thumbnailUrl!,
                                    width: 130,
                                    height: 130,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 130,
                                      height: 130,
                                      color: Colors.deepPurple.shade800,
                                      child: const Icon(Icons.music_note, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 6,
                                  bottom: 6,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFFA855F7),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Curated Playlists Preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Playlists Recomendadas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Switch tab or navigate
                      },
                      child: const Text(
                        'Ver todas',
                        style: TextStyle(color: Color(0xFFA855F7)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: samplePlaylists.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, idx) {
                    final playlist = samplePlaylists[idx];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaylistDetailPage(playlist: playlist),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                playlist.coverUrl,
                                width: 140,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              playlist.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${playlist.trackCount} canciones',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Dynamic Home Sections from YouTube Music
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Text(
                  'Para Ti (YouTube Music)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FutureBuilder<List<HomeSection>>(
                future: _sectionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA855F7)),
                        ),
                      ),
                    );
                  }
                  final sections = snapshot.data ?? [];
                  if (sections.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'No hay secciones dinámicas disponibles en este momento.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    );
                  }

                  return Column(
                    children: sections.take(3).map((sec) {
                      return ExpansionTile(
                        iconColor: const Color(0xFFA855F7),
                        collapsedIconColor: Colors.white60,
                        title: Text(
                          sec.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: sec.contents.take(4).map((item) {
                          final name = item is SongDetailed
                              ? item.name
                              : (item is SongFull
                                  ? item.name
                                  : (item is AlbumDetailed ? item.name : 'Música'));
                          final artistName = item is SongDetailed
                              ? item.artist.name
                              : (item is SongFull
                                  ? item.artist.name
                                  : (item is AlbumDetailed ? item.artist.name : ''));

                          return ListTile(
                            leading: const Icon(Icons.music_note, color: Color(0xFFA855F7)),
                            title: Text(name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(artistName, style: const TextStyle(color: Colors.white54)),
                            onTap: () {
                              if (item is SongDetailed) {
                                audioController.playSong(
                                  item.videoId,
                                  title: item.name,
                                  artist: item.artist.name,
                                  thumbnailUrl: item.thumbnails.isNotEmpty
                                      ? item.thumbnails.first.url
                                      : null,
                                );
                              }
                            },
                          );
                        }).toList(),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
