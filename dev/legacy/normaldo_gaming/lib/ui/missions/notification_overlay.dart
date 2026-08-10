import 'package:easy_localization/easy_localization.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:normaldo_gaming/application/mission/mission_cubit.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/domain/pull_up_game/mission.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';

class MissionNotificationOverlay extends StatefulWidget {
  const MissionNotificationOverlay({super.key});

  @override
  State<MissionNotificationOverlay> createState() =>
      _MissionNotificationState();
}

class _MissionNotificationState extends State<MissionNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController animationController;
  late final Animation<Offset> translateAnimation;
  late final Animation<double> opacityAnimation;

  Mission? _lastCompleted;

  void _cubitListener(BuildContext context, MissionState state, int index) {
    final mission = state.missions.toList()[index];
    _lastCompleted = mission;
    animationController.forward().whenComplete(() {
      FlameAudio.play('sfx/mission_notification.mp3');
      Future.delayed(const Duration(seconds: 2)).whenComplete(
        () => animationController.reverse(),
      );
    });
  }

  bool _listenWhen(
    MissionState previous,
    MissionState current,
    int index,
  ) {
    return !previous.missions.toList()[index].completed &&
        current.missions.toList()[index].completed;
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    translateAnimation = Tween<Offset>(
      begin: const Offset(0, -200),
      end: const Offset(0, 32),
    ).animate(animationController);
    opacityAnimation =
        Tween<double>(begin: 0.5, end: 1).animate(animationController);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<MissionCubit, MissionState>(
            listenWhen: (previous, current) =>
                _listenWhen(previous, current, 0),
            listener: (context, state) => _cubitListener(context, state, 0)),
        BlocListener<MissionCubit, MissionState>(
            listenWhen: (previous, current) =>
                _listenWhen(previous, current, 1),
            listener: (context, state) => _cubitListener(context, state, 1)),
        BlocListener<MissionCubit, MissionState>(
            listenWhen: (previous, current) =>
                _listenWhen(previous, current, 2),
            listener: (context, state) => _cubitListener(context, state, 2)),
      ],
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
          ),
          AnimatedBuilder(
              animation: translateAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: translateAnimation.value,
                  child: _buildNotification(),
                );
              }),
        ],
      ),
    );
  }

  Widget _buildNotification() {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
          animation: opacityAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: opacityAnimation.value,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                decoration: BoxDecoration(
                    color: NGTheme.purple2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: NGTheme.purple3,
                      width: 4,
                    )),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'МИССИЯ ВЫПОЛНЕНА!',
                      style: textTheme.displayMedium,
                    ),
                    Text(
                      _lastCompleted?.when(
                            collectPizza: (exp,
                                    completeValue,
                                    isOneGame,
                                    description,
                                    adsViewed,
                                    type,
                                    currentValue) =>
                                _lastCompleted?.description.plural(
                                    completeValue,
                                    args: [completeValue.toString()]),
                            crashItem: (exp,
                                    completeValue,
                                    isOneGame,
                                    description,
                                    adsViewed,
                                    item,
                                    type,
                                    currentValue) =>
                                _lastCompleted?.description
                                    .plural(completeValue, args: [
                              item.name.tr(),
                              completeValue.toString()
                            ]),
                            passItem: (exp,
                                    completeValue,
                                    isOneGame,
                                    description,
                                    adsViewed,
                                    item,
                                    type,
                                    currentValue) =>
                                _lastCompleted?.description
                                    .plural(completeValue, args: [
                              item.name.tr(),
                              completeValue.toString()
                            ]),
                            reachLocation: (exp,
                                    description,
                                    adsViewed,
                                    completeValue,
                                    isOneGame,
                                    type,
                                    currentValue) =>
                                _lastCompleted?.description.tr(args: [
                              Utils.locationIndexToString[completeValue]
                                      ?.tr() ??
                                  'UNKNOWN'
                            ]),
                            finishGame: (exp,
                                    description,
                                    adsViewed,
                                    completeValue,
                                    isOneGame,
                                    type,
                                    currentValue) =>
                                _lastCompleted?.description.tr(args: [
                              Utils.locationIndexToString[completeValue]
                                      ?.tr() ??
                                  'UNKNOWN'
                            ]),
                          ) ??
                          '',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }),
    );
  }
}
