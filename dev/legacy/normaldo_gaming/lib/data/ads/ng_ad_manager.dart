import 'dart:io';

import 'package:normaldo_gaming/core/config/config.dart';
import 'package:normaldo_gaming/domain/ads/ad_manager.dart';

final class AdManager extends BaseAdManager {
  AdManager(this.config);

  final Config config;

  @override
  String get gameId => Platform.isIOS ? config.iosAdId : config.androidAdId;

  @override
  String get interstitialVideoAdPlacementId =>
      Platform.isIOS ? 'Interstitial_iOS' : 'Interstitial_Android';

  @override
  String get rewardedVideoAdPlacementId =>
      Platform.isIOS ? 'Rewarded_iOS' : 'Rewarded_Android';
}
