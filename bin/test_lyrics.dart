import 'package:dart_ytmusic_api/yt_music.dart';

void main() async {
  final yt = YTMusic();
  await yt.initialize(cookies: '');

  final searchSongs = await yt.searchSongs('Smells Like Teen Spirit');
  if (searchSongs.isNotEmpty) {
    final song = searchSongs.first;
    print('Testing song: ${song.name} (videoId: ${song.videoId})');

    try {
      final timedLyrics = await yt.getTimedLyrics(song.videoId);
      print('TimedLyrics response: $timedLyrics');
      if (timedLyrics != null) {
        print('Source: ${timedLyrics.sourceMessage}');
        print('Lines count: ${timedLyrics.timedLyricsData.length}');
        for (var line in timedLyrics.timedLyricsData.take(5)) {
          print('[${line.cueRange?.startTimeMilliseconds}ms -> ${line.cueRange?.endTimeMilliseconds}ms]: ${line.lyricLine}');
        }
      } else {
        print('TimedLyrics returned null, testing plain getLyrics...');
        final plainLyrics = await yt.getLyrics(song.videoId);
        print('Plain lyrics:');
        print(plainLyrics);
      }
    } catch (e) {
      print('Error fetching lyrics: $e');
    }
  }
}
