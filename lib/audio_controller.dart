import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class AudioMetadata {
  final String id;
  final String title;
  final String? artist;
  final Uri? artUri;

  const AudioMetadata({
    required this.id,
    required this.title,
    this.artist,
    this.artUri,
  });
}

class AudioController extends ChangeNotifier {
  static final AudioController instance = AudioController._internal();
  factory AudioController() => instance;

  AudioController._internal() {
    _initStreams();
  }

  final AudioPlayer _player = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();

  AudioPlayer get player => _player;

  Duration _position = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _playerState = PlayerState(false, ProcessingState.idle);

  String? _currentVideoId;
  String? _currentTitle;
  String? _currentArtist;
  String? _currentThumbnailUrl;
  bool _isLoadingStream = false;

  Duration get position => _position;
  Duration get bufferedPosition => _bufferedPosition;
  Duration get duration => _duration;
  PlayerState get playerState => _playerState;
  bool get isPlaying => _playerState.playing;
  bool get isLoadingStream => _isLoadingStream;

  String? get currentVideoId => _currentVideoId;
  String? get currentTitle => _currentTitle;
  String? get currentArtist => _currentArtist;
  String? get currentThumbnailUrl => _currentThumbnailUrl;

  void _initStreams() {
    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _player.bufferedPositionStream.listen((buf) {
      _bufferedPosition = buf;
      notifyListeners();
    });
    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
    _player.playerStateStream.listen((state) {
      _playerState = state;
      notifyListeners();
    });
  }

  String get statusText {
    if (_isLoadingStream) return 'Cargando stream...';
    final state = _playerState.processingState;
    if (_playerState.playing && state == ProcessingState.ready) {
      return 'Reproduciendo';
    }
    if (state == ProcessingState.buffering) return 'Buffering...';
    if (state == ProcessingState.loading) return 'Cargando...';
    if (state == ProcessingState.completed) return 'Finalizado';
    return 'Detenido';
  }

  Future<void> playSong(
    String videoId, {
    String? title,
    String? artist,
    String? thumbnailUrl,
  }) async {
    _currentVideoId = videoId;
    _currentTitle = title;
    _currentArtist = artist;
    _currentThumbnailUrl = thumbnailUrl;
    _isLoadingStream = true;
    notifyListeners();

    try {
      if (_currentTitle == null) {
        final video = await _yt.videos.get(videoId);
        _currentTitle = video.title;
        _currentArtist ??= video.author;
        _currentThumbnailUrl ??= video.thumbnails.highResUrl;
        notifyListeners();
      }

      if (_currentTitle != null && (Platform.isLinux || Platform.isWindows)) {
        JustAudioMediaKit.title = "${_currentTitle!} - ${_currentArtist!}";
      }

      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final selectedStream = manifest.muxed.withHighestBitrate();
      final streamUrl = selectedStream.url.toString();

      debugPrint(
        'Reproduciendo audio. container=${selectedStream.container.name} bitrate=${selectedStream.bitrate.kiloBitsPerSecond} url=$streamUrl',
      );

      await _player.stop();
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamUrl),
          tag: MediaItem(
            id: videoId,
            title: _currentTitle!,
            artist: _currentArtist,
            artUri: _currentThumbnailUrl != null
                ? Uri.parse(_currentThumbnailUrl!)
                : null,
          ),
        ),
      );
      await _player.play();
      notifyListeners();
    } catch (e, st) {
      debugPrint('Error reproducir audio: $e');
      debugPrint('$st');
    } finally {
      _isLoadingStream = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration newPosition) async {
    await _player.seek(newPosition);
  }

  Future<void> stop() async {
    await _player.stop();
  }

  @override
  void dispose() {
    _player.dispose();
    _yt.close();
    super.dispose();
  }
}

final audioController = AudioController();
