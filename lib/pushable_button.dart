library pushable_button;

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A widget to show a "3D" pushable button
class PushableButton extends StatefulWidget {
  const PushableButton({
    Key? key,
    required this.child,
    required this.hslColor,
    this.minHeight = 48.0,
    this.elevation = 8.0,
    this.borderRadius,
    this.outline = false,
    this.onPressed,
  })  : assert(minHeight > 0),
        super(key: key);

  /// child widget (normally a Text or Icon)
  final Widget child;

  /// Color of the top layer
  /// The color of the bottom layer is derived by decreasing the luminosity by 0.15
  final HSLColor hslColor;

  /// Chiều cao tối thiểu của button
  final double minHeight;

  /// elevation or "gap" between the top and bottom layer
  final double elevation;

  /// An optional shadow to make the button look better
  /// This is added to the bottom layer only

  /// An optional border radius of the button corners
  /// If no border radius is provided, the button will use [StadiumBorder]
  final double? borderRadius;

  final bool outline;

  /// button pressed callback
  final VoidCallback? onPressed;

  @override
  _PushableButtonState createState() => _PushableButtonState();
}

class _PushableButtonState extends State<PushableButton> {
  final GlobalKey _key = GlobalKey();
  double? _childHeight;

  @override
  void initState() {
    super.initState();
    _scheduleChildHeightUpdate();
  }

  void _scheduleChildHeightUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateChildHeight();
    });
  }

  void _updateChildHeight() {
    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    setState(() => _childHeight = renderBox.size.height);
  }

  @override
  Widget build(BuildContext context) {
    final minHeight = widget.minHeight;
    return Stack(
      children: [
        // This is a dummy container to get the height of the child
        Opacity(opacity: 0, child: Container(key: _key, child: widget.child)),
        // The actual pushable button
        _AnimatedPushableButton(
          child: widget.child,
          actualHeight: math.max(_childHeight ?? minHeight, minHeight),
          elevation: widget.elevation,
          hslColor: widget.hslColor,
          borderRadius: widget.borderRadius,
          outline: widget.outline,
          onPressed: widget.onPressed,
        ),
      ],
    );
  }
}

class _AnimatedPushableButton extends StatefulWidget {
  const _AnimatedPushableButton({
    required this.child,
    required this.actualHeight,
    required this.elevation,
    required this.hslColor,
    required this.outline,
    this.borderRadius,
    this.onPressed,
  });

  final Widget child;
  final double actualHeight;
  final double elevation;
  final HSLColor hslColor;
  final double? borderRadius;
  final bool outline;
  final VoidCallback? onPressed;

  @override
  State<_AnimatedPushableButton> createState() =>
      _AnimatedPushableButtonState();
}

class _AnimatedPushableButtonState extends State<_AnimatedPushableButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  bool _isDragging = false;
  Offset? _dragOffset;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 50),
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null) _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    _animationController.reverse();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    if (widget.onPressed == null) return;
    _animationController.reverse();
  }

  void _handleDragStart(DragStartDetails details) {
    if (widget.onPressed == null) return;
    setState(() {
      _isDragging = true;
      _dragOffset = details.localPosition;
    });
    _animationController.forward(from: 0.0);
  }

  void _handleDragEnd(DragEndDetails details, Size buttonSize) {
    if (widget.onPressed == null) return;
    setState(() {
      _isDragging = false;
      _dragOffset = null;
    });
    _animationController.reverse();

    final buttonRect = Offset.zero & buttonSize;
    if (buttonRect.contains(_dragOffset ?? Offset.zero)) {
      widget.onPressed?.call();
    }
  }

  void _handleDragCancel() {
    if (widget.onPressed == null) return;
    setState(() {
      _isDragging = false;
      _dragOffset = null;
    });
    _animationController.reverse();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isDragging) setState(() => _dragOffset = details.localPosition);
  }

  @override
  Widget build(BuildContext context) {
    final totalHeight = widget.actualHeight + widget.elevation;
    final buttonSize = Size(MediaQuery.of(context).size.width, totalHeight);

    return SizedBox(
      height: totalHeight,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onHorizontalDragStart: _handleDragStart,
        onHorizontalDragEnd: (details) => _handleDragEnd(details, buttonSize),
        onHorizontalDragCancel: _handleDragCancel,
        onHorizontalDragUpdate: _handleDragUpdate,
        onVerticalDragStart: _handleDragStart,
        onVerticalDragEnd: (details) => _handleDragEnd(details, buttonSize),
        onVerticalDragCancel: _handleDragCancel,
        onVerticalDragUpdate: _handleDragUpdate,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return _ButtonLayers(
              top: _animationController.value * widget.elevation,
              totalHeight: totalHeight,
              actualHeight: widget.actualHeight,
              hslColor: widget.hslColor,
              child: widget.child,
              borderRadius: widget.borderRadius,
              outline: widget.outline,
            );
          },
        ),
      ),
    );
  }
}

class _ButtonLayers extends StatelessWidget {
  const _ButtonLayers({
    required this.top,
    required this.totalHeight,
    required this.actualHeight,
    required this.hslColor,
    required this.child,
    this.borderRadius,
    required this.outline,
  });

  final double top;
  final double totalHeight;
  final double actualHeight;
  final HSLColor hslColor;
  final Widget child;
  final double? borderRadius;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final bottomHslColor = hslColor.withLightness(hslColor.lightness - 0.15);

    return Stack(
      children: [
        // Bottom layer
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: totalHeight - top,
            decoration: BoxDecoration(
              color: bottomHslColor.toColor(),
              borderRadius: BorderRadius.circular(borderRadius ?? 0),
            ),
          ),
        ),
        // Top layer
        Positioned(
          left: 0,
          right: 0,
          top: top,
          child: Container(
            height: actualHeight,
            decoration: borderRadius != null
                ? BoxDecoration(
                    border: outline
                        ? Border(
                            right: BorderSide(
                              width: 1.5,
                              color: bottomHslColor.toColor(),
                            ),
                            left: BorderSide(
                              width: 1.5,
                              color: bottomHslColor.toColor(),
                            ),
                            top: BorderSide(
                              width: 1.5,
                              color: bottomHslColor.toColor(),
                            ),
                            bottom: BorderSide.none,
                          )
                        : null,
                    color: hslColor.toColor(),
                    borderRadius: BorderRadius.circular(borderRadius ?? 0),
                  )
                : ShapeDecoration(
                    color: hslColor.toColor(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius ?? 0),
                    ),
                  ),
            child: Center(child: child),
          ),
        ),
      ],
    );
  }
}
