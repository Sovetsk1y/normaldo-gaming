import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/domain/roller/rolls.dart';
import 'package:normaldo_gaming/ui/widgets/bouncing_button.dart';

class SlotWinDialog extends StatelessWidget {
  const SlotWinDialog({
    required this.winRoll,
    required this.bid,
    super.key,
  });

  final Rolls winRoll;
  final int bid;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        height: 200,
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NGTheme.green1, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('YOU WIN!!!'.tr(),
                style: textTheme.displayLarge?.copyWith(color: NGTheme.green1)),
            const SizedBox(height: 32),
            _buildWin(context),
            const Spacer(),
            BouncingButton(
              onPressed: () => context.pop(),
              child: Text('OK'.tr(), style: textTheme.displayLarge),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWin(BuildContext context) {
    const iconDimension = 30.0;
    final textTheme = Theme.of(context).textTheme;
    return switch (winRoll) {
      Rolls.empty => Text(
          'Nothing..'.tr(),
          style: textTheme.displayLarge,
        ),
      Rolls.exp1 => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/pizza_pack1.png',
              width: iconDimension,
              height: iconDimension,
            ),
            const SizedBox(width: 8),
            Text('+1 EXP!', style: textTheme.displayLarge),
          ],
        ),
      Rolls.exp2 => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/pizza_pack2.png',
              width: iconDimension,
              height: iconDimension,
            ),
            const SizedBox(width: 8),
            Text('+2 EXP!', style: textTheme.displayLarge),
          ],
        ),
      Rolls.exp3 => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/pizza_pack3.png',
              width: iconDimension,
              height: iconDimension,
            ),
            const SizedBox(width: 8),
            Text('+3 EXP!', style: textTheme.displayLarge),
          ],
        ),
      Rolls.extraLife => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/heart.png',
              width: iconDimension,
              height: iconDimension,
            ),
            const SizedBox(width: 8),
            Text('+ 1', style: textTheme.displayLarge),
          ],
        ),
      Rolls.half1 => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/dollar.png',
              width: iconDimension,
              height: iconDimension,
            ),
            const SizedBox(width: 8),
            Text('+ ${bid ~/ 2}', style: textTheme.displayLarge),
          ],
        ),
      Rolls.win => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/dollar.png',
              width: iconDimension,
              height: iconDimension,
            ),
            const SizedBox(width: 8),
            Text('+ ${bid * 2}', style: textTheme.displayLarge),
          ],
        ),
      Rolls.jackpot => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/dollar.png',
              width: iconDimension,
              height: iconDimension,
            ),
            const SizedBox(width: 8),
            Text('+ ${bid * 100}', style: textTheme.displayLarge),
          ],
        ),
    };
  }
}
