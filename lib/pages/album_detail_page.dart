import 'package:flutter/material.dart';
import 'package:dart_ytmusic_api/types.dart';
import 'package:dart_ytmusic_api/parsers/album_parser.dart';
import 'package:macos_native_widgets/gtk/gtk_scaffold.dart';
import 'package:macos_native_widgets/gtk/native_appbar.dart';
import '../audio/audio_controller.dart';
import '../models/music_models.dart';
import 'search_widget.dart';

class AlbumDetailPage extends StatefulWidget {
  final AlbumDetailed album;

  const AlbumDetailPage({super.key, required this.album});

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  AlbumFull? _albumFull;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlbumDetails();
  }

  Future<void> _loadAlbumDetails() async {
    try {
      // 1. Fetch official songs from ytmusic.getAlbum (contains official YT Music song videoIds)
      final officialAlbum = await ytmusic.getAlbum(widget.album.albumId);

      // 2. Fetch raw browse data to extract the correct tracklist sequence
      final rawData = await ytmusic.constructRequest(
        'browse',
        body: {'browseId': widget.album.albumId},
      );
      final rawAlbum = AlbumParser.parse(rawData, widget.album.albumId);

      // 3. Map raw track names to preserve exact tracklist order
      final rawNamesOrder = rawAlbum.songs
          .map((s) => s.name.toLowerCase().trim())
          .toList();

      final reorderedOfficialSongs = List<SongDetailed>.from(
        officialAlbum.songs,
      );
      reorderedOfficialSongs.sort((a, b) {
        final idxA = rawNamesOrder.indexOf(a.name.toLowerCase().trim());
        final idxB = rawNamesOrder.indexOf(b.name.toLowerCase().trim());
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return 0;
      });

      setState(() {
        _albumFull = AlbumFull(
          type: officialAlbum.type,
          albumId: officialAlbum.albumId,
          playlistId: officialAlbum.playlistId,
          name: officialAlbum.name,
          artist: officialAlbum.artist,
          year: officialAlbum.year,
          thumbnails: officialAlbum.thumbnails,
          songs: reorderedOfficialSongs,
        );
        _isLoading = false;
      });
    } catch (e) {
      // Fallback: try raw parse if official fetch fails
      try {
        final rawData = await ytmusic.constructRequest(
          'browse',
          body: {'browseId': widget.album.albumId},
        );
        final details = AlbumParser.parse(rawData, widget.album.albumId);
        setState(() {
          _albumFull = details;
          _isLoading = false;
        });
        return;
      } catch (_) {}
      try {
        setState(() {
          _error = 'No se pudieron cargar los detalles del álbum: $e';
          _isLoading = false;
        });
      } catch (e) {}
    }
  }

  String _formatDuration(int? totalSeconds) {
    if (totalSeconds == null) return '';
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours h $minutes min';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final coverUrl = widget.album.thumbnails.isNotEmpty
        ? widget.album.thumbnails.last.url
        : '';
    final albumTitle = _albumFull?.name ?? widget.album.name;
    final artistName = _albumFull?.artist.name ?? widget.album.artist.name;
    final year = _albumFull?.year ?? widget.album.year;

    final songs = _albumFull?.songs ?? [];
    final totalDurationSecs = songs.fold<int>(
      0,
      (sum, item) => sum + (item.duration ?? 0),
    );

    final queueItems = songs
        .map(
          (s) => SongItem(
            id: s.videoId,
            title: s.name,
            artist: s.artist.name,
            album: albumTitle,
            thumbnailUrl: s.thumbnails.isNotEmpty
                ? s.thumbnails.last.url
                : coverUrl,
          ),
        )
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: NativeAppBar(
        leading: GtkHeaderAction(
          id: "album-back",
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
          // Header Collapsible
          SliverAppBar(
            leading: const SizedBox(),
            expandedHeight: 340.0,
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
                      // Album Cover Image
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: coverUrl.isNotEmpty
                              ? Image.network(
                                  coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        child: Icon(
                                          Icons.album_rounded,
                                          color: colorScheme.onSurface,
                                          size: 50,
                                        ),
                                      ),
                                )
                              : Container(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  child: Icon(
                                    Icons.album_rounded,
                                    color: colorScheme.onSurface,
                                    size: 50,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        albumTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Álbum • $artistName${year != null ? " • $year" : ""}',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                      if (songs.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${songs.length} canciones • ${_formatDuration(totalDurationSecs)}',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Actions Row
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
                        'Reproducir Todo',
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

          // Content States
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              ),
            )
          else if (_error != null && songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final song = songs[index];

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
                        leading: SizedBox(
                          width: 32,
                          child: Center(
                            child: isCurrentPlaying
                                ? Icon(
                                    Icons.bar_chart_rounded,
                                    color: colorScheme.primary,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
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
                          song.artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        trailing: song.duration != null
                            ? Text(
                                '${Duration(seconds: song.duration!).inMinutes}:${(Duration(seconds: song.duration!).inSeconds % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                  fontSize: 12,
                                ),
                              )
                            : null,
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
              }, childCount: songs.length),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }
}
