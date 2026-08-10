import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';

class SoundVolumeWidget extends StatefulWidget {
  const SoundVolumeWidget({super.key});

  @override
  State<SoundVolumeWidget> createState() => _SoundVolumeWidgetState();
}

class _SoundVolumeWidgetState extends State<SoundVolumeWidget> with HasNgAudio {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Music'.tr(),
                style: textTheme.displayMedium,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Slider(
                value: audio.bgmVolume,
                activeColor: NGTheme.purple2,
                onChanged: (volume) {
                  setState(() {
                    audio.setBgmVolume(volume);
                  });
                },
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'SFX',
                style: textTheme.displayMedium,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Slider(
                value: audio.sfxVolume,
                activeColor: NGTheme.purple2,
                onChanged: (volume) {
                  setState(() {
                    audio.setSfxVolume(volume);
                  });
                },
              ),
            ),
          ],
        )
      ],
    );
  }
}
