import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:normaldo_gaming/application/daily_reward/cubit/daily_reward_cubit.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/core/widgets/blinking_text.dart';
import 'package:normaldo_gaming/core/widgets/blinking_widget.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';

class TrashBinScreen extends StatefulWidget {
  const TrashBinScreen({super.key});

  @override
  State<TrashBinScreen> createState() => _TrashBinScreenState();
}

class _TrashBinScreenState extends State<TrashBinScreen> {
  String? _reward;

  @override
  void initState() {
    context.read<DailyRewardCubit>().applyAward(context.read()).then((value) {
      setState(() {
        _reward = value;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: BlocConsumer<DailyRewardCubit, DailyRewardState>(
          listener: (context, state) {
        if (state.canApply) {
          context
              .read<DailyRewardCubit>()
              .applyAward(context.read())
              .then((value) {
            setState(() {
              _reward = value;
            });
          });
        }
      }, builder: (context, state) {
        if (_reward == null && state.canApply) {
          return Center(
            child: Text(
              'Opening lid...'.tr(),
              style: textTheme.displayMedium,
            ),
          );
        }
        if (_reward == null && !state.canApply) {
          return Center(
            child: Text(
              state.delay.toString().split('.').first,
              style: textTheme.displayLarge,
            ),
          );
        }
        if (_reward != null) {
          return Column(
            children: [
              const SizedBox(height: 32),
              BlinkingText(
                'SUCCESS!!!'.tr(),
                duration: const Duration(milliseconds: 500),
                endDelay: const Duration(seconds: 2),
                style: textTheme.displayLarge?.copyWith(
                  fontSize: 48,
                  color: NGTheme.green3,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BlinkingWidget(
                  startDelay: const Duration(seconds: 1),
                  endDelay: const Duration(hours: 2),
                  duration: const Duration(milliseconds: 500),
                  child: Column(
                    children: [
                      Text('You found:'.tr(), style: textTheme.displayLarge),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            Utils.imagePathFromDailyReward(_reward!),
                            height: 50,
                            width: 50,
                          ),
                          const SizedBox(width: 16),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              Utils.amountFromDailyReward(_reward!),
                              style: textTheme.displayLarge
                                  ?.copyWith(fontSize: 42),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        throw UnexpectedError();
      }),
    );
  }
}
