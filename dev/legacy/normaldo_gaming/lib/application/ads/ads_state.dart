part of 'ads_cubit.dart';

@freezed
class AdsState with _$AdsState {
  const factory AdsState.initial() = _Initial;
  const factory AdsState.loading() = _Loading;
  const factory AdsState.failed(
    String errorMessage, {
    void Function()? onComplete,
  }) = _Failed;
  const factory AdsState.readyToShow({
    required String placementId,
    required AdReward reward,
    void Function()? onComplete,
  }) = _ReadyToShow;
}

@freezed
class AdReward with _$AdReward {
  const factory AdReward.noReward() = _NoReward;
  const factory AdReward.bucks(int amount) = _Bucks;
  const factory AdReward.bucksInGame(int amount) = _BucksInGame;
  const factory AdReward.custom(void Function() applyReward) = _Custom;
}
