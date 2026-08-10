import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/domain/roller/rolls.dart';

class SlotsInfoDialog extends StatelessWidget {
  const SlotsInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: NGTheme.purple3, width: 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 24),
                  child: Text(
                    'WIN ROLLS'.tr(),
                    style: textTheme.displayLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.only(
                        right: 8,
                        left: 8,
                        bottom: 8,
                        top: 24,
                      ),
                      decoration: const BoxDecoration(
                        color: NGTheme.purple3,
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(100),
                          bottomLeft: Radius.circular(100),
                        ),
                      ),
                      child: Text('X', style: textTheme.displayLarge),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24.0, top: 8.0, right: 24.0),
              child: Row(
                children: [
                  Expanded(
                      child: Column(
                    children: [
                      _buildItem(context, Rolls.exp1),
                      _buildItem(context, Rolls.exp2),
                      _buildItem(context, Rolls.exp3),
                    ],
                  )),
                  Expanded(
                      child: Column(
                    children: [
                      _buildItem(context, Rolls.half1),
                      _buildItem(context, Rolls.extraLife),
                      _buildItem(context, Rolls.win),
                    ],
                  )),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: _buildItem(context, Rolls.jackpot),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, Rolls roll) {
    const itemDimension = 24.0;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      title: switch (roll) {
        Rolls.empty => const SizedBox.shrink(),
        Rolls.exp1 => Row(
            children: [
              Image.asset(
                'assets/images/pizza_pack1.png',
                height: itemDimension,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/pizza_pack1.png',
                height: itemDimension,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/pizza_pack1.png',
                height: itemDimension,
              ),
              const SizedBox(width: 16),
              Text('>', style: textTheme.displayMedium),
              const SizedBox(width: 16),
              Text('+1 EXP!', style: textTheme.displayMedium),
            ],
          ),
        Rolls.exp2 => Row(
            children: [
              Image.asset(
                'assets/images/pizza_pack2.png',
                height: itemDimension,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/pizza_pack2.png',
                height: itemDimension,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/pizza_pack2.png',
                height: itemDimension,
              ),
              const SizedBox(width: 16),
              Text('>', style: textTheme.displayMedium),
              const SizedBox(width: 16),
              Text('+2 EXP!', style: textTheme.displayMedium),
            ],
          ),
        Rolls.exp3 => Row(
            children: [
              Image.asset(
                'assets/images/pizza_pack3.png',
                height: itemDimension,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/pizza_pack3.png',
                height: itemDimension,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/pizza_pack3.png',
                height: itemDimension,
              ),
              const SizedBox(width: 16),
              Text('>', style: textTheme.displayMedium),
              const SizedBox(width: 16),
              Text('+3 EXP!', style: textTheme.displayMedium),
            ],
          ),
        Rolls.half1 => Row(
            children: [
              Image.asset(
                'assets/images/cocktail.png',
                height: itemDimension,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/cocktail.png',
                height: itemDimension,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/cocktail.png',
                height: itemDimension,
              ),
              const SizedBox(width: 16),
              Text('>', style: textTheme.displayMedium),
              const SizedBox(width: 16),
              Text('0.5 BID', style: textTheme.displayMedium),
            ],
          ),
        Rolls.extraLife => Row(
            children: [
              Image.asset(
                'assets/images/heart.png',
                height: itemDimension,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/heart.png',
                height: itemDimension,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/heart.png',
                height: itemDimension,
              ),
              const SizedBox(width: 16),
              Text('>', style: textTheme.displayMedium),
              const SizedBox(width: 16),
              Text('+1', style: textTheme.displayMedium),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/heart.png',
                height: itemDimension,
              ),
            ],
          ),
        Rolls.win => Row(
            children: [
              Image.asset(
                'assets/images/dollar.png',
                height: itemDimension,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/dollar.png',
                height: itemDimension,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/dollar.png',
                height: itemDimension,
              ),
              const SizedBox(width: 16),
              Text('>', style: textTheme.displayMedium),
              const SizedBox(width: 16),
              Text('2x BID', style: textTheme.displayMedium),
            ],
          ),
        Rolls.jackpot => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/pizza.png',
                height: itemDimension * 1.5,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/pizza.png',
                height: itemDimension * 1.5,
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/pizza.png',
                height: itemDimension * 1.5,
              ),
              const SizedBox(width: 16),
              Text('>', style: textTheme.displayLarge),
              const SizedBox(width: 16),
              Text('100x BID JACKPOT!!!', style: textTheme.displayLarge),
            ],
          ),
      },
    );
  }
}
