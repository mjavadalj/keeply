import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/data/deleted_media_retention.dart';
import '../../../core/data/media_repository.dart';
import '../../../core/data/review_store.dart';
import '../../../core/domain/media_models.dart';

class DeletedScreen extends StatefulWidget {
  const DeletedScreen(
      {super.key, required this.repository, required this.store});
  final MediaRepository repository;
  final ReviewStore store;
  @override
  State<DeletedScreen> createState() => _DeletedScreenState();
}

class _DeletedScreenState extends State<DeletedScreen> {
  List<MediaItem> items = const [];
  bool loading = true;
  bool permanentlyDeleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await DeletedMediaRetention.purgeExpired(
      repository: widget.repository,
      store: widget.store,
    );
    final entries = widget.store.deletedEntries;
    final source = const MediaSource(
        id: 'all', label: 'All media', kind: MediaSourceKind.all);
    final trashed = await widget.repository
        .query(source: source, trashed: true, limit: 120);
    final ids = entries.map((entry) => entry.id).toSet();
    items =
        trashed.where((item) => ids.contains(item.id)).toList(growable: false);
    await widget.store.removeStaleDeleted(items.map((item) => item.id).toSet());
    if (mounted) setState(() => loading = false);
  }

  Future<void> _restore(MediaItem item) async {
    try {
      await widget.repository.restore(item);
      await widget.store.removeDeleted(item.id);
      if (mounted)
        setState(
            () => items = items.where((value) => value.id != item.id).toList());
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t restore this item.')));
    }
  }

  Future<void> _permanentlyDeleteAll() async {
    if (items.isEmpty || permanentlyDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all permanently?'),
        content: Text(
          'This will permanently delete ${items.length} items and free their storage. They cannot be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final deletingItems = List<MediaItem>.of(items, growable: false);
    setState(() => permanentlyDeleting = true);

    try {
      await widget.repository.permanentlyDelete(deletingItems);
      await widget.store
          .removeDeletedMany(deletingItems.map((item) => item.id));
      if (mounted) {
        setState(() {
          items = const [];
          permanentlyDeleting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => permanentlyDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Couldn’t permanently delete these items.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty)
      return const Center(
          child: Text('Nothing in Keeply’s deleted history yet.'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: permanentlyDeleting ? null : _permanentlyDeleteAll,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              icon: permanentlyDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: Text(
                permanentlyDeleting ? 'Deleting…' : 'Delete all permanently',
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => _DeletedTile(
                item: items[index],
                repository: widget.repository,
                onRestore: () => _restore(items[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeletedTile extends StatelessWidget {
  const _DeletedTile(
      {required this.item, required this.repository, required this.onRestore});
  final MediaItem item;
  final MediaRepository repository;
  final VoidCallback onRestore;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${item.isVideo ? 'Video' : 'Photo'} deleted item',
      button: true,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.displayName ?? 'Deleted media',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onRestore();
                    },
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore'),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: repository.loadThumbnail(item, size: 320),
              builder: (context, snapshot) => snapshot.hasData
                  ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                  : Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_outlined),
                    ),
            ),
            if (item.isVideo)
              const Positioned(right: 6, bottom: 6, child: _VideoMarker()),
          ],
        ),
      ),
    );
  }
}

class _VideoMarker extends StatelessWidget {
  const _VideoMarker();
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          color: Colors.black54, borderRadius: BorderRadius.circular(12)),
      child: const Padding(
          padding: EdgeInsets.all(4),
          child:
              Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white)));
}
