import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:normaldo_gaming/domain/ads/ad_manager.dart';
import 'package:normaldo_gaming/injection/injection.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

part 'ads_state.dart';
part 'ads_cubit.freezed.dart';

enum AdType { interstitial, rewarded }

class AdsCubit extends Cubit<AdsState> {
  AdsCubit() : super(const AdsState.initial());

  @override
  void onChange(Change<AdsState> change) {
    print(change);
    super.onChange(change);
  }

  void reset() {
    emit(const AdsState.initial());
  }

  Future<void> showAd({
    required AdType type,
    required AdReward reward,
    void Function()? onComplete,
  }) async {
    emit(const AdsState.loading());
    final manager = injector.get<BaseAdManager>();
    return UnityAds.load(
        placementId: manager.interstitialVideoAdPlacementId,
        onComplete: (placementId) {
          emit(AdsState.readyToShow(
            placementId: placementId,
            reward: reward,
            onComplete: onComplete,
          ));
        },
        onFailed: (placementId, error, errorMessage) {
          emit(AdsState.failed(
            errorMessage,
            onComplete: onComplete,
          ));
        });
  }
}
