import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gtk_scaffold_channel.dart';
import 'native_control_channel.dart';

/// Manages GTK Theme extraction and provides a dynamic [ThemeData] that updates
/// automatically whenever the GTK system theme changes.
class GtkThemeManager extends ChangeNotifier {
  GtkThemeManager._() {
    if (isNativeControlSupported) {
      GtkScaffoldChannel.instance.addListener(_handleMethodCall);
      _fetchInitialTheme();
    }
  }

  static final GtkThemeManager instance = GtkThemeManager._();

  double _headerBarHeight = 47.0;
  bool _isDark = true;
  ThemeData _themeData = _buildFallbackTheme(isDark: true);

  double get headerBarHeight => _headerBarHeight;
  bool get isDark => _isDark;
  ThemeData get themeData => _themeData;

  Future<void> _fetchInitialTheme() async {
    try {
      final res = await GtkScaffoldChannel.instance.invokeMethod<Map>('getGtkTheme');
      if (res != null) {
        _applyGtkThemeMap(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      debugPrint('Failed to fetch initial GTK theme: $e');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onGtkThemeChanged') {
      final args = call.arguments;
      if (args is Map) {
        _applyGtkThemeMap(Map<String, dynamic>.from(args));
      }
    }
  }

  void _applyGtkThemeMap(Map<String, dynamic> map) {
    final windowBgStr = map['windowBg'] as String?;
    final windowFgStr = map['windowFg'] as String?;
    final baseBgStr = map['baseBg'] as String?;
    final baseFgStr = map['baseFg'] as String?;
    final selectedBgStr = map['selectedBg'] as String?;
    final selectedFgStr = map['selectedFg'] as String?;
    final isDark = map['isDark'] as bool? ?? true;
    final hHeight = (map['headerBarHeight'] as num?)?.toDouble() ?? 47.0;

    final windowBg = _parseCssColor(windowBgStr) ?? (isDark ? const Color(0xFF0F0B1A) : const Color(0xFFF6F6F6));
    final windowFg = _parseCssColor(windowFgStr) ?? (isDark ? Colors.white : Colors.black);
    final baseBg = _parseCssColor(baseBgStr) ?? (isDark ? const Color(0xFF1E1B2E) : Colors.white);
    final baseFg = _parseCssColor(baseFgStr) ?? (isDark ? Colors.white : Colors.black);
    final selectedBg = _parseCssColor(selectedBgStr) ?? const Color(0xFFA855F7);
    final selectedFg = _parseCssColor(selectedFgStr) ?? Colors.white;

    _isDark = isDark;
    _headerBarHeight = hHeight;

    final brightness = isDark ? Brightness.dark : Brightness.light;

    _themeData = ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: windowBg,
      cardColor: baseBg,
      primaryColor: selectedBg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: selectedBg,
        onPrimary: selectedFg,
        secondary: selectedBg,
        onSecondary: selectedFg,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: baseBg,
        onSurface: baseFg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: baseBg,
        foregroundColor: baseFg,
        elevation: 0,
      ),
      useMaterial3: true,
    );

    notifyListeners();
  }

  static Color? _parseCssColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    try {
      if (colorStr.startsWith('rgba(') && colorStr.endsWith(')')) {
        final content = colorStr.substring(5, colorStr.length - 1);
        final parts = content.split(',');
        if (parts.length == 4) {
          final r = int.parse(parts[0].trim());
          final g = int.parse(parts[1].trim());
          final b = int.parse(parts[2].trim());
          final a = double.parse(parts[3].trim());
          return Color.fromRGBO(r, g, b, a);
        }
      } else if (colorStr.startsWith('#')) {
        String hex = colorStr.substring(1);
        if (hex.length == 6) hex = 'FF$hex';
        if (hex.length == 8) {
          return Color(int.parse(hex, radix: 16));
        }
      }
    } catch (_) {}
    return null;
  }

  static ThemeData _buildFallbackTheme({required bool isDark}) {
    final bg = isDark ? const Color(0xFF0F0B1A) : const Color(0xFFF6F6F6);
    final primary = const Color(0xFFA855F7);
    final brightness = isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: primary,
      ),
      useMaterial3: true,
    );
  }
}
