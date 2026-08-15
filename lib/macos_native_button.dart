import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_control_channel.dart';
import 'route_observer.dart';

class MacosNativeButton extends StatefulWidget {
  final String title;
  final VoidCallback onPressed;

  const MacosNativeButton({
    super.key,
    required this.title,
    required this.onPressed,
  });

  @override
  State<MacosNativeButton> createState() => _MacosNativeButtonState();
}

class _MacosNativeButtonState extends State<MacosNativeButton> with RouteAware {
  static const MethodChannel _channel = MethodChannel('com.example.macos_native_widgets/button');
  
  String? _buttonId;
  Size? _nativeSize;
  ModalRoute? _modalRoute;
  
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (!isNativeControlSupported) return;
    _buttonId = UniqueKey().toString();
    
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onButtonPressed') {
        final id = call.arguments['id'] as String;
        if (id == _buttonId) {
          widget.onPressed();
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createNativeButton();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isNativeControlSupported) return;
    final ModalRoute? route = ModalRoute.of(context);
    if (_modalRoute != route) {
      if (_modalRoute != null) routeObserver.unsubscribe(this);
      _modalRoute = route;
      if (_modalRoute != null) routeObserver.subscribe(this, _modalRoute!);
    }
  }

  Future<void> _createNativeButton() async {
    if (!mounted || !isNativeControlSupported) return;
    
    final RenderBox? renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    try {
      final result = await _channel.invokeMethod('createButton', {
        'id': _buttonId,
        'title': widget.title,
        'x': position.dx,
        'y': position.dy,
      });

      if (result != null && mounted) {
        setState(() {
          _nativeSize = Size(
            (result['width'] as num).toDouble(),
            (result['height'] as num).toDouble(),
          );
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateNativePosition();
        });
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to create native button: '${e.message}'.");
    }
  }

  void _updateNativePosition() {
    if (!mounted || _buttonId == null || !isNativeControlSupported) return;
    final RenderBox? renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      _channel.invokeMethod('updatePosition', {
        'id': _buttonId,
        'x': position.dx,
        'y': position.dy,
      });
    }
  }

  Future<void> _setNativeVisibility(bool visible) async {
    if (_buttonId == null || !isNativeControlSupported) return;
    try {
      await _channel.invokeMethod('setVisibility', {'id': _buttonId, 'visible': visible});
    } on PlatformException catch (_) {}
  }

  @override
  void dispose() {
    if (_modalRoute != null) routeObserver.unsubscribe(this);
    if (_buttonId != null && isNativeControlSupported) {
      _channel.invokeMethod('removeButton', {'id': _buttonId});
    }
    super.dispose();
  }

  @override
  void didPushNext() {
    _setNativeVisibility(false);
  }

  @override
  void didPopNext() {
    _setNativeVisibility(true);
  }

  @override
  void didUpdateWidget(MacosNativeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (!isNativeControlSupported) {
      return ElevatedButton(
        onPressed: widget.onPressed,
        child: Text(widget.title),
      );
    }
    return NativePositionTracker(
      onPositionChanged: _updateNativePosition,
      child: SizedBox(
        key: _key,
        width: _nativeSize?.width ?? 0,
        height: _nativeSize?.height ?? 0,
      ),
    );
  }
}
