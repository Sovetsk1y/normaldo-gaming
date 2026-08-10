part of 'daily_reward_cubit.dart';

@freezed
class DailyRewardState with _$DailyRewardState {
  const DailyRewardState._();

  const factory DailyRewardState({
    required Duration delay,
    required int currentDay,
    DateTime? lastApply,
  }) = _DailyRewardState;

  bool get canApply => delay == Duration.zero;

  factory DailyRewardState.initial() => const DailyRewardState(
        delay: Duration.zero,
        currentDay: 0,
      );
}
