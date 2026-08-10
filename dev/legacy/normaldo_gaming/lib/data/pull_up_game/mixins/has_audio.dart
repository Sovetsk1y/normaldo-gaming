import 'package:normaldo_gaming/domain/app/audio_pools.dart';
import 'package:normaldo_gaming/injection/injection.dart';

mixin HasNgAudio {
  AudioManager get audio => injector.get();
}
