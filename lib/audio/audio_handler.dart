import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player = AudioPlayer();
  static const MethodChannel _nativeChannel =
      MethodChannel('com.example.macos_native_widgets/native');

  MyAudioHandler() {
    _init();
  }

  void _init() {
    // Escuchar el estado de reproducción del reproductor y emitirlo a AudioService
    player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (isPlaying) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.fastForward,
            MediaAction.rewind,
          },
          androidCompactActionIndices: const [0, 1, 3],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[processingState]!,
          playing: isPlaying,
          updatePosition: player.position,
          bufferedPosition: player.bufferedPosition,
          speed: player.speed,
        ),
      );
    });

    // Escuchar la duración total para actualizar MediaItem y habilitar la barra de Seek en MPRIS
    player.durationStream.listen((duration) {
      final currentItem = mediaItem.value;
      if (currentItem != null && duration != null && currentItem.duration != duration) {
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
    });

    // Escuchar la posición para mantener actualizado el estado del slider/MPRIS
    player.positionStream.listen((position) {
      playbackState.add(
        playbackState.value.copyWith(
          updatePosition: position,
        ),
      );
    });

    player.bufferedPositionStream.listen((bufferedPosition) {
      playbackState.add(
        playbackState.value.copyWith(
          bufferedPosition: bufferedPosition,
        ),
      );
    });
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> fastForward() =>
      player.seek(player.position + const Duration(seconds: 10));

  @override
  Future<void> rewind() =>
      player.seek(player.position - const Duration(seconds: 10));

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'raise' || name == 'click') {
      await _raiseWindow();
    }
  }

  Future<void> _raiseWindow() async {
    try {
      await _nativeChannel.invokeMethod('raiseWindow');
    } catch (_) {}
  }

  Future<void> setAudioSource(AudioSource source, MediaItem item) async {
    final duration = player.duration;
    final itemWithDuration = duration != null ? item.copyWith(duration: duration) : item;
    mediaItem.add(itemWithDuration);
    await player.stop();
    await player.setAudioSource(source);
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }
}
