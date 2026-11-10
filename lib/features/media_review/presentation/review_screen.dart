import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/deleted_media_retention.dart';
import '../../../core/domain/media_models.dart';
import '../domain/review_controller.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.controller});

  final ReviewController controller;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final ReviewController controller = widget.controller;
  List<MediaSource> sources = const [];
  bool loading = true;
  bool permissionDenied = false;
  bool mediaManagementDenied = false;
  bool mediaManagementRequested = false;
  int sourceLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final allowed = await controller.repository.hasPermission();
    if (!allowed) {
      final granted = await controller.repository.requestPermission();
      if (!granted) {
        if (mounted)
          setState(() {
            permissionDenied = true;
            loading = false;
          });
        return;
      }
    }
    if (!mediaManagementRequested) {
      mediaManagementRequested = true;
      final granted = await _ensureMediaManagement();
      if (!granted) {
        mediaManagementRequested = false;
        if (mounted) {
          setState(() {
            mediaManagementDenied = true;
            loading = false;
          });
        }
        return;
      }
      mediaManagementDenied = false;
    }
    unawaited(DeletedMediaRetention.purgeExpired(
      repository: controller.repository,
      store: controller.store,
    ));
    try {
      sources = await controller.repository.discoverSources();
      await controller.load();
    } catch (_) {
      permissionDenied = false;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<bool> _ensureMediaManagement() async {
    try {
      return await controller.repository.ensureMediaManagement();
    } catch (_) {
      return false;
    }
  }

  Future<void> _act(MediaItem item, bool delete) async {
    final action = delete ? controller.delete(item) : controller.keep(item);
    // The controller removes the item before persistence awaits. Rebuild now
    // so both buttons and the next card respond on the same frame.
    if (mounted) setState(() {});
    try {
      await action;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Couldn’t delete this item.'),
              action: SnackBarAction(
                  label: 'Retry', onPressed: () => _act(item, true))),
        );
      }
      return;
    }
  }

  Future<void> _showSources() async {
    if (sources.isEmpty) return;
    final selected = await showModalBottomSheet<MediaSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: sources
              .map((source) => ListTile(
                    title: Text(source.label),
                    leading: Icon(source.kind == MediaSourceKind.videos
                        ? Icons.movie_outlined
                        : Icons.photo_library_outlined),
                    trailing: source.id == controller.source.id
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(context, source),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected != null && mounted) {
      final generation = ++sourceLoadGeneration;
      setState(() => loading = true);
      await controller.load(selectedSource: selected);
      if (mounted && generation == sourceLoadGeneration) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _resetKept() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review kept media again?'),
        content: const Text(
            'Only media you kept will be added back to the review queue. Deleted media stays deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => loading = true);
      await controller.resetKept();
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (permissionDenied) return _PermissionState(onRetry: _start);
    if (mediaManagementDenied) return _MediaManagementState(onRetry: _start);
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600;
      final content = Column(
        children: [
          _SourceHeader(
              source: controller.source,
              onTap: _showSources,
              onReset: _resetKept),
          Expanded(child: _buildCardArea()),
           _Actions(
               enabled: controller.tutorialSeen &&
                   controller.queue.isNotEmpty &&
                   true,
              onDelete: () => _act(controller.queue.first, true),
              onKeep: () => _act(controller.queue.first, false)),
          const SizedBox(height: 20),
        ],
      );
      return Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20),
          child: content);
    });
  }

  Widget _buildCardArea() {
    if (!controller.tutorialSeen) {
      return Center(child: _TutorialCard(onDismiss: () async {
        await controller.finishTutorial();
        setState(() {});
      }));
    }
    if (controller.queue.isEmpty) {
      return const Center(child: _EmptyState());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final item = controller.queue.first;
        final stackDepth = (controller.queue.length - 1).clamp(0, 2).toInt();
        final cardWidth = constraints.maxWidth.clamp(0.0, 460.0).toDouble();
        final cardHeight =
            (constraints.maxHeight * .76).clamp(0.0, 620.0).toDouble();

        return Column(
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      for (var depth = stackDepth; depth >= 1; depth--)
                        Positioned.fill(
                          top: -(depth * 12.0),
                          left: depth * 10.0,
                          right: depth * 10.0,
                          bottom: depth * 12.0,
                          child: _StackCard(
                            key:
                                ValueKey('stack-${controller.queue[depth].id}'),
                            depth: depth,
                            item: controller.queue[depth],
                            loadThumbnail: controller.thumbnail,
                          ),
                        ),
                      _SwipeCard(
                          key: ValueKey(item.id),
                           item: item,
                           loadThumbnail: controller.thumbnail,
                          enabled: true,
                          onKeep: () => _act(item, false),
                          onDelete: () => _act(item, true)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _SwipeHints(),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

class _SourceHeader extends StatelessWidget {
  const _SourceHeader(
      {required this.source, required this.onTap, required this.onReset});
  final MediaSource source;
  final VoidCallback onTap;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Choose media source',
            child: Material(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(
                            Icons.photo_library_outlined,
                            color: colors.onPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          source.label,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colors.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      Icon(
                        Icons.expand_more,
                        color: colors.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Review kept media again',
          onPressed: onReset,
          style: IconButton.styleFrom(
            foregroundColor: colors.secondary,
            backgroundColor: colors.secondaryContainer,
          ),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions(
      {required this.enabled, required this.onDelete, required this.onKeep});
  final bool enabled;
  final VoidCallback onDelete;
  final VoidCallback onKeep;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled ? onDelete : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: enabled ? onKeep : null,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Keep'),
          ),
        ),
      ],
    );
  }
}

class _SwipeCard extends StatefulWidget {
  const _SwipeCard(
      {super.key,
       required this.item,
       required this.loadThumbnail,
       required this.enabled,
       required this.onKeep,
       required this.onDelete});
  final MediaItem item;
  final Future<Uint8List?> Function(MediaItem) loadThumbnail;
  final bool enabled;
  final VoidCallback onKeep;
  final VoidCallback onDelete;
  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Offset> _offset = ValueNotifier(Offset.zero);
  Uint8List? bytes;
  bool loading = true;
  late final AnimationController _settleController;
  Animation<Offset>? _settleAnimation;
  bool _thresholdHapticSent = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(_handleSettleTick);
    _load();
  }

  @override
  void dispose() {
    _settleController.dispose();
    _offset.dispose();
    super.dispose();
  }

  void _handleSettleTick() {
    final animation = _settleAnimation;
    if (!mounted || animation == null) return;
    _offset.value = animation.value;
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final loaded = await widget.loadThumbnail(widget.item);
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      bytes = loaded;
      loading = false;
    });
  }

  @override
  void didUpdateWidget(covariant _SwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _offset.value = Offset.zero;
      bytes = null;
      loading = true;
      _thresholdHapticSent = false;
      _load();
    }
  }

  Future<void> _animateTo(Offset target, {required Duration duration}) async {
    _settleController.stop();
    _settleController.duration = duration;
    _settleAnimation = Tween<Offset>(
      begin: _offset.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _settleController,
      curve: Curves.easeOutCubic,
    ));
    try {
      await _settleController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    } finally {
      _settleAnimation = null;
    }
  }

  void _end(DragEndDetails details) {
    final width = context.size?.width ?? 400.0;
    final threshold = width * .28;
    if (_offset.value.dx.abs() > threshold ||
        details.velocity.pixelsPerSecond.dx.abs() > 900) {
      final delete =
          _offset.value.dx < 0 || details.velocity.pixelsPerSecond.dx < -900;
      _dismiss(delete);
    } else {
      _animateTo(Offset.zero, duration: const Duration(milliseconds: 220));
      _thresholdHapticSent = false;
    }
  }

  Future<void> _dismiss(bool delete) async {
    await _animateTo(
      Offset(
        (delete ? -1 : 1) * (context.size?.width ?? 400) * 1.25,
        _offset.value.dy,
      ),
      duration: const Duration(milliseconds: 180),
    );
    if (!mounted) return;
    (delete ? widget.onDelete : widget.onKeep)();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colors = Theme.of(context).colorScheme;
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 400.0;
        final threshold = width * .28;
        return ValueListenableBuilder<Offset>(
          valueListenable: _offset,
          builder: (context, offset, child) {
            final dragProgress = (offset.dx.abs() / threshold).clamp(0.0, 1.0);
            final dragging = offset.dx.abs() > 8;
            final keep = offset.dx >= 0;
            final intentColor = keep ? colors.primary : colors.error;
            return IgnorePointer(
              ignoring: !widget.enabled,
              child: GestureDetector(
                onPanUpdate: (details) {
                  _settleController.stop();
                  _settleAnimation = null;
                  final nextOffset = offset + details.delta;
                  if (!_thresholdHapticSent && nextOffset.dx.abs() >= threshold) {
                    _thresholdHapticSent = true;
                    HapticFeedback.mediumImpact();
                  } else if (_thresholdHapticSent &&
                      nextOffset.dx.abs() < threshold * .82) {
                    _thresholdHapticSent = false;
                  }
                  _offset.value = nextOffset;
                },
                onPanEnd: _end,
                child: Transform.translate(
                  offset: offset,
            child: Transform.rotate(
              angle: offset.dx / 2200,
              child: RepaintBoundary(
                child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 6,
                shadowColor: colors.shadow.withAlpha(80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: dragging
                        ? intentColor
                            .withAlpha(110 + (dragProgress * 145).round())
                        : colors.outlineVariant,
                    width: dragging ? 2.0 : 1.5,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bytes != null)
                      RepaintBoundary(
                        child: Image.memory(bytes!,
                            fit: BoxFit.cover, gaplessPlayback: true),
                      )
                    else
                      Container(
                        color: colors.surfaceContainerHighest,
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : const Icon(Icons.image_not_supported_outlined,
                                size: 48),
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 96,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                    ),
                    if (widget.item.isVideo)
                      const Positioned(
                          top: 16, right: 16, child: _VideoBadge()),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 18,
                      child: Text(
                        widget.item.displayName ??
                            (widget.item.isVideo ? 'Video' : 'Photo'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (dragging)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Align(
                            alignment:
                                keep ? Alignment.topLeft : Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Opacity(
                                opacity: (dragProgress * 1.35).clamp(0.0, 1.0),
                                child: Transform.rotate(
                                  angle: keep ? -.08 : .08,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: keep
                                          ? colors.primaryContainer
                                          : colors.errorContainer,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: intentColor,
                                        width: 2,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            keep
                                                ? Icons.check_rounded
                                                : Icons.delete_outline,
                                            color: keep
                                                ? colors.onPrimaryContainer
                                                : colors.onErrorContainer,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            keep ? 'KEEP' : 'DELETE',
                                            style: TextStyle(
                                              color: keep
                                                  ? colors.onPrimaryContainer
                                                  : colors.onErrorContainer,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                ),
              ),
            ),
          ),
        ),
      );
          },
        );
      },
    );
  }
}

class _StackCard extends StatefulWidget {
  const _StackCard({
    super.key,
    required this.depth,
    required this.item,
    required this.loadThumbnail,
  });

  final int depth;
  final MediaItem item;
  final Future<Uint8List?> Function(MediaItem) loadThumbnail;

  @override
  State<_StackCard> createState() => _StackCardState();
}

class _StackCardState extends State<_StackCard> {
  Uint8List? bytes;
  bool loading = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _StackCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id == widget.item.id) return;
    bytes = null;
    loading = true;
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final loaded = await widget.loadThumbnail(widget.item);
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      bytes = loaded;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Card(
        elevation: 2,
        color: colors.surface.withAlpha(widget.depth == 1 ? 255 : 245),
        shadowColor: colors.shadow.withAlpha(45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colors.outlineVariant, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true)
            else
              Container(
                color: colors.surfaceContainerHighest,
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : const Icon(Icons.image_not_supported_outlined, size: 48),
              ),
            Container(
                color: Colors.black.withAlpha(widget.depth == 1 ? 52 : 88)),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(180),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeHints extends StatelessWidget {
  const _SwipeHints();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.arrow_back_rounded, color: colors.error, size: 22),
        const SizedBox(width: 8),
        Text('Swipe left to delete',
            style: TextStyle(color: colors.error, fontWeight: FontWeight.w700)),
        const SizedBox(width: 20),
        Text('Swipe right to keep',
            style:
                TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Icon(Icons.arrow_forward_rounded, color: colors.primary, size: 22),
      ],
    );
  }
}

class _VideoBadge extends StatelessWidget {
  const _VideoBadge();
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          color: Colors.black54, borderRadius: BorderRadius.circular(20)),
      child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.play_arrow_rounded, color: Colors.white)));
}

class _TutorialCard extends StatelessWidget {
  const _TutorialCard({required this.onDismiss});
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) => _TutorialGesture(onDismiss: onDismiss);
}

class _TutorialGesture extends StatefulWidget {
  const _TutorialGesture({required this.onDismiss});
  final VoidCallback onDismiss;
  @override
  State<_TutorialGesture> createState() => _TutorialGestureState();
}

class _TutorialGestureState extends State<_TutorialGesture> {
  double drag = 0;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onPanUpdate: (details) => setState(() => drag += details.delta.dx),
      onPanEnd: (_) {
        if (drag.abs() > 60)
          widget.onDismiss();
        else
          setState(() => drag = 0);
      },
      child: Transform.translate(
        offset: Offset(drag, 0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      Icons.swipe_rounded,
                      size: 56,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('A calmer camera roll',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text('Swipe left to delete. Swipe right to keep.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: widget.onDismiss,
                    child: const Text('Start reviewing')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.tertiaryContainer,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(
              Icons.done_all_rounded,
              size: 64,
              color: colors.onTertiaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('You’re done.', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Nothing else is waiting in this source.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _PermissionState extends StatelessWidget {
  const _PermissionState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.photo_library_outlined, size: 56),
            const SizedBox(height: 16),
            Text('Media access is required',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'Allow access so Keeply can show and organize your camera roll.'),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Try again'))
          ])));
}

class _MediaManagementState extends StatelessWidget {
  const _MediaManagementState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security_outlined, size: 56),
              const SizedBox(height: 16),
              Text('Media management access is required',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                  'Allow Keeply to move media into the phone’s trash without asking on every swipe.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: onRetry, child: const Text('Open settings')),
            ],
          ),
        ),
      );
}
