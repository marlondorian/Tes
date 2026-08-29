import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:dart_ytmusic_api/parsers/album_parser.dart';

void main() async {
  final yt = YTMusic();
  await yt.initialize(cookies: '');

  final albums = await yt.searchAlbums('Nevermind');
  final album = albums.first;

  // 1. Raw browse response order (contiene el orden correcto de canciones pero con IDs de video de YouTube)
  final rawData = await yt.constructRequest('browse', body: {'browseId': album.albumId});
  final rawAlbum = AlbumParser.parse(rawData, album.albumId);

  // 2. getAlbum response (contiene las canciones oficiales con los IDs oficiales de YT Music, pero desordenadas)
  final officialAlbum = await yt.getAlbum(album.albumId);

  print('=== RAW BROWSE ORDER (Orden correcto del tracklist) ===');
  for (var i = 0; i < rawAlbum.songs.length; i++) {
    print('${i + 1}. ${rawAlbum.songs[i].name} [id: ${rawAlbum.songs[i].videoId}]');
  }

  print('\n=== OFFICIAL GETALBUM SONGS (IDs oficiales de YT Music, desordenadas) ===');
  for (var i = 0; i < officialAlbum.songs.length; i++) {
    print('${i + 1}. ${officialAlbum.songs[i].name} [id: ${officialAlbum.songs[i].videoId}]');
  }

  // ALGORITMO DE REORDENAMIENTO:
  // Tomar las canciones oficiales (officialAlbum.songs) y ordenarlas según el índice de su nombre en rawAlbum.songs
  final rawNamesOrder = rawAlbum.songs.map((s) => s.name.toLowerCase().trim()).toList();
  
  final reorderedOfficialSongs = List.of(officialAlbum.songs);
  reorderedOfficialSongs.sort((a, b) {
    final idxA = rawNamesOrder.indexOf(a.name.toLowerCase().trim());
    final idxB = rawNamesOrder.indexOf(b.name.toLowerCase().trim());
    if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
    if (idxA != -1) return -1;
    if (idxB != -1) return 1;
    return 0;
  });

  print('\n=== REORDERED OFFICIAL SONGS (Canciones de YT Music en el orden correcto) ===');
  for (var i = 0; i < reorderedOfficialSongs.length; i++) {
    print('${i + 1}. ${reorderedOfficialSongs[i].name} [id: ${reorderedOfficialSongs[i].videoId}]');
  }
}
