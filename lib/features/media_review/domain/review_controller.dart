import 'dart:async';
import 'dart:typed_data';

import '../../../core/data/media_repository.dart';
import '../../../core/data/review_store.dart';
import '../../../core/domain/media_models.dart';

class ReviewController {
  ReviewController({required this.repository, required this.store});

  static const thumbnailPreloadCount = 5;
  static const _thumbnailCacheLimit = thumbnailPreloadCount + 3;

  final MediaRepository repository;
  final ReviewStore store;

  MediaSource source = const MediaSource(
      id: 'all', label: 'All media', kind: MediaSourceKind.all);
  final List<MediaItem> _queue = [];
  final _thumbnailCache = <String, Future<Uint8List?>>{};
  int _offset = 0;
  int _loadGeneration = 0;
  Future<bool>? _loadMoreFuture;
  Future<void> _actionTail = Future<void>.value();

  List<MediaItem> get queue => List.unmodifiable(_queue);
  bool get tutorialSeen => store.tutorialSeen;
  Set<String> get keptIds => store.keptIds;

  Future<void> load({MediaSource? selectedSource}) async {
    final generation = ++_loadGeneration;
    source = selectedSource ?? source;
    _queue.clear();
    _thumbnailCache.clear();
    _offset = 0;
    while (generation == _loadGeneration) {
      final loadedCurrentSource = await _loadMore();
      if (loadedCurrentSource) break;
    }
    if (generation == _loadGeneration) unawaited(preloadThumbnails());
  }

  Future<bool> _loadMore() {
    final existing = _loadMoreFuture;
    if (existing != null) {
      return existing.then((_) => false);
    }

    final generation = _loadGeneration;
    final requestedSource = source;
    final operation = _fetchMore(
      generation: generation,
      requestedSource: requestedSource,
    );
    _loadMoreFuture = operation.whenComplete(() => _loadMoreFuture = null);
    return _loadMoreFuture!;
  }

  Future<bool> _fetchMore({
    required int generation,
    required MediaSource requestedSource,
  }) async {
    final rows = await repository.query(
      source: requestedSource,
      offset: _offset,
      limit: 24,
    );
    if (generation != _loadGeneration) return false;
    _offset += rows.length;
    final kept = store.keptIds;
    _queue.addAll(rows.where((item) => !kept.contains(item.id)));
    return true;
  }

  Future<void> ensureBuffer() async {
    if (_queue.length < 5) await _loadMore();
    unawaited(preloadThumbnails());
  }

  Future<void> finishTutorial() => store.markTutorialSeen();

  Future<void> keep(MediaItem item) async {
    _remove(item.id);
    return _enqueueAction(() async {
      try {
        await store.markKept(item.id);
      } catch (_) {
        _queue.insert(0, item);
        rethrow;
      }
      await ensureBuffer();
    });
  }

  Future<void> delete(MediaItem item) async {
    _remove(item.id);
    return _enqueueAction(() async {
      try {
        await repository.trash(item);
        await store.recordDeleted(item);
        await ensureBuffer();
      } catch (_) {
        _queue.insert(0, item);
        rethrow;
      }
    });
  }

  Future<void> _enqueueAction(Future<void> Function() action) {
    final operation = _actionTail.then((_) => action());
    _actionTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<Uint8List?> thumbnail(MediaItem item) {
    final cached = _thumbnailCache.remove(item.id);
    if (cached != null) {
      _thumbnailCache[item.id] = cached;
      return cached;
    }

    final future = _loadThumbnailSafely(item);
    _thumbnailCache[item.id] = future;
    while (_thumbnailCache.length > _thumbnailCacheLimit) {
      _thumbnailCache.remove(_thumbnailCache.keys.first);
    }
    return future;
  }

  Future<void> preloadThumbnails({int count = thumbnailPreloadCount}) async {
    await Future.wait(
      _queue.take(count).map(thumbnail),
    );
  }

  Future<Uint8List?> _loadThumbnailSafely(MediaItem item) async {
    try {
      return await repository.loadThumbnail(item);
    } catch (_) {
      return null;
    }
  }

  Future<void> resetKept() async {
    await store.clearKept();
    await load();
  }

  void _remove(String id) {
    _queue.removeWhere((item) => item.id == id);
  }
}
