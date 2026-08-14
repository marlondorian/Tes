import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

typedef NativeControlEventHandler = void Function(String method, Map<String, dynamic> arguments);

class NativeControlChannel {
  static const MethodChannel _channel = MethodChannel('com.example.macos_native_widgets/native');
  static final Map<String, NativeControlEventHandler> _listeners = {};
  static bool _initialized = false;

  static void registerListener(String id, NativeControlEventHandler handler) {
    _ensureHandler();
    _listeners[id] = handler;
  }

  static void unregisterListener(String id) {
    _listeners.remove(id);
  }

  static Future<dynamic> invokeMethod(String method, [dynamic arguments]) {
    return _channel.invokeMethod(method, arguments);
  }

  static void _ensureHandler() {
    if (_initialized) return;
    _channel.setMethodCallHandler(_handleMethodCall);
    _initialized = true;
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    final args = call.arguments as Map<dynamic, dynamic>?;
    final id = args?['id'] as String?;
    if (id == null) {
      return Future.error(PlatformException(code: 'INVALID_ARGS', message: 'Missing id', details: null));
    }

    final handler = _listeners[id];
    if (handler != null) {
      handler(call.method, Map<String, dynamic>.from(args!));
      return null;
    }

    return null;
  }
}

class NativePositionTracker extends SingleChildRenderObjectWidget {
  final VoidCallback onPositionChanged;

  const NativePositionTracker({
    super.key,
    required this.onPositionChanged,
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _NativePositionTrackerRenderBox(
      onPositionChanged: onPositionChanged,
      scrollPosition: Scrollable.maybeOf(context)?.position,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final tracker = renderObject as _NativePositionTrackerRenderBox;
    tracker.onPositionChanged = onPositionChanged;
    tracker.scrollPosition = Scrollable.maybeOf(context)?.position;
  }
}

class _NativePositionTrackerRenderBox extends RenderProxyBox {
  static final Set<_NativePositionTrackerRenderBox> _trackers = <_NativePositionTrackerRenderBox>{};
  static _NativePositionTrackerMetricsObserver? _metricsObserver;

  VoidCallback onPositionChanged;
  ScrollPosition? _scrollPosition;
  bool _scrollListenerAttached = false;
  Offset? _lastGlobalPosition;

  _NativePositionTrackerRenderBox({
    required this.onPositionChanged,
    ScrollPosition? scrollPosition,
  }) : _scrollPosition = scrollPosition {
    _ensureMetricsObserver();
  }

  static void _ensureMetricsObserver() {
    if (_metricsObserver != null) return;
    _metricsObserver = _NativePositionTrackerMetricsObserver();
  }

  set scrollPosition(ScrollPosition? newPosition) {
    if (_scrollPosition == newPosition) return;
    _removeScrollListener();
    _scrollPosition = newPosition;
    _addScrollListener();
  }

  void _addScrollListener() {
    if (_scrollListenerAttached || _scrollPosition == null) return;
    _scrollPosition!.addListener(_handleScroll);
    _scrollListenerAttached = true;
  }

  void _removeScrollListener() {
    if (!_scrollListenerAttached || _scrollPosition == null) return;
    _scrollPosition!.removeListener(_handleScroll);
    _scrollListenerAttached = false;
  }

  void _handleScroll() {
    if (!attached) return;
    _updatePosition();
  }

  void _updatePosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onPositionChanged();
    });
  }

  void _dispatchGlobalLayoutChange() {
    if (!attached) return;
    _updatePosition();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _trackers.add(this);
    _addScrollListener();
  }

  @override
  void detach() {
    _removeScrollListener();
    _trackers.remove(this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!attached) return;
      _updatePosition();
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);

    final globalPosition = localToGlobal(Offset.zero);
    if (_lastGlobalPosition != globalPosition) {
      _lastGlobalPosition = globalPosition;
      _updatePosition();
    }
  }
}

class _NativePositionTrackerMetricsObserver extends WidgetsBindingObserver {
  _NativePositionTrackerMetricsObserver() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    for (final tracker in _NativePositionTrackerRenderBox._trackers) {
      tracker._dispatchGlobalLayoutChange();
    }
  }
}
