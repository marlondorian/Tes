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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1A),
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
      appBar: GtkNativeHeaderBar(
        leading: GtkHeaderTabBar(
          id: 'main-tabbar',
          tabs: _tabTitles,
          selectedIndex: _currentTabIndex,
          onTabSelected: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
        ),
        title: '',
        backgroundColor: const Color(0xFF1E1B2E),
        actions: [
          GtkHeaderSearchBar(
            id: 'header-search',
            placeholder: 'Buscar música...',
          ),
          GtkHeaderAction(
            id: 'info',
            iconName: 'dialog-information-symbolic',
            label: 'Acerca de',
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Midnight Music Player',
                applicationVersion: '2.0.0',
                applicationLegalese: '© 2026 Midnight Audio Lab',
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Body Tabs
          IndexedStack(index: _currentTabIndex, children: _pages),

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
    );
  }
}
