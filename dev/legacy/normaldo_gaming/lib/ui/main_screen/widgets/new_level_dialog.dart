import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/core/widgets/blinking_text.dart';
import 'package:normaldo_gaming/core/widgets/blinking_widget.dart';
import 'package:normaldo_gaming/domain/pull_up_game/entities/reward.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';
import 'package:normaldo_gaming/injection/injection.dart';
import 'package:normaldo_gaming/ui/widgets/ng_button.dart';

class NewLevelDialog extends StatelessWidget {
  const NewLevelDialog({
    required this.reward,
    required this.level,
    super.key,
  });

  final List<Reward> reward;
  final int level;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
            gradient: RadialGradient(
          radius: 0.8,
          colors: [
            Colors.black.withOpacity(0.5),
            Colors.transparent,
          ],
        )),
        child: Column(
          children: [
            BlinkingText(
              'NEW LEVEL!'.tr(),
              duration: const Duration(milliseconds: 500),
              endDelay: const Duration(seconds: 2),
              style: textTheme.displayLarge
                  ?.copyWith(fontSize: 48, color: NGTheme.orange1),
            ),
            const SizedBox(height: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          BlinkingText(
                            'LVL ${level - 1} –> ',
                            duration: const Duration(milliseconds: 500),
                            startDelay: const Duration(milliseconds: 1500),
                            endDelay: const Duration(hours: 2),
                            style: textTheme.displayLarge,
                          ),
                          BlinkingText(
                            '$level',
                            style: textTheme.displayLarge?.copyWith(
                              fontSize: 52,
                              color: NGTheme.green1,
                            ),
                            startDelay: const Duration(seconds: 2),
                            duration: const Duration(milliseconds: 500),
                            endDelay: const Duration(hours: 2),
                          ),
                          if (reward.whereType<RankReward>().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Column(
                                children: [
                                  BlinkingText(
                                    'NEW RANK!'.tr(),
                                    duration: const Duration(milliseconds: 500),
                                    startDelay: const Duration(seconds: 3),
                                    endDelay: const Duration(hours: 2),
                                    style: textTheme.displayMedium,
                                  ),
                                  BlinkingText(
                                    (reward.firstWhere((element) =>
                                                element is RankReward)
                                            as RankReward)
                                        .rank
                                        .tr(),
                                    startDelay: const Duration(seconds: 4),
                                    duration: const Duration(milliseconds: 500),
                                    endDelay: const Duration(hours: 2),
                                    style: textTheme.displayMedium
                                        ?.copyWith(color: NGTheme.purple1),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRewards(context),
                const SizedBox(height: 32),
                BlinkingWidget(
                  duration: const Duration(milliseconds: 500),
                  endDelay: const Duration(hours: 2),
                  startDelay: const Duration(seconds: 3),
                  child: NGButton(
                    onPressed: () => context.pop(),
                    text: 'AIGHT!'.tr(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewards(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlinkingWidget(
      startDelay: const Duration(seconds: 3),
      duration: const Duration(milliseconds: 500),
      endDelay: const Duration(hours: 2),
      child: Column(
        children: [
          Text(
            'Your reward:'.tr(),
            style: textTheme.displayMedium,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: reward
                .where((e) =>
                    e is RankReward ||
                    e is BucksReward ||
                    e is ExtraLiveReward ||
                    e is SkinReward)
                .map((e) => switch (e) {
                      RankReward() => const SizedBox.shrink(),
                      BucksReward() => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Image.asset(
                                'assets/images/dollar.png',
                                width: 40,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                e.amount.toString(),
                                style: textTheme.displayLarge,
                              )
                            ],
                          ),
                        ),
                      ExtraLiveReward() => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Image.asset(
                                  'assets/images/heart.png',
                                  width: 40,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                e.amount.toString(),
                                style: textTheme.displayLarge,
                              )
                            ],
                          ),
                        ),
                      SkinReward() => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            children: [
                              Text(
                                'NEW SKIN!'.tr(),
                                style: textTheme.displayMedium?.copyWith(
                                    color: NGTheme.colorOf(injector
                                        .get<SkinsRepository>(key: 'skins_test')
                                        .getSkinById(e.uniqueId)
                                        .rarity)),
                              ),
                              Image.asset(
                                'assets/images/${injector.get<SkinsRepository>(key: 'skins_test').getSkinById(e.uniqueId).assets.mask}',
                                width: 70,
                              )
                            ],
                          ),
                        ),
                      _ => throw UnexpectedError(),
                    })
                .toList(),
          ),
        ],
      ),
    );
  }
}
