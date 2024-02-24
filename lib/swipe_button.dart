import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

enum SwipePosition {
  swipeLeft,
  swipeRight,
}

class SwipeButton extends StatefulWidget {
  const SwipeButton({
    super.key,
    this.thumb,
    this.content,
    this.text,
    this.isRTL = false,
    BorderRadius? borderRadius,
    this.initialPosition = SwipePosition.swipeLeft,
    required this.onChanged,
    this.height = 56.0,
    this.width,
    this.backgroundColor,
    this.thumbColor,
    this.onTap,
  })  : assert(initialPosition != null && onChanged != null && height != null),
        borderRadius = borderRadius ?? BorderRadius.zero;

  final Widget? thumb;
  final Widget? content;
  final Widget? text;
  final BorderRadius borderRadius;
  final double? height;
  final double? width;
  final Color? backgroundColor;
  final Color? thumbColor;
  final bool isRTL;
  final SwipePosition? initialPosition;
  final VoidCallback? onChanged;
  final VoidCallback? onTap;

  @override
  SwipeButtonState createState() => SwipeButtonState();
}

class SwipeButtonState extends State<SwipeButton> with SingleTickerProviderStateMixin {
  final GlobalKey _containerKey = GlobalKey();
  final GlobalKey _positionedKey = GlobalKey();

  AnimationController? _controller;
  Animation<double>? _contentAnimation;
  Offset _start = Offset.zero;

  RenderBox? get _positioned => _positionedKey.currentContext?.findRenderObject() as RenderBox;

  RenderBox? get _container => _containerKey.currentContext?.findRenderObject() as RenderBox;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _contentAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOut));
    if (widget.initialPosition == SwipePosition.swipeRight) {
      _controller?.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        key: _containerKey,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: widget.borderRadius,
            ),
            child: Stack(
              children: [
                Center(
                  child: widget.text,
                ),
                ClipRRect(
                  clipper: _SwipeButtonClipper(
                    isRTL: widget.isRTL,
                    animation: _controller!,
                    borderRadius: widget.borderRadius,
                  ),
                  borderRadius: widget.borderRadius,
                  child: SizedBox.expand(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 0),
                      child: FadeTransition(opacity: _contentAnimation!, child: widget.content),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _controller!,
            builder: (BuildContext context, Widget? child) {
              return Align(
                alignment: Alignment(widget.isRTL ? ((_controller?.value)! * -2.0) + 1.0 : ((_controller?.value)! * 2.0) - 1.0, 0.0),
                child: child,
              );
            },
            child: GestureDetector(
              onTap: widget.onTap,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: Container(
                key: _positionedKey,
                width: widget.height,
                height: widget.height,
                decoration: BoxDecoration(
                  color: widget.thumbColor,
                  borderRadius: widget.borderRadius,
                ),
                child: Transform.rotate(angle: widget.isRTL ? math.pi : 0, child: widget.thumb),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    final pos = _positioned?.globalToLocal(details.globalPosition);
    _start = Offset(pos!.dx, 0.0);
    _controller?.stop(canceled: true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final pos = _container!.globalToLocal(details.globalPosition) - _start;
    final extent = _container!.size.width - _positioned!.size.width;
    _controller!.value = widget.isRTL ? 1 - (pos.dx.clamp(0.0, extent) / extent) : (pos.dx.clamp(0.0, extent) / extent);
    if (_controller!.value > 0.85) {
      HapticFeedback.heavyImpact();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final extent = _container!.size.width - _positioned!.size.width;
    var fractionalVelocity = (details.primaryVelocity! / extent).abs();
    if (fractionalVelocity < 0.5) {
      fractionalVelocity = 0.5;
    }
    SwipePosition result;
    double acceleration, velocity;
    if (_controller!.value > 0.85) {
      acceleration = 0.5;
      velocity = fractionalVelocity;
      result = SwipePosition.swipeRight;
    } else {
      acceleration = -0.5;
      velocity = (-fractionalVelocity * 4) / 5;
      result = SwipePosition.swipeLeft;
    }
    final simulation = _SwipeSimulation(
      acceleration,
      _controller!.value,
      1.0,
      velocity,
    );
    _controller?.animateWith(simulation).then((_) {
      if (widget.onChanged != null) {
        if (result == SwipePosition.swipeRight) {
          widget.onChanged!();
        }
        _controller!.value = 0;
      }
    });
  }
}

class _SwipeSimulation extends GravitySimulation {
  _SwipeSimulation(super.acceleration, super.distance, super.endDistance, super.velocity);

  @override
  double x(double time) => super.x(time).clamp(0.0, 1.0);

  @override
  bool isDone(double time) {
    final y = x(time).abs();
    return y <= 0.0 || y >= 1.0;
  }
}

class _SwipeButtonClipper extends CustomClipper<RRect> {
  const _SwipeButtonClipper({
    required this.isRTL,
    required this.animation,
    required this.borderRadius,
  })  : assert(animation != null && borderRadius != null),
        super(reclip: animation);
  final bool isRTL;
  final Animation<double>? animation;
  final BorderRadius? borderRadius;

  @override
  RRect getClip(Size size) {
    return borderRadius!.toRRect(
      isRTL
          ? Rect.fromLTRB(
              0.0,
              0.0,
              size.width * (1 - animation!.value),
              size.height,
            )
          : Rect.fromLTRB(
              size.width * animation!.value,
              0.0,
              size.width,
              size.height,
            ),
    );
  }

  @override
  bool shouldReclip(_SwipeButtonClipper oldClipper) => true;
}
