import 'package:flutter/material.dart';
import '../widgets/mini_player.dart';
import '../widgets/expanded_player.dart';
import 'music_home_page.dart';
import 'playlists_page.dart';
import 'search_page.dart';
import 'library_page.dart';
import '../gtk/gtk_scaffold.dart';
import '../gtk/gtk_native_header_bar.dart';

class MainMusicLayout extends StatefulWidget {
  const MainMusicLayout({super.key});

  @override
  State<MainMusicLayout> createState() => _MainMusicLayoutState();
}

class _MainMusicLayoutState extends State<MainMusicLayout> {
  int _currentTabIndex = 0;
  bool _isPlayerExpanded = false;

  final List<Widget> _pages = const [
    MusicHomePage(),
    PlaylistsPage(),
    SearchMusicPage(),
    LibraryPage(),
  ];

  final List<String> _tabTitles = const [
    'Inicio',
    'Playlists',
    'Búsqueda',
    'Tu Biblioteca',
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        bottomNavigationBar: GtkBottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
          items: const [
            GtkBottomNavigationItem(
              id: "0",
              label: 'Inicio',
              iconName: 'go-home-symbolic',
            ),
            GtkBottomNavigationItem(
              id: "1",
              label: 'Playlists',
              iconName: 'media-playlist-repeat-symbolic',
            ),
            GtkBottomNavigationItem(
              id: "2",
              label: 'Buscar',
              iconName: 'system-search-symbolic',
            ),
            GtkBottomNavigationItem(
              id: "3",
              label: 'Biblioteca',
              iconName: 'folder-music-symbolic',
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            children: [
              ListTile(
                title: Text('Settings'),
                leading: Icon(Icons.settings),
                onTap: () {
                  // Handle settings tap
                  Navigator.pop(context); // Close the drawer
                },
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            // Main Body Tabs
            switch (_currentTabIndex) {
              0 => const MusicHomePage(),
              1 => const PlaylistsPage(),
              2 => const SearchMusicPage(),
              3 => const LibraryPage(),
              _ => const MusicHomePage(),
            },
            // Floating Mini Player & Bottom Navigation Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Persistent Floating Mini Player
                  MiniPlayerWidget(
                    onTapExpand: () {
                      setState(() {
                        _isPlayerExpanded = true;
                      });
                    },
                  ),

                  // GTK Modern Bottom Navigation Bar
                ],
              ),
            ),

            // Expandable Fullscreen Player Sheet Overlay
            if (_isPlayerExpanded)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                left: 0,
                right: 0,
                child: ExpandedPlayerWidget(
                  onClose: () {
                    setState(() {
                      _isPlayerExpanded = false;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
