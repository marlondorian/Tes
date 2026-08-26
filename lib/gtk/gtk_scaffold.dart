import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gtk_scaffold_channel.dart';
import 'gtk_native_header_bar.dart';
import 'native_control_channel.dart';
import '../pages/route_observer.dart';

/// Abstract base class for all items that can be placed in a GTK / macOS header bar
abstract class GtkHeaderItem {
  final String id;
  final String? position; // 'start', 'center', 'end', or null to inherit from placement section

  const GtkHeaderItem({
    required this.id,
    this.position,
  });

  Map<String, dynamic> toJson();
}

/// A button or icon action item placed in the header bar.
class GtkHeaderAction extends GtkHeaderItem {
  final String? label;
  final String? iconName;
  final VoidCallback? onPressed;

  const GtkHeaderAction({
    required super.id,
    this.label,
    this.iconName,
    super.position,
    this.onPressed,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'action',
    'id': id,
    'label': label,
    'iconName': iconName,
    if (position != null) 'position': position,
  };
}

/// A title and optional subtitle item placed in the header bar.
class GtkHeaderTitle extends GtkHeaderItem {
  final String title;

  const GtkHeaderTitle({
    super.id = 'title',
    required this.title,
    super.position,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'title',
    'id': id,
    'title': title,
    if (position != null) 'position': position,
  };
}

/// A search input bar placed in the header bar.
class GtkHeaderSearchBar extends GtkHeaderItem {
  final String placeholder;
  final String value;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final double width;

  const GtkHeaderSearchBar({
    required super.id,
    this.placeholder = 'Buscar...',
    this.value = '',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.controller,
    this.width = 240.0,
    super.position,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'search',
    'id': id,
    'placeholder': placeholder,
    'value': value,
    'width': width,
    if (position != null) 'position': position,
  };
}

/// A tab bar / segmented control placed in the header bar.
class GtkHeaderTabBar extends GtkHeaderItem {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onTabSelected;

  const GtkHeaderTabBar({
    required super.id,
    required this.tabs,
    this.selectedIndex = 0,
    this.onTabSelected,
    super.position,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'tabbar',
    'id': id,
    'tabs': tabs,
    'selectedIndex': selectedIndex,
    if (position != null) 'position': position,
  };
}

typedef HeaderItem = GtkHeaderItem;
typedef HeaderAction = GtkHeaderAction;
typedef HeaderTitle = GtkHeaderTitle;
typedef HeaderSearchBar = GtkHeaderSearchBar;
typedef HeaderTabBar = GtkHeaderTabBar;

class GtkBottomNavigationItem {
  final String id;
  final String label;
  final String? iconName;

  const GtkBottomNavigationItem({
    required this.id,
    required this.label,
    this.iconName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'iconName': iconName,
  };
}

/// Standalone [GtkBottomNavigationBar] widget designed for standard Flutter [Scaffold.bottomNavigationBar].
///
/// ```dart
/// Scaffold(
///   appBar: GtkNativeHeaderBar(...),
///   body: MyBody(),
///   bottomNavigationBar: GtkBottomNavigationBar(
///     currentIndex: _index,
///     onTap: (i) => setState(() => _index = i),
///     items: const [
///       GtkBottomNavigationItem(id: "0", label: 'Home', iconName: 'go-home-symbolic'),
///       GtkBottomNavigationItem(id: "1", label: 'Settings', iconName: 'emblem-system-symbolic'),
///     ],
///   ),
/// )
/// ```
class GtkBottomNavigationBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GtkBottomNavigationItem> items;
  final bool visible;
  final Color? backgroundColor;
  final double height;

  const GtkBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.visible = true,
    this.backgroundColor,
    this.height = 54.0,
  });

  @override
  State<GtkBottomNavigationBar> createState() => _GtkBottomNavigationBarState();
}

class _GtkBottomNavigationBarState extends State<GtkBottomNavigationBar> {
  final _ch = GtkScaffoldChannel.instance;
  static final List<_GtkBottomNavigationBarState> _activeBottomNavs = [];

  @override
  void initState() {
    super.initState();
    if (!isNativeControlSupported) return;
    _ch.addListener(_handleMethodCall);
    _activeBottomNavs.add(this);
    _syncWithNative();
  }

  @override
  void didUpdateWidget(GtkBottomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isNativeControlSupported) return;
    if (_activeBottomNavs.isNotEmpty && _activeBottomNavs.last == this) {
      _syncWithNative();
    }
  }

  @override
  void dispose() {
    if (isNativeControlSupported) {
      _ch.removeListener(_handleMethodCall);
      _activeBottomNavs.remove(this);
      if (_activeBottomNavs.isEmpty) {
        _hideNative();
      } else if (_activeBottomNavs.isNotEmpty) {
        _activeBottomNavs.last._syncWithNative();
      }
    }
    super.dispose();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onBottomNavSelected') {
      final index = (call.arguments?['index'] as num?)?.toInt();
      if (index != null && mounted) {
        widget.onTap(index);
      }
    }
  }

  String? _colorToCss(Color? color) {
    if (color == null) return null;
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    final a = color.a;
    return 'rgba($r, $g, $b, $a)';
  }

  Future<void> _syncWithNative() async {
    try {
      await _ch.invokeMethod('setupBottomNav', {
        'selectedIndex': widget.currentIndex,
        'items': widget.items.map((i) => i.toJson()).toList(),
        'backgroundColor': _colorToCss(widget.backgroundColor) ?? '',
      });
      await _ch.invokeMethod('setBottomNavVisibility', {
        'visible': widget.visible,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to sync GtkBottomNavigationBar with native: ${e.message}');
    }
  }

  Future<void> _hideNative() async {
    try {
      await _ch.invokeMethod('setBottomNavVisibility', {
        'visible': false,
      });
    } catch (_) {}
  }

  Widget? _buildIcon(String? iconName) {
    if (iconName == null || iconName.isEmpty) return null;
    switch (iconName) {
      case "go-previous-symbolic":
      case "pan-start-symbolic":
        return const Icon(Icons.arrow_back);
      case "go-next-symbolic":
      case "pan-end-symbolic":
        return const Icon(Icons.arrow_forward);
      case "view-refresh-symbolic":
        return const Icon(Icons.refresh);
      case "dialog-information-symbolic":
        return const Icon(Icons.info_outline);
      case "go-home-symbolic":
        return const Icon(Icons.home);
      case "edit-symbolic":
        return const Icon(Icons.edit);
      case "emblem-system-symbolic":
      case "preferences-system-symbolic":
        return const Icon(Icons.settings);
      case "document-open-symbolic":
        return const Icon(Icons.insert_drive_file);
      case "folder-symbolic":
        return const Icon(Icons.folder);
      case "list-add-symbolic":
        return const Icon(Icons.add);
      case "user-trash-symbolic":
        return const Icon(Icons.delete);
      default:
        return const Icon(Icons.widgets);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    if (!isNativeControlSupported) {
      return BottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
        backgroundColor: widget.backgroundColor,
        items: widget.items.map((item) {
          return BottomNavigationBarItem(
            icon: _buildIcon(item.iconName) ?? const Icon(Icons.circle),
            label: item.label,
          );
        }).toList(),
      );
    }
    return SizedBox(height: widget.height);
  }
}

Future<void> applyCustomCss(String css) async {
  const channel = MethodChannel('com.example.macos_native_widgets/scaffold');
  await channel.invokeMethod('applyCustomCss', {'css': css});
}

class GtkScaffold extends StatefulWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<GtkHeaderAction>? headerActions;
  final GtkBottomNavigationBar? bottomNavigationBar;
  final Widget body;

  const GtkScaffold({
    super.key,
    this.title = '',
    this.showBackButton = false,
    this.onBack,
    this.headerActions,
    this.bottomNavigationBar,
    required this.body,
  });

  static bool get hasActiveScaffold => _GtkScaffoldState.hasActiveScaffold;

  @override
  State<GtkScaffold> createState() => _GtkScaffoldState();
}

class _GtkScaffoldState extends State<GtkScaffold> with RouteAware {
  final _ch = GtkScaffoldChannel.instance;
  static final List<_GtkScaffoldState> _activeScaffolds = [];
  static bool get hasActiveScaffold => _activeScaffolds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!isNativeControlSupported) return;
    _ch.addListener(_handleMethodCall);
    _activeScaffolds.add(this);
    _syncWithNative();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isNativeControlSupported) return;
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void didUpdateWidget(GtkScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isNativeControlSupported) return;
    if (_activeScaffolds.isNotEmpty && _activeScaffolds.last == this) {
      _syncWithNative();
    }
  }

  @override
  void dispose() {
    if (isNativeControlSupported) {
      routeObserver.unsubscribe(this);
      _ch.removeListener(_handleMethodCall);
      _activeScaffolds.remove(this);
      if (_activeScaffolds.isEmpty && !GtkNativeHeaderBar.hasActiveHeaderBar) {
        _hideNative();
      } else if (_activeScaffolds.isNotEmpty) {
        _activeScaffolds.last._syncWithNative();
      }
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    if (_activeScaffolds.isNotEmpty && _activeScaffolds.last == this) {
      _syncWithNative();
    }
  }

  @override
  void didPushNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_activeScaffolds.isNotEmpty && _activeScaffolds.last == this) {
        final modalRoute = ModalRoute.of(context);
        if (modalRoute != null && !modalRoute.isCurrent) {
          _hideNative();
        }
      }
    });
  }

  Future<void> _hideNative() async {
    try {
      await _ch.invokeMethod('setHeaderBarVisibility', {'visible': false});
    } catch (_) {}
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onHeaderBack':
        if (widget.onBack != null) {
          widget.onBack!();
        } else {
          Navigator.maybePop(context);
        }
        break;
      case 'onHeaderActionPressed':
        final id = call.arguments?['id'] as String?;
        if (id != null && widget.headerActions != null) {
          for (final action in widget.headerActions!) {
            if (action.id == id) {
              action.onPressed?.call();
              break;
            }
          }
        }
        break;
      case 'onBottomNavSelected':
        final index = (call.arguments?['index'] as num?)?.toInt();
        if (index != null && widget.bottomNavigationBar != null) {
          widget.bottomNavigationBar!.onTap(index);
        }
        break;
    }
  }

  Future<void> _syncWithNative() async {
    try {
      if (widget.title.isNotEmpty) {
        await _ch.invokeMethod('setHeaderBarVisibility', {'visible': true});
        await _ch.invokeMethod('updateHeaderBar', {
          'title': widget.title,
          'subtitle': '',
          'showBackButton': widget.showBackButton,
        });

        if (widget.headerActions != null) {
          await _ch.invokeMethod(
            'setHeaderActions',
            widget.headerActions!.map((a) => a.toJson()).toList(),
          );
        } else {
          await _ch.invokeMethod('setHeaderActions', []);
        }
      }
    } on PlatformException catch (e) {
      debugPrint('Failed to sync GtkScaffold with native: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isNativeControlSupported) {
      return Scaffold(
        appBar: widget.title.isNotEmpty
            ? GtkNativeHeaderBar(
                title: GtkHeaderTitle(title: widget.title),
                showBackButton: widget.showBackButton,
                onBack: widget.onBack,
                actions: widget.headerActions,
              )
            : null,
        bottomNavigationBar: widget.bottomNavigationBar,
        body: widget.body,
      );
    }
    return widget.body;
  }
}
