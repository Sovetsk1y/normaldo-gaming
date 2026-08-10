import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/domain/pull_up_game/entities/reward.dart';
import 'package:normaldo_gaming/domain/pull_up_game/level_manager.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';
import 'package:normaldo_gaming/injection/injection.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ThePath extends StatefulWidget {
  const ThePath({super.key});

  @override
  State<ThePath> createState() => _ThePathState();
}

class _ThePathState extends State<ThePath> {
  final _levelManager = injector.get<LevelManager>();
  final _itemScrollController = ItemScrollController();

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _itemScrollController.jumpTo(
        index: context.read<UserCubit>().state.user.level - 1,
        alignment: 0.5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScrollablePositionedList.builder(
        shrinkWrap: true,
        reverse: true,
        itemScrollController: _itemScrollController,
        itemCount: _levelManager.levelUpRewards.length,
        itemBuilder: (context, index) {
          final reward = _levelManager.levelUpRewards[index];
          return _buildChild(context, reward, index);
        });
  }

  Widget _buildChild(BuildContext context, List<Reward> reward, int index) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: .5),
      height: 67,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment:
            index == 0 ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Spacer(),
              if (reward.any(
                  (element) => element is TextReward || element is RankReward))
                _buildTextAndRank(reward, index, textTheme),
              if (reward.any((element) =>
                  element is SkinReward ||
                  element is BucksReward ||
                  element is ExtraLiveReward))
                _buildSkinBucksLivesReward(reward),
              const Spacer(),
            ],
          ),
          const SizedBox(width: 16),
          Stack(
            alignment: index == 0
                ? const Alignment(0, -0.4)
                : index == _levelManager.levelUpRewards.length - 1
                    ? const Alignment(0, 0.4)
                    : const Alignment(0, 0),
            children: [
              if (index == 0 ||
                  index == _levelManager.levelUpRewards.length - 1)
                Transform.translate(
                  offset: Offset(0.5, 15 * (index == 0 ? -1 : 1)),
                  child: _buildPathPart(index),
                )
              else
                _buildPathPart(index),
              Text((index + 1).toString(), style: textTheme.labelMedium),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkinBucksLivesReward(List<Reward> reward) {
    const dimension = 25.0;
    return Row(
      children: reward
          .where((e) =>
              e is BucksReward || e is ExtraLiveReward || e is SkinReward)
          .map((reward) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: switch (reward) {
                  BucksReward() => Image.asset(
                      'assets/images/dollar.png',
                      width: dimension,
                    ),
                  ExtraLiveReward() => Image.asset(
                      'assets/images/heart.png',
                      width: dimension,
                    ),
                  SkinReward() => Image.asset(
                      Utils.maskImagePath(reward.uniqueId),
                      height: 40,
                    ),
                  _ => throw UnexpectedError(),
                },
              ))
          .toList(),
    );
  }

  Widget _buildTextAndRank(
      List<Reward> reward, int index, TextTheme textTheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: reward
          .where((element) => element is TextReward || element is RankReward)
          .map((reward) => switch (reward) {
                TextReward() => Text(
                    reward.text.tr(),
                    style: textTheme.displaySmall,
                    textAlign: TextAlign.end,
                  ),
                RankReward() => Text(
                    reward.rank.tr(),
                    style: textTheme.displaySmall,
                    textAlign: TextAlign.end,
                  ),
                _ => throw UnexpectedError(),
              })
          .toList(),
    );
  }

  Widget _buildPathPart(int index) {
    return BlocBuilder<UserCubit, UserState>(builder: (context, state) {
      final user = state.user;
      if (index == 0) {
        return Image.asset('assets/images/ui/the_path/end_path_active.png');
      }
      if (index == _levelManager.levelUpRewards.length - 1) {
        if (user.level == _levelManager.levelUpRewards.length) {
          return Image.asset('assets/images/ui/the_path/start_path_active.png');
        } else {
          return Image.asset(
              'assets/images/ui/the_path/start_path_inactive.png');
        }
      }
      if (index > 0 && index < _levelManager.levelUpRewards.length) {
        if (user.level >= index + 1) {
          return Image.asset(
              'assets/images/ui/the_path/middle_path_active.png');
        } else {
          return Image.asset(
              'assets/images/ui/the_path/middle_path_inactive.png');
        }
      }
      throw UnexpectedError();
    });
  }
}

class PathRewardTile extends StatelessWidget {
  const PathRewardTile({super.key, required this.reward});

  final Reward reward;

  @override
  Widget build(BuildContext context) {
    return const Row();
  }
}
