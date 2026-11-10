enum MediaKind { image, video }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.uri,
    required this.kind,
    required this.dateAddedSeconds,
    this.bucketId,
    this.bucketName,
    this.relativePath,
    this.displayName,
    this.durationMs,
    this.isTrashed = false,
  });

  final String id;
  final String uri;
  final MediaKind kind;
  final int dateAddedSeconds;
  final String? bucketId;
  final String? bucketName;
  final String? relativePath;
  final String? displayName;
  final int? durationMs;
  final bool isTrashed;

  bool get isVideo => kind == MediaKind.video;

  MediaItem copyWith({bool? isTrashed}) => MediaItem(
        id: id,
        uri: uri,
        kind: kind,
        dateAddedSeconds: dateAddedSeconds,
        bucketId: bucketId,
        bucketName: bucketName,
        relativePath: relativePath,
        displayName: displayName,
        durationMs: durationMs,
        isTrashed: isTrashed ?? this.isTrashed,
      );
}

enum MediaSourceKind { all, photos, videos, bucket }

class MediaSource {
  const MediaSource({
    required this.id,
    required this.label,
    required this.kind,
    this.bucketId,
  });

  final String id;
  final String label;
  final MediaSourceKind kind;
  final String? bucketId;
}

class DeletedEntry {
  const DeletedEntry({
    required this.id,
    required this.uri,
    required this.kind,
    required this.deletedAtMs,
  });

  final String id;
  final String uri;
  final MediaKind kind;
  final int deletedAtMs;

  Map<String, Object?> toJson() => {
        'id': id,
        'uri': uri,
        'kind': kind.name,
        'deletedAtMs': deletedAtMs,
      };

  factory DeletedEntry.fromJson(Map<String, dynamic> json) => DeletedEntry(
        id: json['id'] as String,
        uri: json['uri'] as String,
        kind: MediaKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => MediaKind.image,
        ),
        deletedAtMs: (json['deletedAtMs'] as num).toInt(),
      );
}
