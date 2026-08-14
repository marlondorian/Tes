import 'package:flutter/services.dart';

/// Centralized dispatcher for [MethodChannel] 'com.example.macos_native_widgets/scaffold'.
///
/// Only one [setMethodCallHandler] is registered on the channel.
/// Listeners subscribe via [addListener] / [removeListener] and receive
/// every incoming [MethodCall]; each listener decides which methods to handle.
class GtkScaffoldChannel {
  GtkScaffoldChannel._();
  static final GtkScaffoldChannel instance = GtkScaffoldChannel._();

  static const _channel = MethodChannel(
    'com.example.macos_native_widgets/scaffold',
  );

  final List<Future<dynamic> Function(MethodCall)> _listeners = [];

  bool _registered = false;

  void addListener(Future<dynamic> Function(MethodCall) listener) {
    _listeners.add(listener);
    _ensureRegistered();
  }

  void removeListener(Future<dynamic> Function(MethodCall) listener) {
    _listeners.remove(listener);
  }

  void _ensureRegistered() {
    if (_registered) return;
    _registered = true;
    _channel.setMethodCallHandler(_dispatch);
  }

  Future<dynamic> _dispatch(MethodCall call) async {
    for (final listener in List.of(_listeners)) {
      await listener(call);
    }
  }

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }
}
