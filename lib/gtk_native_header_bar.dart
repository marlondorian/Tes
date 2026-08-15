import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gtk_scaffold.dart';
import 'gtk_scaffold_channel.dart';
import 'native_control_channel.dart';
import 'route_observer.dart';

/// A [PreferredSizeWidget] that matches the height and configures the native GTK HeaderBar
/// rendered as a GtkOverlay on top of FlView.
///
/// Use it as the [appBar] argument of a [Scaffold]:
///
/// ```dart
/// Scaffold(
///   appBar: GtkNativeHeaderBar(
///     title: 'My App',
///     subtitle: 'Subheading',
///     leading: GtkHeaderAction(
///       id: 'back',
///       iconName: 'go-previous-symbolic',
///       position: 'start',
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
  /// Main title string displayed in the GTK HeaderBar.
  final String title;

  /// Optional subtitle string displayed under the title.
  final String? subtitle;

  /// Optional custom leading [GtkHeaderAction] (e.g. back button or menu button).
  final GtkHeaderAction? leading;

  /// Whether to show the standard GTK back button.
  final bool showBackButton;

  /// Callback when standard back button is clicked.
  final VoidCallback? onBack;

  /// List of action items placed on the GTK HeaderBar.
  final List<GtkHeaderAction>? actions;

  /// Optional background color for the GTK HeaderBar.
  /// If null, the native GTK theme default color is used.
  final Color? backgroundColor;

  /// Default height before the native measurement is available.
  /// 47px is the standard Adwaita GTK HeaderBar natural height.
  final double defaultHeight;

  const GtkNativeHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
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
    return Size.fromHeight(Platform.isMacOS ? 52.0 : 47.0);
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
    _height = Platform.isMacOS ? 52.0 : 47.0;
    _ch.addListener(_handleMethodCall);
    _activeInstances.add(this);
    _syncWithNative();
    _fetchNativeHeight();
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

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onHeaderBack':
        if (!mounted) break;
        if (widget.leading != null) {
          widget.leading!.onPressed();
        } else if (widget.onBack != null) {
          widget.onBack!();
        } else {
          Navigator.maybePop(context);
        }
        break;
      case 'onHeaderActionPressed':
        final id = call.arguments?['id'] as String?;
        if (id == null) break;

        if (widget.leading != null && widget.leading!.id == id) {
          widget.leading!.onPressed();
          break;
        }

        if (widget.actions != null) {
          for (final action in widget.actions!) {
            if (action.id == id) {
              action.onPressed();
              break;
            }
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
        'title': widget.title,
        'subtitle': widget.subtitle ?? '',
        'showBackButton': widget.showBackButton,
        'backgroundColor': _colorToCss(widget.backgroundColor) ?? '',
      });

      final allActions = <Map<String, dynamic>>[];
      if (widget.leading != null) {
        final leadingJson = widget.leading!.toJson();
        leadingJson['position'] = 'start';
        allActions.add(leadingJson);
      }
      if (widget.actions != null) {
        allActions.addAll(widget.actions!.map((a) => a.toJson()));
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

  @override
  Widget build(BuildContext context) {
    if (!isNativeControlSupported) {
      Widget? leadingWidget;
      if (widget.leading != null) {
        leadingWidget = IconButton(
          icon: _buildIcon(widget.leading!.iconName) ??
              (widget.leading!.label != null
                  ? Text(widget.leading!.label!)
                  : const Icon(Icons.chevron_left)),
          tooltip: widget.leading!.label,
          onPressed: widget.leading!.onPressed,
        );
      } else if (widget.showBackButton) {
        leadingWidget = IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack ?? () => Navigator.maybePop(context),
        );
      }

      final actionsWidgets = <Widget>[];
      if (widget.actions != null) {
        for (final action in widget.actions!) {
          actionsWidgets.add(
            IconButton(
              icon: _buildIcon(action.iconName) ??
                  (action.label != null
                      ? Text(action.label!)
                      : const Icon(Icons.widgets)),
              tooltip: action.label,
              onPressed: action.onPressed,
            ),
          );
        }
      }

      return AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(widget.title),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
              Text(widget.subtitle!, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        centerTitle: true,
        leading: leadingWidget,
        actions: actionsWidgets,
        backgroundColor: widget.backgroundColor,
      );
    }

    return SizedBox(height: _height);
  }
}
