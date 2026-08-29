import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:dart_ytmusic_api/parsers/album_parser.dart';

void main() async {
  final yt = YTMusic();
  await yt.initialize(cookies: '');

  final albums = await yt.searchAlbums('Nevermind');
  final album = albums.first;

  final rawData = await yt.constructRequest('browse', body: {'browseId': album.albumId});
  
  final parsedAlbumDirect = AlbumParser.parse(rawData, album.albumId);
  print('=== Direct AlbumParser.parse songs order ===');
  for (var i = 0; i < parsedAlbumDirect.songs.length; i++) {
    print('${i + 1}. ${parsedAlbumDirect.songs[i].name}');
  }

  final fullAlbumFromPackage = await yt.getAlbum(album.albumId);
  print('\n=== Package getAlbum songs order (after getArtistSongs filtering) ===');
  for (var i = 0; i < fullAlbumFromPackage.songs.length; i++) {
    print('${i + 1}. ${fullAlbumFromPackage.songs[i].name}');
  }
}
