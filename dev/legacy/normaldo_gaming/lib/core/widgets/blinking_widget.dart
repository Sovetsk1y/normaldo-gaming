import 'dart:async';

import 'package:flutter/material.dart';

class BlinkingWidget extends StatefulWidget {
  const BlinkingWidget({
    required this.child,
    required this.duration,
    this.startDelay,
    this.endDelay,
    super.key,
  });

  final Widget child;
  final Duration duration;
  final Duration? startDelay;
  final Duration? endDelay;

  @override
  State<BlinkingWidget> createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<BlinkingWidget> {
  Timer? _timer;
  double _opacity = 0.0;

  Future<void> _timerHandler(Timer timer) async {
    if (mounted) {
      setState(() {
        _opacity = _opacity == 1 ? 0 : 1;
      });
    }
    if (widget.endDelay != null) {
      if (_opacity == 1) {
        timer.cancel();
        await Future.delayed(widget.endDelay!);
        _timer = Timer.periodic(
          widget.duration,
          _timerHandler,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.startDelay != null) {
      Future.delayed(widget.startDelay!).whenComplete(() {
        _timer = Timer.periodic(widget.duration, _timerHandler);
      });
    } else {
      _timer = Timer.periodic(widget.duration, _timerHandler);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: widget.duration,
      child: widget.child,
    );
  }
}
