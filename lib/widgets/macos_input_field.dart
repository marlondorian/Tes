import 'package:flutter/material.dart';
import '../gtk/native_control_channel.dart';
import '../pages/route_observer.dart';

typedef InputCallback = void Function(String value);

class MacosInputField extends StatefulWidget {
  final String? placeholder;
  final InputCallback? onInput;
  final InputCallback? onSubmit;
  final String? initialValue;
  final double? width;
  final double? height;

  const MacosInputField({
    super.key,
    this.placeholder,
    this.onInput,
    this.onSubmit,
    this.initialValue,
    this.width,
    this.height,
  });

  @override
  State<MacosInputField> createState() => _MacosInputFieldState();
}

class _MacosInputFieldState extends State<MacosInputField> with RouteAware {
  String? _inputId;
  Size? _nativeSize;
  ModalRoute? _modalRoute;
  TextEditingController? _controller;

  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (!isNativeControlSupported) {
      _controller = TextEditingController(text: widget.initialValue);
      return;
    }

    _inputId = UniqueKey().toString();
    NativeControlChannel.registerListener(_inputId!, _handleNativeEvent);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createNativeInput();
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

  Future<void> _createNativeInput() async {
    if (!mounted || _inputId == null || !isNativeControlSupported) return;

    final RenderBox? renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    try {
      // Prefer explicit widget width/height if provided, otherwise use measured renderBox size.
      final measured = renderBox?.size ?? Size(200, 24);
      final sendSize = Size(widget.width ?? measured.width, widget.height ?? measured.height);
      final result = await NativeControlChannel.invokeMethod('createInput', {
        'id': _inputId,
        'text': widget.initialValue ?? '',
        'x': position.dx,
        'y': position.dy,
        'width': sendSize.width,
        'height': sendSize.height,
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
    } catch (e) {
      debugPrint('Failed to create native input: $e');
    }
  }

  void _handleNativeEvent(String method, Map<String, dynamic> args) {
    if (method == 'onInput') {
      final value = args['value'] as String? ?? '';
      if (widget.onInput != null) widget.onInput!(value);
    } else if (method == 'onSubmit') {
      final value = args['value'] as String? ?? '';
      if (widget.onSubmit != null) widget.onSubmit!(value);
    }
  }

  void _updateNativePosition() {
    if (!mounted || _inputId == null || !isNativeControlSupported) return;
    final RenderBox? renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final measured = renderBox.size;
      final sendSize = Size(widget.width ?? measured.width, widget.height ?? measured.height);
      NativeControlChannel.invokeMethod('updatePosition', {
        'id': _inputId,
        'x': position.dx,
        'y': position.dy,
        'width': sendSize.width,
        'height': sendSize.height,
      });
    }
  }

  Future<void> _setNativeVisibility(bool visible) async {
    if (_inputId == null || !isNativeControlSupported) return;
    try {
      await NativeControlChannel.invokeMethod('setVisibility', {'id': _inputId, 'visible': visible});
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (_modalRoute != null) routeObserver.unsubscribe(this);
    if (_inputId != null && isNativeControlSupported) {
      NativeControlChannel.invokeMethod('removeInput', {'id': _inputId});
      NativeControlChannel.unregisterListener(_inputId!);
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
    final width = widget.width ?? _nativeSize?.width ?? 200;
    final height = widget.height ?? _nativeSize?.height ?? 34;

    if (!isNativeControlSupported) {
      return SizedBox(
        width: width,
        height: height,
        child: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.placeholder,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onChanged: widget.onInput,
          onSubmitted: widget.onSubmit,
        ),
      );
    }

    return NativePositionTracker(
      onPositionChanged: _updateNativePosition,
      child: SizedBox(
        key: _key,
        width: width,
        height: height,
        child: const SizedBox.shrink(),
      ),
    );
  }
}
