import '../domain/media_models.dart';
import 'media_repository.dart';
import 'review_store.dart';

class DeletedMediaRetention {
  DeletedMediaRetention._();

  static Future<void>? _inFlight;

  static Future<void> purgeExpired({
    required MediaRepository repository,
    required ReviewStore store,
  }) {
    final existing = _inFlight;
    if (existing != null) return existing;

    final operation = _purgeExpired(repository: repository, store: store);
    _inFlight = operation.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  static Future<void> _purgeExpired({
    required MediaRepository repository,
    required ReviewStore store,
  }) async {
    final expired = store.expiredDeletedEntries;
    if (expired.isEmpty) return;

    final items = expired
        .map(
          (entry) => MediaItem(
            id: entry.id,
            uri: entry.uri,
            kind: entry.kind,
            dateAddedSeconds: 0,
            isTrashed: true,
          ),
        )
        .toList(growable: false);

    try {
      await repository.permanentlyDeleteAutomatically(items);
      await store.removeDeletedMany(expired.map((entry) => entry.id));
    } catch (_) {
      // Keep the entry so a later launch can retry the cleanup.
    }
  }
}
