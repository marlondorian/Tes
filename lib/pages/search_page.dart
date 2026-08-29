import 'package:flutter/material.dart';
import 'package:dart_ytmusic_api/types.dart';
import 'package:macos_native_widgets/gtk/gtk_scaffold.dart';
import 'package:macos_native_widgets/gtk/native_appbar.dart';
import '../audio/audio_controller.dart';
import '../models/music_models.dart';
import 'search_widget.dart'; // ytmusic singleton
import 'artist_detail_page.dart';
import 'album_detail_page.dart';

class SearchMusicPage extends StatefulWidget {
  const SearchMusicPage({super.key});

  @override
  State<SearchMusicPage> createState() => _SearchMusicPageState();
}

class _SearchMusicPageState extends State<SearchMusicPage> {
  final TextEditingController _queryController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<SearchResult> _results = [];
  String _selectedFilter = 'Canciones';

  final List<String> _filters = [
    'Canciones',
    'Artistas',
    'Álbumes',
    'Playlists',
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
    });

    try {
      List<SearchResult> results = [];
      switch (_selectedFilter) {
        case 'Artistas':
          results = await ytmusic.searchArtists(query);
          break;
        case 'Álbumes':
          results = await ytmusic.searchAlbums(query);
          break;
        case 'Playlists':
          results = await ytmusic.searchPlaylists(query);
          break;
        case 'Canciones':
        default:
          results = await ytmusic.searchSongs(query);
          break;
      }
      setState(() {
        _results = results;
      });
    } catch (e) {
      try {
        setState(() {
          _error = 'Error en la búsqueda: $e';
        });
      } catch (e) {}
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: NativeAppBar(
        title: GtkHeaderSearchBar(
          id: 'search_bar_music',
          value: _queryController.text,
          onChanged: (value) {
            _queryController.text = value;
            _performSearch();
          },
          width: 300,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buscar Música',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Search Input Field
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                child: TextField(
                  controller: _queryController,
                  style: TextStyle(color: colorScheme.onSurface),
                  onSubmitted: (_) => _performSearch(),
                  decoration: InputDecoration(
                    hintText: '¿Qué quieres escuchar hoy?',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colorScheme.primary,
                    ),
                    suffixIcon: _queryController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.54,
                              ),
                            ),
                            onPressed: () {
                              _queryController.clear();
                              setState(() {
                                _results = [];
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Category Filter Tags
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final filter = _filters[idx];
                    final isSelected = filter == _selectedFilter;
                    return ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      selectedColor: colorScheme.primary,
                      backgroundColor: colorScheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                          if (_queryController.text.trim().isNotEmpty) {
                            _performSearch();
                          }
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Search Status / Loader / Error
              if (_isLoading)
                Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                )
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                )
              else if (_results.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.manage_search_rounded,
                          size: 72,
                          color: colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Busca tus canciones, artistas o álbumes favoritos',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: _results.length,
                    separatorBuilder: (context, index) => Divider(
                      color: colorScheme.onSurface.withValues(alpha: 0.12),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = _results[index];

                      if (item is SongDetailed) {
                        final songItem = SongItem(
                          id: item.videoId,
                          title: item.name,
                          artist: item.artist.name,
                          album: item.album?.name,
                          thumbnailUrl: item.thumbnails.isNotEmpty
                              ? item.thumbnails.last.url
                              : null,
                        );

                        return ListenableBuilder(
                          listenable: audioController,
                          builder: (context, _) {
                            final isCurrentPlaying =
                                audioController.currentVideoId == item.videoId;

                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item.thumbnails.isNotEmpty
                                    ? Image.network(
                                        item.thumbnails.last.url,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  color: colorScheme.primary
                                                      .withValues(alpha: 0.2),
                                                  child: Icon(
                                                    Icons.music_note,
                                                    color:
                                                        colorScheme.onSurface,
                                                  ),
                                                ),
                                      )
                                    : Container(
                                        width: 48,
                                        height: 48,
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        child: Icon(
                                          Icons.music_note,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                              ),
                              title: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrentPlaying
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                  fontWeight: isCurrentPlaying
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                '${item.artist.name} ${item.album != null ? "• ${item.album!.name}" : ""}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  isCurrentPlaying && audioController.isPlaying
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_fill_rounded,
                                  color: colorScheme.primary,
                                  size: 36,
                                ),
                                onPressed: () {
                                  if (isCurrentPlaying) {
                                    audioController.togglePlayPause();
                                  } else {
                                    final songsOnly = _results
                                        .whereType<SongDetailed>();
                                    final songQueue = songsOnly
                                        .map(
                                          (s) => SongItem(
                                            id: s.videoId,
                                            title: s.name,
                                            artist: s.artist.name,
                                            album: s.album?.name,
                                            thumbnailUrl:
                                                s.thumbnails.isNotEmpty
                                                ? s.thumbnails.last.url
                                                : null,
                                          ),
                                        )
                                        .toList();
                                    final currentSongIdx = songsOnly
                                        .toList()
                                        .indexOf(item);
                                    audioController.playQueue(
                                      songQueue,
                                      initialIndex: currentSongIdx >= 0
                                          ? currentSongIdx
                                          : 0,
                                    );
                                  }
                                },
                              ),
                              onTap: () {
                                audioController.playSongItem(songItem);
                              },
                            );
                          },
                        );
                      }

                      if (item is ArtistDetailed) {
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: item.thumbnails.isNotEmpty
                                ? Image.network(
                                    item.thumbnails.last.url,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              width: 48,
                                              height: 48,
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.2),
                                              child: Icon(
                                                Icons.person,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                          ),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Artista',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArtistDetailPage(artist: item),
                              ),
                            );
                          },
                        );
                      }

                      if (item is AlbumDetailed) {
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item.thumbnails.isNotEmpty
                                ? Image.network(
                                    item.thumbnails.last.url,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              width: 48,
                                              height: 48,
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.2),
                                              child: Icon(
                                                Icons.album,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    child: Icon(
                                      Icons.album,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                          ),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Álbum • ${item.artist.name}${item.year != null ? " (${item.year})" : ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AlbumDetailPage(album: item),
                              ),
                            );
                          },
                        );
                      }

                      if (item is PlaylistDetailed) {
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item.thumbnails.isNotEmpty
                                ? Image.network(
                                    item.thumbnails.last.url,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              width: 48,
                                              height: 48,
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.2),
                                              child: Icon(
                                                Icons.playlist_play,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    child: Icon(
                                      Icons.playlist_play,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                          ),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Playlist • ${item.artist.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            _queryController.text = item.name;
                            setState(() {
                              _selectedFilter = 'Canciones';
                            });
                            _performSearch();
                          },
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
