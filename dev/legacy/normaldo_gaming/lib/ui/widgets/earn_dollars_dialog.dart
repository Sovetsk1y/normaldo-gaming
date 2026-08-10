import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/core/theme.dart';

import 'bouncing_button.dart';

class EarnDollarsDialog extends StatelessWidget {
  const EarnDollarsDialog({required this.amount, super.key});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 200,
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
            Text('Buy success!'.tr(),
                textAlign: TextAlign.center,
                style: textTheme.displayLarge?.copyWith(color: NGTheme.green1)),
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('+ $amount', style: textTheme.displayLarge),
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/dollar.png',
                  height: 30,
                )
              ],
            ),
            const SizedBox(height: 32),
            BouncingButton(
              onPressed: () => context.pop(),
              child: Text('OK'.tr(), style: textTheme.displayLarge),
            )
          ],
        ),
      ),
    );
  }
}
