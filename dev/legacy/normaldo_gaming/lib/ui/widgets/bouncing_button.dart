import 'package:flutter/material.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/app/audio_pools.dart';

class BounceScale {
  final double value;

  const BounceScale(this.value)
      : assert(
          value > 0 && value <= 1,
        );

  const BounceScale.iconButton() : value = 0.05;
  const BounceScale.wideWidget() : value = 0.02;
}

class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final BounceScale scale;

  const BouncingButton({
    super.key,
    required this.child,
    this.scale = const BounceScale.wideWidget(),
    this.onPressed,
  });

  @override
  State createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton>
    with SingleTickerProviderStateMixin, HasNgAudio {
  late double _scale;
  late AnimationController _controller;
  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 200,
      ),
      upperBound: widget.scale.value,
    )..addListener(() {
        setState(() {});
      });
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scale = 1 - _controller.value;
    return GestureDetector(
      onTap: () {
        audio.playMenuSfx(MenuSfx.button);
        widget.onPressed?.call();
      },
      child: Listener(
        onPointerDown: (_) => _tapDown(),
        onPointerUp: (_) => _tapUp(),
        child: Transform.scale(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }

  void _tapDown() {
    _controller.forward();
  }

  void _tapUp() {
    _controller.reverse();
  }
}
