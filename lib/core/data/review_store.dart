import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/media_models.dart';

class ReviewStore {
  ReviewStore(this._preferences);

  static const _keptKey = 'keeply.kept_ids';
  static const _deletedKey = 'keeply.deleted_entries';
  static const _tutorialKey = 'keeply.tutorial_seen';
  static const deletedRetention = Duration(days: 30);

  final SharedPreferences _preferences;

  Set<String> get keptIds =>
      _preferences.getStringList(_keptKey)?.toSet() ?? {};

  bool get tutorialSeen => _preferences.getBool(_tutorialKey) ?? false;

  List<DeletedEntry> get deletedEntries {
    final raw = _preferences.getStringList(_deletedKey) ?? const <String>[];
    return raw
        .map((value) => jsonDecode(value))
        .whereType<Map<String, dynamic>>()
        .map(DeletedEntry.fromJson)
        .toList(growable: false);
  }

  List<DeletedEntry> get expiredDeletedEntries =>
      expiredDeletedEntriesAt(DateTime.now().millisecondsSinceEpoch);

  List<DeletedEntry> expiredDeletedEntriesAt(int nowMs) {
    final cutoffMs = nowMs - deletedRetention.inMilliseconds;
    return deletedEntries
        .where((entry) => entry.deletedAtMs <= cutoffMs)
        .toList(growable: false);
  }

  Future<void> markKept(String id) async {
    final next = keptIds..add(id);
    await _preferences.setStringList(_keptKey, next.toList());
  }

  Future<void> markTutorialSeen() => _preferences.setBool(_tutorialKey, true);

  Future<void> recordDeleted(MediaItem item) async {
    final entries =
        deletedEntries.where((entry) => entry.id != item.id).toList();
    entries.add(
      DeletedEntry(
        id: item.id,
        uri: item.uri,
        kind: item.kind,
        deletedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _saveDeleted(entries);
  }

  Future<void> removeDeleted(String id) async {
    await _saveDeleted(
        deletedEntries.where((entry) => entry.id != id).toList());
  }

  Future<void> removeDeletedMany(Iterable<String> ids) async {
    final removed = ids.toSet();
    await _saveDeleted(
        deletedEntries.where((entry) => !removed.contains(entry.id)).toList());
  }

  Future<void> clearKept() => _preferences.remove(_keptKey);

  Future<void> removeStaleDeleted(Set<String> availableIds) async {
    final active = deletedEntries
        .where((entry) => availableIds.contains(entry.id))
        .toList();
    await _saveDeleted(active);
  }

  Future<void> _saveDeleted(List<DeletedEntry> entries) {
    return _preferences.setStringList(
      _deletedKey,
      entries.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }
}
