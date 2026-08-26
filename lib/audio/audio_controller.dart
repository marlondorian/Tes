import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/music_models.dart';
import 'audio_handler.dart';
import 'mpris.dart';

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

  AudioController._internal();

  MyAudioHandler? _audioHandler;
  MyAudioHandler? get audioHandler => _audioHandler;

  final YoutubeExplode _yt = YoutubeExplode();

  AudioPlayer? get player => _audioHandler?.player;

  Duration _position = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _playerState = PlayerState(false, ProcessingState.idle);

  String? _currentVideoId;
  String? _currentTitle;
  String? _currentArtist;
  String? _currentAlbum;
  String? _currentThumbnailUrl;
  bool _isLoadingStream = false;

  // Queue & Playback Settings
  List<SongItem> _queue = [];
  int _currentIndex = -1;
  bool _isShuffle = false;
  bool _isLoop = false;
  double _volume = 1.0;

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
  String? get currentAlbum => _currentAlbum;

  List<SongItem> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get isShuffle => _isShuffle;
  bool get isLoop => _isLoop;
  double get volume => _volume;

  SongItem? get currentSong => (_currentIndex >= 0 && _currentIndex < _queue.length)
      ? _queue[_currentIndex]
      : (_currentVideoId != null
          ? SongItem(
              id: _currentVideoId!,
              title: _currentTitle ?? 'Sin título',
              artist: _currentArtist ?? 'Desconocido',
              album: _currentAlbum,
              thumbnailUrl: _currentThumbnailUrl,
            )
          : null);

  Future<MyAudioHandler> ensureAudioHandler() async {
    if (_audioHandler != null) return _audioHandler!;
    // Registrar nuestra implementación MPRIS personalizada (reemplaza audio_service_mpris)
    if (Platform.isLinux) {
      CustomAudioServiceMpris.registerWith();
    }
    _audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.marlon.tes.channel.audio',
        androidNotificationChannelName: 'Midnight Player',
        androidNotificationOngoing: true,
      ),
    );
    _initStreams();
    return _audioHandler!;
  }

  void _initStreams() {
    final player = _audioHandler?.player;
    if (player == null) return;

    player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    player.bufferedPositionStream.listen((buf) {
      _bufferedPosition = buf;
      notifyListeners();
    });
    player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
    player.playerStateStream.listen((state) {
      _playerState = state;
      notifyListeners();
      if (state.processingState == ProcessingState.completed) {
        if (_isLoop) {
          seek(Duration.zero);
          resume();
        } else {
          playNext();
        }
      }
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

  Future<void> playSongItem(SongItem song) async {
    if (!_queue.contains(song)) {
      _queue = [song];
      _currentIndex = 0;
    } else {
      _currentIndex = _queue.indexOf(song);
    }
    await playSong(
      song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      thumbnailUrl: song.thumbnailUrl,
    );
  }

  Future<void> playQueue(List<SongItem> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    _queue = List.from(songs);
    if (_isShuffle) {
      _queue.shuffle();
      _currentIndex = 0;
    } else {
      _currentIndex = initialIndex.clamp(0, songs.length - 1);
    }
    final target = _queue[_currentIndex];
    await playSong(
      target.id,
      title: target.title,
      artist: target.artist,
      album: target.album,
      thumbnailUrl: target.thumbnailUrl,
    );
  }

  Future<void> playNext() async {
    if (_queue.isEmpty) return;
    if (_currentIndex + 1 < _queue.length) {
      _currentIndex++;
      final nextSong = _queue[_currentIndex];
      await playSong(
        nextSong.id,
        title: nextSong.title,
        artist: nextSong.artist,
        album: nextSong.album,
        thumbnailUrl: nextSong.thumbnailUrl,
      );
    } else if (_isLoop && _queue.isNotEmpty) {
      _currentIndex = 0;
      final nextSong = _queue[0];
      await playSong(
        nextSong.id,
        title: nextSong.title,
        artist: nextSong.artist,
        album: nextSong.album,
        thumbnailUrl: nextSong.thumbnailUrl,
      );
    }
  }

  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;
    if (_position.inSeconds > 4) {
      await seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      final prevSong = _queue[_currentIndex];
      await playSong(
        prevSong.id,
        title: prevSong.title,
        artist: prevSong.artist,
        album: prevSong.album,
        thumbnailUrl: prevSong.thumbnailUrl,
      );
    } else {
      await seek(Duration.zero);
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleLoop() {
    _isLoop = !_isLoop;
    notifyListeners();
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    await _audioHandler?.player.setVolume(_volume);
    notifyListeners();
  }

  Future<void> playSong(
    String videoId, {
    String? title,
    String? artist,
    String? album,
    String? thumbnailUrl,
  }) async {
    _currentVideoId = videoId;
    _currentTitle = title;
    _currentArtist = artist;
    _currentAlbum = album;
    _currentThumbnailUrl = thumbnailUrl;
    _isLoadingStream = true;
    notifyListeners();

    try {
      final handler = await ensureAudioHandler();

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

      final item = MediaItem(
        id: videoId,
        album: _currentAlbum,
        title: _currentTitle!,
        artist: _currentArtist,
        artUri: _currentThumbnailUrl != null
            ? Uri.parse(_currentThumbnailUrl!)
            : null,
      );

      await handler.setAudioSource(AudioSource.uri(Uri.parse(streamUrl)), item);
      await handler.play();
      notifyListeners();
    } catch (e) {
      // ignore
    } finally {
      _isLoadingStream = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _audioHandler?.pause();
  }

  Future<void> resume() async {
    if (_audioHandler != null) {
      await _audioHandler!.play();
    }
  }

  Future<void> togglePlayPause() async {
    if (_audioHandler == null) return;
    if (isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration newPosition) async {
    await _audioHandler?.seek(newPosition);
  }

  Future<void> stop() async {
    await _audioHandler?.stop();
  }

  @override
  void dispose() {
    _audioHandler?.player.dispose();
    _yt.close();
    super.dispose();
  }
}

final audioController = AudioController();
