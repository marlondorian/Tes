class SongItem {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final Duration? duration;
  final String? thumbnailUrl;

  const SongItem({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': duration?.inMilliseconds,
        'thumbnailUrl': thumbnailUrl,
      };

  factory SongItem.fromJson(Map<String, dynamic> json) => SongItem(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        album: json['album'] as String?,
        duration: json['durationMs'] != null
            ? Duration(milliseconds: json['durationMs'] as int)
            : null,
        thumbnailUrl: json['thumbnailUrl'] as String?,
      );
}

class PlaylistModel {
  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final String category;
  final List<SongItem> songs;

  const PlaylistModel({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.category,
    required this.songs,
  });

  int get trackCount => songs.length;

  Duration get totalDuration {
    return songs.fold(
      Duration.zero,
      (total, song) => total + (song.duration ?? const Duration(minutes: 3)),
    );
  }
}
