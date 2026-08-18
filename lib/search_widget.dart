import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:dart_ytmusic_api/types.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';

final ytmusic = YTMusic();
final yt = YoutubeExplode();
final audioPlayer = AudioPlayer();

Future<void> playSong(String videoId) async {
  try {
    final manifest = await yt.videos.streamsClient.getManifest(videoId);

    final mp4Streams = manifest.muxed.withHighestBitrate();


    

    final selectedStream = mp4Streams;
    final streamUrl = selectedStream.url.toString();

    debugPrint('Reproduciendo audio. container=${selectedStream.container.name} bitrate=${selectedStream.bitrate.kiloBitsPerSecond} url=$streamUrl');

    await audioPlayer.stop();
    await audioPlayer.setUrl( streamUrl
  );
    await audioPlayer.play();
  } catch (e, st) {
    debugPrint('Error reproducir audio: $e');
    debugPrint('$st');
  }
}

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
  Duration _position = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _dragPosition = Duration.zero;
  bool _isDragging = false;
  PlayerState _playerState = PlayerState(false, ProcessingState.idle);

  @override
  void initState() {
    super.initState();
    audioPlayer.positionStream.listen((position) {
      if (!_isDragging) {
        setState(() {
          _position = position;
        });
      }
    });
    audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
      setState(() {
        _bufferedPosition = bufferedPosition;
      });
    });
    audioPlayer.durationStream.listen((duration) {
      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });
    audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _playerState = state;
      });
    });
  }

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

  String get _playerStatus {
    final state = _playerState.processingState;
    if (_playerState.playing && state == ProcessingState.ready) {
      return 'Reproduciendo';
    }
    if (state == ProcessingState.buffering) {
      return 'Buffering...';
    }
    if (state == ProcessingState.loading) {
      return 'Cargando...';
    }
    if (state == ProcessingState.completed) {
      return 'Finalizado';
    }
    return 'Detenido';
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Estado: $_playerStatus'),
                const SizedBox(height: 8),
                Text('Posición: ${_formatDuration(_position)} / ${_formatDuration(_duration)}'),
                const SizedBox(height: 4),
                Slider(
                  min: 0.0,
                  max: _duration.inMilliseconds.toDouble().clamp(0.0, double.infinity),
                  value: _isDragging
                      ? _dragPosition.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble())
                      : _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble()),
                  onChangeStart: (_) {
                    setState(() {
                      _isDragging = true;
                      _dragPosition = _position;
                    });
                  },
                  onChanged: (value) {
                    setState(() {
                      _dragPosition = Duration(milliseconds: value.toInt());
                    });
                  },
                  onChangeEnd: (value) {
                    final newPosition = Duration(milliseconds: value.toInt());
                    audioPlayer.seek(newPosition);
                    setState(() {
                      _isDragging = false;
                      _position = newPosition;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text('Buffer: ${_formatDuration(_bufferedPosition)}'),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _duration.inMilliseconds == 0
                      ? null
                      : math.min(1.0, _bufferedPosition.inMilliseconds / _duration.inMilliseconds),
                  color: Colors.grey.shade400,
                  backgroundColor: Colors.grey.shade200,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final song = _results[index];
                return ListTile(
                  title: Text(song.name),
                  subtitle: Text(song.artist.name),
                  trailing: Text(song.album?.name ?? ''),
                  onTap: () {
                    playSong(song.videoId);
                    print('Reproduciendo canción: ${song.name} de ${song.artist.name} id=${song.videoId}');
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
