import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../domain/media_models.dart';
import 'media_repository.dart';

class MediaStoreRepository implements MediaRepository {
  MediaStoreRepository({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('keeply/media_store');

  final MethodChannel _channel;

  @override
  Future<bool> hasPermission() async {
    return await _channel.invokeMethod<bool>('hasPermission') ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    return await _channel.invokeMethod<bool>('requestPermission') ?? false;
  }

  @override
  Future<bool> ensureMediaManagement() async {
    return await _channel.invokeMethod<bool>('ensureMediaManagement') ?? false;
  }

  @override
  Future<List<MediaItem>> query({
    required MediaSource source,
    int offset = 0,
    int limit = 24,
    bool trashed = false,
  }) async {
    final rows = await _channel.invokeMethod<List<dynamic>>('queryMedia', {
      'sourceKind': source.kind.name,
      'bucketId': source.bucketId,
      'offset': offset,
      'limit': limit,
      'trashed': trashed,
    });
    return (rows ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(_fromNative)
        .toList(growable: false);
  }

  @override
  Future<List<MediaSource>> discoverSources() async {
    final rows = await _channel.invokeMethod<List<dynamic>>('discoverSources');
    return (rows ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (row) => MediaSource(
            id: row['id'] as String,
            label: row['label'] as String,
            kind: MediaSourceKind.values.firstWhere(
              (value) => value.name == row['kind'],
              orElse: () => MediaSourceKind.bucket,
            ),
            bucketId: row['bucketId'] as String?,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Uint8List?> loadThumbnail(MediaItem item, {int size = 640}) async {
    final bytes = await _channel.invokeMethod<Uint8List>('thumbnail', {
      'uri': item.uri,
      'size': size,
    });
    return bytes;
  }

  @override
  Future<void> trash(MediaItem item) =>
      _channel.invokeMethod<void>('trash', {'uri': item.uri});

  @override
  Future<void> restore(MediaItem item) =>
      _channel.invokeMethod<void>('restore', {'uri': item.uri});

  @override
  Future<void> permanentlyDelete(List<MediaItem> items) =>
      _channel.invokeMethod<void>('deletePermanently', {
        'uris': items.map((item) => item.uri).toList(growable: false),
      });

  @override
  Future<void> permanentlyDeleteAutomatically(List<MediaItem> items) =>
      _channel.invokeMethod<void>('deletePermanentlyAutomatically', {
        'uris': items.map((item) => item.uri).toList(growable: false),
      });

  MediaItem _fromNative(Map<dynamic, dynamic> row) => MediaItem(
        id: row['id'].toString(),
        uri: row['uri'] as String,
        kind: row['kind'] == 'video' ? MediaKind.video : MediaKind.image,
        dateAddedSeconds: (row['dateAddedSeconds'] as num?)?.toInt() ?? 0,
        bucketId: row['bucketId'] as String?,
        bucketName: row['bucketName'] as String?,
        relativePath: row['relativePath'] as String?,
        displayName: row['displayName'] as String?,
        durationMs: (row['durationMs'] as num?)?.toInt(),
        isTrashed: row['isTrashed'] == true,
      );
}
