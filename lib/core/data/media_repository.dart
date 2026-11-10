import 'dart:typed_data';

import '../domain/media_models.dart';

abstract interface class MediaRepository {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<bool> ensureMediaManagement();
  Future<List<MediaItem>> query({
    required MediaSource source,
    int offset = 0,
    int limit = 24,
    bool trashed = false,
  });
  Future<List<MediaSource>> discoverSources();
  Future<Uint8List?> loadThumbnail(MediaItem item, {int size = 640});
  Future<void> trash(MediaItem item);
  Future<void> restore(MediaItem item);
  Future<void> permanentlyDelete(List<MediaItem> items);

  Future<void> permanentlyDeleteAutomatically(List<MediaItem> items) =>
      permanentlyDelete(items);
}
