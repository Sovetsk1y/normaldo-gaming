import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:normaldo_gaming/application/mission/mission_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/domain/pull_up_game/mission.dart';
import 'package:normaldo_gaming/ui/pull_up_game/widgets/mission_tile.dart';

class MissionsList extends StatefulWidget {
  static const startDelay = Duration(seconds: 2);

  final bool showProgress;
  final bool disabled;
  final bool showHeader;
  final EdgeInsets? padding;

  const MissionsList({
    super.key,
    this.showProgress = true,
    this.disabled = false,
    this.showHeader = true,
    this.padding,
  });

  @override
  State<MissionsList> createState() => _MissionsListState();
}

class _MissionsListState extends State<MissionsList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  late List<Mission> missions;

  void _completer() {
    const animDur = Duration(milliseconds: 300);
    List<Mission> completedMissions =
        missions.where((element) => element.completed).toList();
    List<int> indexes =
        completedMissions.map((e) => missions.indexOf(e)).toList();
    if (completedMissions.isNotEmpty) {
      for (final mission in completedMissions) {
        final index = missions.toList().indexOf(mission);
        // indexes.add(index);
        final removedItem = missions.removeAt(index);
        context.read<UserCubit>().addExp(removedItem.exp);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => SizeTransition(
            sizeFactor: animation,
            child: MissionTile(
              mission: removedItem,
              showProgress: false,
            ),
          ),
          duration: animDur,
        );
      }
      if (indexes.isNotEmpty) {
        Future.delayed(animDur).whenComplete(
          () {
            _rearrange(indexes);
          },
        );
      }
    }
  }

  void _rearrange(List<int> newIndexes) {
    for (final index in newIndexes) {
      missions.insert(
          index,
          context.read<MissionCubit>().generateNewMission(
                missions.map((e) => e.type).toSet(),
              ));
      _listKey.currentState?.insertItem(index);
    }
    if (!widget.disabled) {
      context.read<MissionCubit>().updateMissions(missions);
    }
  }

  void _completeMissionAt(int index) {
    final newMissions = List<Mission>.from(missions);
    final mission = newMissions.removeAt(index);
    // final first = newMissions.removeAt(0);
    // final second = newMissions.removeAt(1);
    // final third = newMissions.removeAt(1);
    newMissions.insert(
        index, mission.copyWith(currentValue: mission.completeValue));
    // newMissions.insert(1, second.copyWith(currentValue: second.completeValue));
    // newMissions.insert(2, third.copyWith(currentValue: third.completeValue));
    setState(() {
      missions = newMissions;
      _completer();
    });
  }

  @override
  void initState() {
    super.initState();

    final cubit = context.read<MissionCubit>();
    missions = cubit.state.missions.toList();
    if (missions.length < 3) {
      missions.addAll(List.generate(
          3 - missions.length,
          (index) => cubit.generateNewMission(
                missions.map((e) => e.type).toSet(),
              )));
      cubit.updateMissions(missions);
    }

    if (!widget.disabled) {
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        if (cubit.state.missions.any((element) => element.completed)) {
          Future.delayed(MissionsList.startDelay)
              .whenComplete(() => _completer());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      color: NGTheme.purple2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: NGTheme.purple3,
            width: 4,
          )),
      child: Padding(
        padding: widget.padding ?? const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Text(
                  'Missions'.tr(),
                  style: textTheme.displayMedium,
                ),
              ),
            AnimatedList(
                key: _listKey,
                initialItemCount: missions.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index, animation) {
                  final mission = missions.toList()[index];
                  return SizeTransition(
                    sizeFactor: animation,
                    child: MissionTile(
                      mission: mission,
                      showProgress: widget.showProgress,
                      onCompletePressed: () {
                        _completeMissionAt(index);
                      },
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }
}
