import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/domain/pull_up_game/mission.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';

class MissionTile extends StatelessWidget {
  final Mission mission;
  final bool showProgress;
  final VoidCallback? onCompletePressed;

  const MissionTile({
    super.key,
    required this.mission,
    this.showProgress = true,
    this.onCompletePressed,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          _buildExp(context),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                mission.when(
                      collectPizza: (exp, completeValue, isOneGame, description,
                              adsViewed, type, currentValue) =>
                          mission.description.plural(completeValue,
                              args: [completeValue.toString()]),
                      crashItem: (exp, completeValue, isOneGame, description,
                              adsViewed, item, type, currentValue) =>
                          mission.description.plural(completeValue,
                              args: [item.name.tr(), completeValue.toString()]),
                      passItem: (exp, completeValue, isOneGame, description,
                              adsViewed, item, type, currentValue) =>
                          mission.description.plural(completeValue,
                              args: [item.name.tr(), completeValue.toString()]),
                      reachLocation: (exp, description, adsViewed,
                              completeValue, isOneGame, type, currentValue) =>
                          mission.description.tr(args: [
                        Utils.locationIndexToString[completeValue]?.tr() ??
                            'UNKNOWN'
                      ]),
                      finishGame: (exp, description, adsViewed, completeValue,
                              isOneGame, type, currentValue) =>
                          mission.description.tr(args: [
                        Utils.locationIndexToString[completeValue]?.tr() ??
                            'UNKNOWN'
                      ]),
                    ) +
                    (showProgress ? ' ${mission.progressText}' : ''),
                style: textTheme.displaySmall?.copyWith(
                    color: mission.completed ? NGTheme.green1 : null)),
          )
        ],
        // ? IconButton(
        //     onPressed: onCompletePressed,
        //     icon: const Icon(
        //       Icons.done,
        //       color: NGTheme.green1,
        //     ))
        // : null,
      ),
    );
  }

  Widget _buildExp(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/pizza_pack1.png',
          fit: BoxFit.cover,
          width: 25,
          height: 25,
        ),
        const SizedBox(width: 8),
        Text(mission.exp.toString(),
            style: textTheme.displayMedium
                ?.copyWith(color: mission.completed ? NGTheme.green1 : null)),
      ],
    );
  }
}
