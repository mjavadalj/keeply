import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keeply/core/data/review_store.dart';
import 'package:keeply/core/domain/media_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ReviewStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = ReviewStore(await SharedPreferences.getInstance());
  });

  test('persists kept IDs and reset clears only kept IDs', () async {
    final item = MediaItem(id: 'image:1', uri: 'content://image/1', kind: MediaKind.image, dateAddedSeconds: 1);
    await store.markKept(item.id);
    await store.recordDeleted(item.copyWith(isTrashed: true));

    expect(store.keptIds, contains(item.id));
    expect(store.deletedEntries, hasLength(1));

    await store.clearKept();
    expect(store.keptIds, isEmpty);
    expect(store.deletedEntries, hasLength(1));
  });

  test('removes stale deleted entries without touching active entries', () async {
    final first = MediaItem(id: 'image:1', uri: 'content://image/1', kind: MediaKind.image, dateAddedSeconds: 1);
    final second = MediaItem(id: 'video:2', uri: 'content://video/2', kind: MediaKind.video, dateAddedSeconds: 2);
    await store.recordDeleted(first);
    await store.recordDeleted(second);

    await store.removeStaleDeleted({first.id});
    expect(store.deletedEntries.map((entry) => entry.id), [first.id]);
  });

  test('identifies entries at or beyond the 30-day retention boundary', () async {
    final nowMs = DateTime(2026, 9, 12).millisecondsSinceEpoch;
    final expiredMs =
        nowMs - ReviewStore.deletedRetention.inMilliseconds;
    SharedPreferences.setMockInitialValues({
      'keeply.deleted_entries': [
        jsonEncode({
          'id': 'image:expired',
          'uri': 'content://image/expired',
          'kind': 'image',
          'deletedAtMs': expiredMs,
        }),
        jsonEncode({
          'id': 'image:recent',
          'uri': 'content://image/recent',
          'kind': 'image',
          'deletedAtMs': expiredMs + 1,
        }),
      ],
    });
    store = ReviewStore(await SharedPreferences.getInstance());

    expect(
      store.expiredDeletedEntriesAt(nowMs).map((entry) => entry.id),
      ['image:expired'],
    );
  });
}
