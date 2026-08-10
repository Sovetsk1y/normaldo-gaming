import 'package:flutter/material.dart';

class ListWheelScrollViewX extends StatelessWidget {
  final Widget Function(BuildContext, int) builder;
  final Axis scrollDirection;
  final FixedExtentScrollController? controller;
  final double itemExtent;
  final double diameterRatio;
  final void Function(int)? onSelectedItemChanged;
  final int itemCount;
  const ListWheelScrollViewX({
    super.key,
    required this.builder,
    required this.itemExtent,
    required this.itemCount,
    this.controller,
    this.onSelectedItemChanged,
    this.scrollDirection = Axis.vertical,
    this.diameterRatio = 100000,
  });

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: scrollDirection == Axis.horizontal ? 3 : 0,
      child: ListWheelScrollView.useDelegate(
        onSelectedItemChanged: onSelectedItemChanged,
        controller: controller,
        itemExtent: itemExtent,
        renderChildrenOutsideViewport: true,
        clipBehavior: Clip.none,
        diameterRatio: diameterRatio,
        physics: const FixedExtentScrollPhysics(),
        squeeze: 0.9,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, index) {
            return RotatedBox(
              quarterTurns: scrollDirection == Axis.horizontal ? 1 : 0,
              child: builder(context, index),
            );
          },
        ),
      ),
    );
  }
}
