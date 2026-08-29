import 'package:flutter/material.dart';
import 'package:dart_ytmusic_api/types.dart';
import 'package:macos_native_widgets/gtk/gtk_scaffold.dart';
import 'package:macos_native_widgets/gtk/native_appbar.dart';
import '../audio/audio_controller.dart';
import '../models/music_models.dart';
import 'album_detail_page.dart';
import 'search_widget.dart';

class ArtistDetailPage extends StatefulWidget {
  final ArtistDetailed artist;

  const ArtistDetailPage({super.key, required this.artist});

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  ArtistFull? _artistFull;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArtistDetails();
  }

  Future<void> _loadArtistDetails() async {
    try {
      final details = await ytmusic.getArtist(widget.artist.artistId);
      setState(() {
        _artistFull = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudieron cargar los detalles del artista: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final avatarUrl = widget.artist.thumbnails.isNotEmpty
        ? widget.artist.thumbnails.last.url
        : '';
    final artistName = _artistFull?.name ?? widget.artist.name;

    final topSongs = _artistFull?.topSongs ?? [];
    final topAlbums = _artistFull?.topAlbums ?? [];

    final queueItems = topSongs
        .map(
          (s) => SongItem(
            id: s.videoId,
            title: s.name,
            artist: artistName,
            album: s.album?.name,
            thumbnailUrl: s.thumbnails.isNotEmpty
                ? s.thumbnails.last.url
                : avatarUrl,
          ),
        )
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: NativeAppBar(
        leading: GtkHeaderAction(
          id: "artist-back",
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context); // Solo regresa si hay una pantalla previa
            }
          },
          iconName: "go-previous-symbolic",
        ),
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Header Collapsible for Artist
          SliverAppBar(
            leading: const SizedBox(),
            expandedHeight: 320.0,
            pinned: true,
            backgroundColor: colorScheme.surface,
            iconTheme: IconThemeData(color: colorScheme.onSurface),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.6),
                          colorScheme.surface,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      // Artist Avatar Image
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: avatarUrl.isNotEmpty
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        child: Icon(
                                          Icons.person_rounded,
                                          color: colorScheme.onSurface,
                                          size: 60,
                                        ),
                                      ),
                                )
                              : Container(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: colorScheme.onSurface,
                                    size: 60,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        artistName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Artista',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Play Controls
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: queueItems.isNotEmpty
                          ? () {
                              audioController.playQueue(
                                queueItems,
                                initialIndex: 0,
                              );
                            }
                          : null,
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        color: colorScheme.onPrimary,
                      ),
                      label: Text(
                        'Reproducir Éxitos',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: queueItems.isNotEmpty
                        ? () {
                            final shuffled = List<SongItem>.from(queueItems)
                              ..shuffle();
                            audioController.playQueue(
                              shuffled,
                              initialIndex: 0,
                            );
                          }
                        : null,
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: colorScheme.onSurface,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.onSurface.withValues(
                        alpha: 0.1,
                      ),
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading & Error States
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              ),
            )
          else if (_error != null && topSongs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            )
          else ...[
            // Section: Top Songs
            if (topSongs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'Canciones populares',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = topSongs[index];

                  return ListenableBuilder(
                    listenable: audioController,
                    builder: (context, _) {
                      final isCurrentPlaying =
                          audioController.currentVideoId == song.videoId;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentPlaying
                              ? colorScheme.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: song.thumbnails.isNotEmpty
                                ? Image.network(
                                    song.thumbnails.last.url,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 44,
                                    height: 44,
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
                            song.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrentPlaying
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                              fontWeight: isCurrentPlaying
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            song.album?.name ?? artistName,
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
                            audioController.playQueue(
                              queueItems,
                              initialIndex: index,
                            );
                          },
                        ),
                      );
                    },
                  );
                }, childCount: topSongs.length),
              ),
            ],

            // Section: Albums & Discography
            if (topAlbums.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Text(
                    'Álbumes y sencillos',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 180,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: topAlbums.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 14),
                    itemBuilder: (context, idx) {
                      final album = topAlbums[idx];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailPage(album: album),
                            ),
                          );
                        },
                        child: SizedBox(
                          width: 130,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: album.thumbnails.isNotEmpty
                                    ? Image.network(
                                        album.thumbnails.last.url,
                                        width: 130,
                                        height: 130,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 130,
                                        height: 130,
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        child: Icon(
                                          Icons.album,
                                          color: colorScheme.onSurface,
                                          size: 40,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                album.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (album.year != null)
                                Text(
                                  '${album.year}',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],

          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }
}
