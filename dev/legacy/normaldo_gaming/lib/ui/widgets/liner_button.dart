import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/core/theme.dart';

enum LinerSide { top, right, bottom, left }

class LinerButton extends StatelessWidget {
  const LinerButton({
    super.key,
    required this.side,
    required this.child,
    required this.onPressed,
  });

  final LinerSide side;
  final Widget child;
  final VoidCallback onPressed;

  EdgeInsetsGeometry get _padding => switch (side) {
        LinerSide.left => const EdgeInsets.only(
            top: 8,
            bottom: 8,
            left: 32,
            right: 12,
          ),
        LinerSide.right => const EdgeInsets.only(
            top: 8,
            bottom: 8,
            left: 12,
            right: 32,
          ),
        LinerSide.top => const EdgeInsets.only(
            top: 24,
            bottom: 12,
            left: 8,
            right: 8,
          ),
        LinerSide.bottom => const EdgeInsets.only(
            top: 12,
            bottom: 24,
            left: 8,
            right: 8,
          ),
      };

  BorderRadiusGeometry get _borderRadius => switch (side) {
        LinerSide.left => const BorderRadius.only(
            topRight: Radius.circular(100),
            bottomRight: Radius.circular(100),
          ),
        LinerSide.right => const BorderRadius.only(
            topLeft: Radius.circular(100),
            bottomLeft: Radius.circular(100),
          ),
        LinerSide.top => const BorderRadius.only(
            bottomRight: Radius.circular(100),
            bottomLeft: Radius.circular(100),
          ),
        LinerSide.bottom => const BorderRadius.only(
            topLeft: Radius.circular(100),
            topRight: Radius.circular(100),
          ),
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: _padding,
        decoration: BoxDecoration(
          color: NGTheme.purple2,
          borderRadius: _borderRadius,
        ),
        child: child,
      ),
    );
  }
}

class NGBackButton extends StatelessWidget {
  final LinerSide side;

  const NGBackButton({
    super.key,
    this.side = LinerSide.top,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LinerButton(
      side: side,
      onPressed: () => context.pop(),
      child: Text('<', style: textTheme.displayLarge),
    );
  }
}
