import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gtk_scaffold.dart';
import 'gtk_scaffold_channel.dart';
import 'gtk_theme_manager.dart';
import 'native_control_channel.dart';
import '../pages/route_observer.dart';

/// A [PreferredSizeWidget] that matches the height and configures the native GTK HeaderBar
/// rendered as a GtkOverlay on top of FlView.
///
/// Use it as the [appBar] argument of a [Scaffold]:
///
/// ```dart
/// Scaffold(
///   appBar: GtkNativeHeaderBar(
///     title: GtkHeaderTitle(title: 'My App'),
///     leading: GtkHeaderAction(
///       id: 'back',
///       iconName: 'go-previous-symbolic',
///       onPressed: () => Navigator.pop(context),
///     ),
///     actions: [
///       GtkHeaderAction(
///         id: 'refresh',
///         iconName: 'view-refresh-symbolic',
///         label: 'Refresh',
///         onPressed: () {},
///       ),
///     ],
///   ),
///   body: MyContent(),
/// )
/// ```
class GtkNativeHeaderBar extends StatefulWidget implements PreferredSizeWidget {
  /// Optional custom title [GtkHeaderItem] placed in the center of the header bar.
  /// Can be a [GtkHeaderTitle], [GtkHeaderSearchBar], or [GtkHeaderTabBar].
  final GtkHeaderItem? title;

  /// Optional custom leading [GtkHeaderItem] (e.g. back button, search bar, or menu button).
  final GtkHeaderItem? leading;

  /// Whether to show the standard GTK back button.
  final bool showBackButton;

  /// Callback when standard back button is clicked.
  final VoidCallback? onBack;

  /// List of action/widget items placed on the GTK HeaderBar.
  final List<GtkHeaderItem>? actions;

  /// Optional background color for the GTK HeaderBar.
  /// If null, the native GTK theme default color is used.
  final Color? backgroundColor;

  /// Default height before the native measurement is available.
  /// 47px is the standard Adwaita GTK HeaderBar natural height.
  final double defaultHeight;

  const GtkNativeHeaderBar({
    super.key,
    this.title,
    this.leading,
    this.showBackButton = false,
    this.onBack,
    this.actions,
    this.backgroundColor,
    this.defaultHeight = 47.0,
  });

  @override
  Size get preferredSize {
    if (!isNativeControlSupported) {
      return const Size.fromHeight(kToolbarHeight);
    }
    final height = GtkThemeManager.instance.headerBarHeight;
    return Size.fromHeight(Platform.isMacOS ? 52.0 : (height > 0 ? height : 47.0));
  }

  static bool get hasActiveHeaderBar =>
      _GtkNativeHeaderBarState.hasActiveHeaderBar;

  @override
  State<GtkNativeHeaderBar> createState() => _GtkNativeHeaderBarState();
}

/// Alias for [GtkNativeHeaderBar] for standard Flutter AppBar naming consistency.
typedef GtkAppBar = GtkNativeHeaderBar;

class _GtkNativeHeaderBarState extends State<GtkNativeHeaderBar>
    with RouteAware {
  final _ch = GtkScaffoldChannel.instance;
  late double _height;

  static final List<_GtkNativeHeaderBarState> _activeInstances = [];
  static bool get hasActiveHeaderBar => _activeInstances.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!isNativeControlSupported) return;
    _height = GtkThemeManager.instance.headerBarHeight;
    _ch.addListener(_handleMethodCall);
    GtkThemeManager.instance.addListener(_onThemeChanged);
    _activeInstances.add(this);
    _syncWithNative();
    _fetchNativeHeight();
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {
      _height = GtkThemeManager.instance.headerBarHeight;
    });
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
  void didUpdateWidget(GtkNativeHeaderBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isNativeControlSupported) return;
    if (_activeInstances.isNotEmpty && _activeInstances.last == this) {
      _syncWithNative();
    }
  }

  @override
  void dispose() {
    if (isNativeControlSupported) {
      routeObserver.unsubscribe(this);
      _ch.removeListener(_handleMethodCall);
      GtkThemeManager.instance.removeListener(_onThemeChanged);
      _activeInstances.remove(this);
      if (_activeInstances.isEmpty && !GtkScaffold.hasActiveScaffold) {
        _hideNative();
      } else if (_activeInstances.isNotEmpty) {
        _activeInstances.last._syncWithNative();
      }
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    if (_activeInstances.isNotEmpty && _activeInstances.last == this) {
      _syncWithNative();
    }
  }

  @override
  void didPushNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_activeInstances.isNotEmpty && _activeInstances.last == this) {
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

  GtkHeaderItem? get _resolvedTitleItem => widget.title;

  List<GtkHeaderItem> _getAllItems() {
    final list = <GtkHeaderItem>[];
    if (widget.leading != null) {
      list.add(widget.leading!);
    }
    final titleItem = _resolvedTitleItem;
    if (titleItem != null) {
      list.add(titleItem);
    }
    if (widget.actions != null) {
      list.addAll(widget.actions!);
    }
    return list;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onHeaderBack':
        if (!mounted) break;
        if (widget.leading is GtkHeaderAction && (widget.leading as GtkHeaderAction).onPressed != null) {
          (widget.leading as GtkHeaderAction).onPressed!();
        } else if (widget.onBack != null) {
          widget.onBack!();
        } else {
          Navigator.maybePop(context);
        }
        break;
      case 'onHeaderActionPressed':
        final id = call.arguments?['id'] as String?;
        if (id == null) break;

        for (final item in _getAllItems()) {
          if (item is GtkHeaderAction && item.id == id) {
            item.onPressed?.call();
            break;
          }
        }
        break;
      case 'onHeaderSearchChanged':
        final id = call.arguments?['id'] as String?;
        final text = call.arguments?['text'] as String? ?? '';
        if (id == null) break;

        for (final item in _getAllItems()) {
          if (item is GtkHeaderSearchBar && item.id == id) {
            item.onChanged?.call(text);
            break;
          }
        }
        break;
      case 'onHeaderSearchSubmitted':
        final id = call.arguments?['id'] as String?;
        final text = call.arguments?['text'] as String? ?? '';
        if (id == null) break;

        for (final item in _getAllItems()) {
          if (item is GtkHeaderSearchBar && item.id == id) {
            item.onSubmitted?.call(text);
            break;
          }
        }
        break;
      case 'onHeaderTabSelected':
        final id = call.arguments?['id'] as String?;
        final index = call.arguments?['index'] as int? ?? 0;
        if (id == null) break;

        for (final item in _getAllItems()) {
          if (item is GtkHeaderTabBar && item.id == id) {
            item.onTabSelected?.call(index);
            break;
          }
        }
        break;
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
      await _ch.invokeMethod('setHeaderBarVisibility', {'visible': true});
      await _ch.invokeMethod('updateHeaderBar', {
        'title': '',
        'subtitle': '',
        'showBackButton': widget.showBackButton,
        'backgroundColor': _colorToCss(widget.backgroundColor) ?? '',
      });

      final allActions = <Map<String, dynamic>>[];
      if (widget.leading != null) {
        final leadingJson = widget.leading!.toJson();
        leadingJson['position'] = widget.leading!.position ?? 'start';
        allActions.add(leadingJson);
      }
      final titleItem = _resolvedTitleItem;
      if (titleItem != null) {
        final titleJson = titleItem.toJson();
        titleJson['position'] = titleItem.position ?? 'center';
        allActions.add(titleJson);
      }
      if (widget.actions != null) {
        for (final action in widget.actions!) {
          final actionJson = action.toJson();
          actionJson['position'] = action.position ?? 'end';
          allActions.add(actionJson);
        }
      }

      await _ch.invokeMethod('setHeaderActions', allActions);
    } on PlatformException catch (e) {
      debugPrint('Failed to sync GtkNativeHeaderBar with native: ${e.message}');
    }
  }

  Future<void> _fetchNativeHeight() async {
    try {
      final h = await _ch.invokeMethod<int>('getHeaderBarHeight');
      if (h != null && h > 0 && mounted) {
        setState(() => _height = h.toDouble());
      }
    } on PlatformException {
      // Silently fall back to defaultHeight on non-Linux platforms
    }
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

  Widget _buildHeaderItemWidget(GtkHeaderItem item) {
    if (item is GtkHeaderAction) {
      return IconButton(
        icon: _buildIcon(item.iconName) ??
            (item.label != null
                ? Text(item.label!)
                : const Icon(Icons.widgets)),
        tooltip: item.label,
        onPressed: item.onPressed,
      );
    } else if (item is GtkHeaderTitle) {
      return Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
    } else if (item is GtkHeaderSearchBar) {
      return Container(
        width: item.width,
        height: 34,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: TextField(
          controller: item.controller ?? TextEditingController(text: item.value),
          onChanged: item.onChanged,
          onSubmitted: item.onSubmitted,
          style: const TextStyle(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: item.placeholder,
            hintStyle: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white70),
            suffixIcon: item.onClear != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 14, color: Colors.white70),
                    onPressed: item.onClear,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.12),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
    } else if (item is GtkHeaderTabBar) {
      return Container(
        height: 32,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(item.tabs.length, (index) {
            final isSelected = index == item.selectedIndex;
            return GestureDetector(
              onTap: () => item.onTabSelected?.call(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.tabs[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
            );
          }),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (!isNativeControlSupported) {
      Widget? leadingWidget;
      if (widget.leading != null) {
        leadingWidget = _buildHeaderItemWidget(widget.leading!);
      } else if (widget.showBackButton) {
        leadingWidget = IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack ?? () => Navigator.maybePop(context),
        );
      }

      Widget? titleWidget;
      if (widget.title != null) {
        titleWidget = _buildHeaderItemWidget(widget.title!);
      }

      final actionsWidgets = <Widget>[];
      if (widget.actions != null) {
        for (final action in widget.actions!) {
          actionsWidgets.add(_buildHeaderItemWidget(action));
        }
      }

      return AppBar(
        title: titleWidget,
        centerTitle: true,
        leading: leadingWidget,
        automaticallyImplyLeading: false,
        actions: actionsWidgets,
        backgroundColor: widget.backgroundColor,
      );
    }

    return SizedBox(height: _height);
  }
}
