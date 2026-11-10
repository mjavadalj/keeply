import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keeply/core/data/deleted_media_retention.dart';
import 'package:keeply/core/data/media_repository.dart';
import 'package:keeply/core/data/review_store.dart';
import 'package:keeply/core/domain/media_models.dart';
import 'package:keeply/features/media_review/domain/review_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRepository implements MediaRepository {
  final items = <MediaItem>[];
  final deleted = <String>{};
  final thumbnailCalls = <String>[];
  final permanentlyDeleted = <String>[];
  Completer<void>? queryGate;
  String? gatedSourceId;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> ensureMediaManagement() async => true;
  @override
  Future<List<MediaItem>> query(
          {required MediaSource source,
          int offset = 0,
          int limit = 24,
          bool trashed = false}) async =>
      _query(
        source: source,
        offset: offset,
        limit: limit,
        trashed: trashed,
      );

  Future<List<MediaItem>> _query({
    required MediaSource source,
    required int offset,
    required int limit,
    required bool trashed,
  }) async {
    if (source.id == gatedSourceId) await queryGate?.future;
    return items
        .where((item) => item.isTrashed == trashed)
        .where((item) => source.kind != MediaSourceKind.bucket ||
            item.id == 'image:folder')
        .skip(offset)
        .take(limit)
        .toList();
  }
  @override
  Future<List<MediaSource>> discoverSources() async => const [
        MediaSource(id: 'all', label: 'All media', kind: MediaSourceKind.all)
      ];
  @override
  Future<Uint8List?> loadThumbnail(MediaItem item, {int size = 640}) async {
    thumbnailCalls.add(item.id);
    return Uint8List.fromList([item.id.length]);
  }

  @override
  Future<void> trash(MediaItem item) async => deleted.add(item.id);
  @override
  Future<void> restore(MediaItem item) async {}
  @override
  Future<void> permanentlyDelete(List<MediaItem> items) async {
    permanentlyDeleted.addAll(items.map((item) => item.id));
  }
  @override
  Future<void> permanentlyDeleteAutomatically(List<MediaItem> items) =>
      permanentlyDelete(items);
}

void main() {
  test('filters kept media from the review queue and reset requeues it',
      () async {
    SharedPreferences.setMockInitialValues({
      'keeply.kept_ids': <String>['image:1']
    });
    final store = ReviewStore(await SharedPreferences.getInstance());
    final repository = FakeRepository()
      ..items.addAll([
        MediaItem(
            id: 'image:1',
            uri: 'content://image/1',
            kind: MediaKind.image,
            dateAddedSeconds: 2),
        MediaItem(
            id: 'image:2',
            uri: 'content://image/2',
            kind: MediaKind.image,
            dateAddedSeconds: 1),
      ]);
    final controller = ReviewController(repository: repository, store: store);

    await controller.load();
    expect(controller.queue.map((item) => item.id), ['image:2']);

    await controller.resetKept();
    expect(controller.queue.map((item) => item.id), ['image:1', 'image:2']);
  });

  test('preloads five thumbnails and reuses the cached result', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ReviewStore(await SharedPreferences.getInstance());
    final repository = FakeRepository()
      ..items.addAll(List.generate(
        6,
        (index) => MediaItem(
          id: 'image:$index',
          uri: 'content://image/$index',
          kind: MediaKind.image,
          dateAddedSeconds: index,
        ),
      ));
    final controller = ReviewController(repository: repository, store: store);

    await controller.load();
    await controller.preloadThumbnails();
    await controller.thumbnail(controller.queue.first);

    expect(repository.thumbnailCalls.length, 5);
    expect(repository.thumbnailCalls,
        containsAll(controller.queue.take(5).map((item) => item.id)));
  });

  test('does not let an in-flight source load blank the newly selected source',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = ReviewStore(await SharedPreferences.getInstance());
    final repository = FakeRepository()
      ..items.addAll([
        MediaItem(
            id: 'image:all',
            uri: 'content://image/all',
            kind: MediaKind.image,
            dateAddedSeconds: 2),
        MediaItem(
            id: 'image:folder',
            uri: 'content://image/folder',
            kind: MediaKind.image,
            dateAddedSeconds: 1),
      ])
      ..queryGate = Completer<void>()
      ..gatedSourceId = 'camera';
    final controller = ReviewController(repository: repository, store: store);
    const folder = MediaSource(
        id: 'camera', label: 'Camera', kind: MediaSourceKind.bucket);
    const all = MediaSource(
        id: 'all', label: 'All media', kind: MediaSourceKind.all);

    final folderLoad = controller.load(selectedSource: folder);
    await Future<void>.delayed(Duration.zero);
    final allLoad = controller.load(selectedSource: all);
    repository.queryGate!.complete();
    await Future.wait([folderLoad, allLoad]);

    expect(controller.source.id, 'all');
    expect(controller.queue.map((item) => item.id),
        ['image:all', 'image:folder']);
  });

  test('purges deleted media only after permanent deletion succeeds', () async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'keeply.deleted_entries': [
        '{"id":"image:expired","uri":"content://image/expired","kind":"image","deletedAtMs":${nowMs - ReviewStore.deletedRetention.inMilliseconds}}',
      ],
    });
    final store = ReviewStore(await SharedPreferences.getInstance());
    final repository = FakeRepository();

    await DeletedMediaRetention.purgeExpired(
      repository: repository,
      store: store,
    );

    expect(repository.permanentlyDeleted, ['image:expired']);
    expect(store.deletedEntries, isEmpty);
  });
}
