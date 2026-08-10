import 'package:flame/components.dart';

final class AudioFadeComponent extends TimerComponent {
  AudioFadeComponent({required super.onTick})
      : super(
          period: 0.5,
          repeat: true,
        );
}
