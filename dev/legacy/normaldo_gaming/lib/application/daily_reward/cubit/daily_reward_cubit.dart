import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/roller/roller.dart';
import 'package:ntp/ntp.dart';

part 'daily_reward_state.dart';
part 'daily_reward_cubit.freezed.dart';

class DailyRewardCubit extends HydratedCubit<DailyRewardState> {
  static const dollars100 = 'dollars100';
  static const dollars250 = 'dollars250';
  static const dollars500 = 'dollars500';
  static const heart1 = 'heart1';
  static const heart2 = 'heart2';
  static const heart3 = 'heart3';

  DailyRewardCubit() : super(DailyRewardState.initial()) {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.delay > Duration.zero) {
        emit(state.copyWith(delay: state.delay - const Duration(seconds: 1)));
      }
    });
  }

  final _roller = Roller<String>([
    (dollars100, 60),
    (dollars250, 10),
    (dollars500, 5),
    (heart1, 12),
    (heart2, 5),
    (heart3, 5),
  ]);

  Future<String?> applyAward(UserCubit userCubit) async {
    if (state.canApply) {
      final reward = _roller.roll();
      switch (reward) {
        case dollars100:
          userCubit.addDollars(100);
        case dollars250:
          userCubit.addDollars(250);
        case dollars500:
          userCubit.addDollars(500);
        case heart1:
          userCubit.addExtraLife(1);
        case heart2:
          userCubit.addExtraLife(2);
        case heart3:
          userCubit.addExtraLife(3);
      }
      final currTime = await NTP.now();
      emit(state.copyWith(
        delay: const Duration(hours: 24) -
            Duration(
              hours: currTime.hour,
              minutes: currTime.minute,
              seconds: currTime.second,
            ),
        lastApply: currTime,
      ));
      return reward;
    } else {
      final currTime = await NTP.now();
      if (state.lastApply != null) {
        final lastApply = state.lastApply!;
        final diff = currTime.difference(lastApply);
        if (diff.inDays > 0) {
          emit(state.copyWith(delay: Duration.zero));
        } else {
          emit(state.copyWith(
            // delay: Duration.zero,
            delay: const Duration(hours: 24) -
                Duration(
                  seconds: diff.inSeconds,
                ),
          ));
        }
      }
      return null;
    }
  }

  void reset() {
    emit(DailyRewardState.initial());
  }

  @override
  DailyRewardState? fromJson(Map<String, dynamic> json) {
    return DailyRewardState(
      delay: Duration(seconds: json['delay']),
      currentDay: json['currentDay'],
      lastApply: DateTime.tryParse(json['lastApply']),
    );
  }

  @override
  Map<String, dynamic>? toJson(DailyRewardState state) {
    return {
      'delay': state.delay.inSeconds,
      'currentDay': state.currentDay,
      'lastApply': state.lastApply?.toIso8601String(),
    };
  }
}
