import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:dart_ytmusic_api/types.dart';
import '../audio/audio_controller.dart';

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
  List<SongDetailed> _results = [];
  Duration _dragPosition = Duration.zero;
  bool _isDragging = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _searchSongs() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _error = 'Escribe algo para buscar canciones';
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
      final songs = await ytmusic.searchSongs(query);
      setState(() {
        _results = songs;
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
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final song = _results[index];
                return ListTile(
                  leading: song.thumbnails.isNotEmpty
                      ? Image.network(
                          song.thumbnails.first.url,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : const SizedBox(width: 50, height: 50),
                  title: Text(song.name),
                  subtitle: Text(song.artist.name),
                  trailing: Text(song.album?.name ?? ''),
                  onTap: () {
                    audioController.playSong(
                      song.videoId,
                      title: song.name,
                      artist: song.artist.name,
                      album: song.album?.name,
                      thumbnailUrl: song.thumbnails.isNotEmpty
                          ? song.thumbnails.first.url
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
