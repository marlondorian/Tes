import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final videoId = 'ljUtuoFt-8c';

  final manifest = await yt.videos.streamsClient.getManifest(videoId);
  
  print('=== MUXED STREAMS ===');
  for (var s in manifest.muxed) {
    print('Container: ${s.container.name}, Bitrate: ${s.bitrate.kiloBitsPerSecond} kbps, Res: ${s.videoQuality}');
  }

  print('\n=== AUDIO-ONLY STREAMS ===');
  for (var s in manifest.audioOnly) {
    print('Codec: ${s.audioCodec}, Bitrate: ${s.bitrate.kiloBitsPerSecond} kbps, Container: ${s.container.name}');
  }

  final highestAudio = manifest.audioOnly.withHighestBitrate();
  print('\nHighest Audio-Only Stream URL: ${highestAudio.url}');

  yt.close();
}
