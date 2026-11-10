import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/data/media_store_repository.dart';
import 'core/data/review_store.dart';
import 'core/presentation/keeply_theme.dart';
import 'features/deleted_media/presentation/deleted_screen.dart';
import 'features/media_review/domain/review_controller.dart';
import 'features/media_review/presentation/review_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final store = ReviewStore(preferences);
  final repository = MediaStoreRepository();
  runApp(KeeplyApp(store: store, repository: repository));
}

class KeeplyApp extends StatelessWidget {
  const KeeplyApp({super.key, required this.store, required this.repository});
  final ReviewStore store;
  final MediaStoreRepository repository;
  @override
  Widget build(BuildContext context) {
    final controller = ReviewController(repository: repository, store: store);
    return MaterialApp(
      title: 'Keeply',
      debugShowCheckedModeBanner: false,
      theme: KeeplyTheme.light(KeeplyTheme.lightScheme),
      darkTheme: KeeplyTheme.dark(KeeplyTheme.darkScheme),
      themeMode: ThemeMode.system,
      home:
          _Shell(controller: controller, repository: repository, store: store),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell(
      {required this.controller,
      required this.repository,
      required this.store});
  final ReviewController controller;
  final MediaStoreRepository repository;
  final ReviewStore store;
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int index = 0;
  int deletedRefreshToken = 0;
  @override
  Widget build(BuildContext context) {
    final destinations = const [
      NavigationDestination(
          icon: Icon(Icons.swipe_outlined),
          selectedIcon: Icon(Icons.swipe),
          label: 'Review'),
      NavigationDestination(
          icon: Icon(Icons.delete_outline),
          selectedIcon: Icon(Icons.delete),
          label: 'Deleted')
    ];
    final pages = [
      ReviewScreen(controller: widget.controller),
      DeletedScreen(
          key: ValueKey(deletedRefreshToken),
          repository: widget.repository,
          store: widget.store)
    ];
    return Scaffold(
      appBar: AppBar(title: Text(index == 0 ? 'Keeply' : 'Deleted')),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() {
                index = value;
                if (value == 1) deletedRefreshToken++;
              }),
          destinations: destinations),
    );
  }
}
