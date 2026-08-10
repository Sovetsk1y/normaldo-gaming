final class Config {
  static const _androidAdId = '5387382';
  static const _iosAdId = '5387383';

  Config({
    required this.iosAdId,
    required this.androidAdId,
  });

  Config.dev()
      : androidAdId = _androidAdId,
        iosAdId = _iosAdId;

  Config.prod()
      : androidAdId = _androidAdId,
        iosAdId = _iosAdId;

  final String androidAdId;
  final String iosAdId;
}
