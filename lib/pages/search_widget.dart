import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:dart_ytmusic_api/types.dart';
import '../audio/audio_controller.dart';
import 'artist_detail_page.dart';
import 'album_detail_page.dart';

final ytmusic = YTMusic();

class SongSearchWidget extends StatefulWidget {
  const SongSearchWidget({super.key});

  @override
  State<SongSearchWidget> createState() => _SongSearchWidgetState();
}

class _SongSearchWidgetState extends State<SongSearchWidget> {
  final TextEditingController _queryController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<SearchResult> _results = [];
  Duration _dragPosition = Duration.zero;
  bool _isDragging = false;
  String _selectedFilter = 'Canciones';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _searchSongs() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _error = 'Escribe algo para buscar';
        _results = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
    });

    try {
      List<SearchResult> results = [];
      switch (_selectedFilter) {
        case 'Artistas':
          results = await ytmusic.searchArtists(query);
          break;
        case 'Álbumes':
          results = await ytmusic.searchAlbums(query);
          break;
        case 'Playlists':
          results = await ytmusic.searchPlaylists(query);
          break;
        case 'Canciones':
        default:
          results = await ytmusic.searchSongs(query);
          break;
      }
      setState(() {
        _results = results;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al buscar: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _queryController,
          decoration: const InputDecoration(
            labelText: 'Buscar canciones',
            hintText: 'Escribe el nombre de una canción o artista',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _searchSongs(),
        ),
        const SizedBox(height: 12),

        ElevatedButton(
          onPressed: _isLoading ? null : _searchSongs,
          child: const Text('Buscar'),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red))
        else ...[
          ListenableBuilder(
            listenable: audioController,
            builder: (context, _) {
              final position = audioController.position;
              final duration = audioController.duration;
              final bufferedPosition = audioController.bufferedPosition;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Estado: ${audioController.statusText}'),
                    if (audioController.currentTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Canción: ${audioController.currentTitle}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Posición: ${_formatDuration(position)} / ${_formatDuration(duration)}',
                    ),
                    const SizedBox(height: 4),
                    Slider(
                      min: 0.0,
                      max: duration.inMilliseconds.toDouble().clamp(
                        0.0,
                        double.infinity,
                      ),
                      value: _isDragging
                          ? _dragPosition.inMilliseconds.toDouble().clamp(
                              0.0,
                              duration.inMilliseconds.toDouble(),
                            )
                          : position.inMilliseconds.toDouble().clamp(
                              0.0,
                              duration.inMilliseconds.toDouble(),
                            ),
                      onChangeStart: (_) {
                        setState(() {
                          _isDragging = true;
                          _dragPosition = position;
                        });
                      },
                      onChanged: (value) {
                        setState(() {
                          _dragPosition = Duration(milliseconds: value.toInt());
                        });
                      },
                      onChangeEnd: (value) {
                        final newPosition = Duration(
                          milliseconds: value.toInt(),
                        );
                        audioController.seek(newPosition);
                        setState(() {
                          _isDragging = false;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('Buffer: ${_formatDuration(bufferedPosition)}'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: duration.inMilliseconds == 0
                          ? null
                          : math.min(
                              1.0,
                              bufferedPosition.inMilliseconds /
                                  duration.inMilliseconds,
                            ),
                      color: Colors.grey.shade400,
                      backgroundColor: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _results[index];

                if (item is SongDetailed) {
                  return ListTile(
                    leading: item.thumbnails.isNotEmpty
                        ? Image.network(
                            item.thumbnails.last.url,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox(width: 50, height: 50),
                    title: Text(item.name),
                    subtitle: Text(item.artist.name),
                    trailing: Text(item.album?.name ?? ''),
                    onTap: () {
                      audioController.playSong(
                        item.videoId,
                        title: item.name,
                        artist: item.artist.name,
                        album: item.album?.name,
                        thumbnailUrl: item.thumbnails.isNotEmpty
                            ? item.thumbnails.last.url
                            : null,
                      );
                    },
                  );
                }

                if (item is ArtistDetailed) {
                  return ListTile(
                    leading: item.thumbnails.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Image.network(
                              item.thumbnails.last.url,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const CircleAvatar(
                            radius: 25,
                            child: Icon(Icons.person),
                          ),
                    title: Text(item.name),
                    subtitle: const Text('Artista'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArtistDetailPage(artist: item),
                        ),
                      );
                    },
                  );
                }

                if (item is AlbumDetailed) {
                  return ListTile(
                    leading: item.thumbnails.isNotEmpty
                        ? Image.network(
                            item.thumbnails.last.url,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox(width: 50, height: 50),
                    title: Text(item.name),
                    subtitle: Text('Álbum • ${item.artist.name}'),
                    trailing: Text(item.year != null ? '${item.year}' : ''),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlbumDetailPage(album: item),
                        ),
                      );
                    },
                  );
                }

                if (item is PlaylistDetailed) {
                  return ListTile(
                    leading: item.thumbnails.isNotEmpty
                        ? Image.network(
                            item.thumbnails.last.url,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox(width: 50, height: 50),
                    title: Text(item.name),
                    subtitle: Text('Playlist • ${item.artist.name}'),
                    onTap: () {
                      _queryController.text = item.name;
                      _selectedFilter = 'Canciones';
                      _searchSongs();
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ],
    );
  }
}
