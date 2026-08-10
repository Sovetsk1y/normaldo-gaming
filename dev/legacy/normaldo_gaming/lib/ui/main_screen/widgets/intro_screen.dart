import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/routing/ng_router.dart';
import 'package:normaldo_gaming/ui/widgets/ng_button.dart';
import 'package:video_player/video_player.dart';

class IntroScreen extends StatefulWidget {
  final bool leadToGame;
  final String languageCode;

  const IntroScreen({
    super.key,
    required this.languageCode,
    this.leadToGame = true,
  });

  @override
  State<IntroScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<IntroScreen> with HasNgAudio {
  late final VideoPlayerController _controller;

  bool _showButton = false;

  void _skip() {
    _controller.pause();
    _controller.dispose();
    context.pop();
    audio.resumeBgm();
    if (widget.leadToGame) {
      context.pushNamed(NGRoutes.pullUpGame.name);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final path = widget.languageCode.toUpperCase() == 'RU'
        ? 'assets/video/rus_intro.mp4'
        : 'assets/video/eng_intro.mp4';
    _controller = VideoPlayerController.asset(path)
      ..initialize().then((_) {
        _controller.play();
        audio.pauseBgm();
        setState(() {});
        _controller.addListener(() {
          if (_controller.value.isCompleted) {
            _skip();
          }
        });
      });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return PopScope(
      canPop: false,
      child: GestureDetector(
        onTap: () => setState(() => _showButton = !_showButton),
        child: Container(
          height: screenSize.height,
          width: screenSize.width,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_controller.value.isInitialized)
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              else
                Container(),
              Align(
                alignment: const Alignment(0.8, -0.8),
                child: IgnorePointer(
                  ignoring: !_showButton,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _showButton ? 1 : 0,
                    child: NGButton(
                      onPressed: _skip,
                      text: widget.leadToGame ? 'Skip'.tr() : 'Close'.tr(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
