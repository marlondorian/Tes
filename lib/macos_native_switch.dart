import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_control_channel.dart';
import 'route_observer.dart';

class MacosNativeSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const MacosNativeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<MacosNativeSwitch> createState() => _MacosNativeSwitchState();
}

class _MacosNativeSwitchState extends State<MacosNativeSwitch> with RouteAware {
  final GlobalKey _key = GlobalKey();
  String? _switchId;
  Size? _nativeSize;
  ModalRoute? _modalRoute;

  @override
  void initState() {
    super.initState();
    _switchId = UniqueKey().toString();
    NativeControlChannel.registerListener(_switchId!, _handleNativeMethodCall);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createNativeSwitch();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? route = ModalRoute.of(context);
    if (_modalRoute != route) {
      if (_modalRoute != null) routeObserver.unsubscribe(this);
      _modalRoute = route;
      if (_modalRoute != null) routeObserver.subscribe(this, _modalRoute!);
    }
  }

  Future<void> _createNativeSwitch() async {
    if (!mounted) return;

    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    try {
      final result = await NativeControlChannel.invokeMethod('createSwitch', {
        'id': _switchId,
        'value': widget.value,
        'x': position.dx,
        'y': position.dy,
      });

      if (result is Map) {
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
      debugPrint("Failed to create native switch: '${e.message}'.");
    }
  }

  Future<void> _handleNativeMethodCall(
    String method,
    Map<String, dynamic> arguments,
  ) async {
    if (method == 'onSwitchChanged') {
      final value = arguments['value'] as bool?;
      if (value != null && mounted) {
        widget.onChanged(value);
      }
    }
  }

  Future<void> _updateNativePosition() async {
    if (!mounted || _switchId == null) return;

    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      await NativeControlChannel.invokeMethod('updatePosition', {
        'id': _switchId,
        'x': position.dx,
        'y': position.dy,
      });
    }
  }

  Future<void> _setNativeVisibility(bool visible) async {
    if (_switchId == null) return;
    try {
      await NativeControlChannel.invokeMethod('setVisibility', {
        'id': _switchId,
        'visible': visible,
      });
    } on PlatformException catch (_) {}
  }

  Future<void> _updateNativeValue() async {
    if (!mounted || _switchId == null) return;

    await NativeControlChannel.invokeMethod('updateSwitchValue', {
      'id': _switchId,
      'value': widget.value,
    });
  }

  @override
  void didUpdateWidget(MacosNativeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _updateNativeValue();
    }
  }

  Future<void> _removeNativeSwitch() async {
    if (_switchId == null) return;
    await NativeControlChannel.invokeMethod('removeSwitch', {'id': _switchId});
  }

  @override
  void dispose() {
    if (_modalRoute != null) routeObserver.unsubscribe(this);
    if (_switchId != null) {
      _removeNativeSwitch();
      NativeControlChannel.unregisterListener(_switchId!);
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
  Widget build(BuildContext context) {
    return NativePositionTracker(
      onPositionChanged: _updateNativePosition,
      child: SizedBox(
        key: _key,
        width: _nativeSize?.width ?? 52,
        height: _nativeSize?.height ?? 32,
      ),
    );
  }
}
