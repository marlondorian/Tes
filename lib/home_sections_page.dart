import 'package:flutter/material.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import 'search_widget.dart';

class HomeSectionsPage extends StatefulWidget {
  const HomeSectionsPage({super.key});

  @override
  State<HomeSectionsPage> createState() => _HomeSectionsPageState();
}

class _HomeSectionsPageState extends State<HomeSectionsPage> {
  late final Future<List<HomeSection>> _sectionsFuture;

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _loadHomeSections();
  }

  Future<List<HomeSection>> _loadHomeSections() async {
    return await ytmusic.getHomeSections();
  }

  String _describeSectionItem(dynamic item) {
    if (item is SongDetailed) {
      return item.name;
    }
    if (item is SongFull) {
      return item.name;
    }
    if (item is PlaylistDetailed) {
      return item.name;
    }
    if (item is PlaylistFull) {
      return item.name;
    }
    if (item is AlbumDetailed) {
      return item.name;
    }
    if (item is AlbumFull) {
      return item.name;
    }
    if (item is VideoDetailed) {
      return item.name;
    }
    if (item is VideoFull) {
      return item.name;
    }
    if (item is ArtistDetailed) {
      return item.name;
    }
    if (item is ArtistFull) {
      return item.name;
    }
    if (item is UpNextsDetails) {
      return item.title;
    }
    return '${item.runtimeType}';
  }

  String _describeSectionSubtitle(dynamic item) {
    if (item is SongDetailed) {
      return item.artist.name;
    }
    if (item is SongFull) {
      return item.artist.name;
    }
    if (item is PlaylistDetailed) {
      return 'Playlist • ${item.artist.name}';
    }
    if (item is PlaylistFull) {
      return 'Playlist • ${item.artist.name}';
    }
    if (item is AlbumDetailed) {
      return 'Álbum • ${item.artist.name}';
    }
    if (item is AlbumFull) {
      return 'Álbum • ${item.artist.name}';
    }
    if (item is VideoDetailed) {
      return 'Video • ${item.artist.name}';
    }
    if (item is VideoFull) {
      return 'Video • ${item.artist.name}';
    }
    if (item is ArtistDetailed) {
      return 'Artista';
    }
    if (item is ArtistFull) {
      return 'Artista';
    }
    if (item is UpNextsDetails) {
      return 'Up next • ${item.artists.name}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secciones de YouTube Music'),
      ),
      body: FutureBuilder<List<HomeSection>>(
        future: _sectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar secciones: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final sections = snapshot.data ?? [];
          if (sections.isEmpty) {
            return const Center(
              child: Text('No se encontraron secciones.'),
            );
          }

          return ListView.separated(
            itemCount: sections.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final section = sections[index];
              return ExpansionTile(
                title: Text(section.title),
                subtitle: Text('${section.contents.length} elementos'),
                children: section.contents
                    .take(5)
                    .map<Widget>((item) => ListTile(
                          title: Text(_describeSectionItem(item)),
                          subtitle: Text(_describeSectionSubtitle(item)),
                        ))
                    .toList(),
              );
            },
          );
        },
      ),
    );
  }
}
