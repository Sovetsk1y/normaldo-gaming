import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/ui/missions/missions_list.dart';

class MissionsOnStartOverlay extends StatefulWidget {
  const MissionsOnStartOverlay({super.key});

  @override
  State<MissionsOnStartOverlay> createState() => _MissionsOnStartOverlayState();
}

class _MissionsOnStartOverlayState extends State<MissionsOnStartOverlay> {
  double _left = -1000;

  @override
  void initState() {
    super.initState();

    if (!context.read<UserCubit>().state.educated) return;
    Future.delayed(const Duration(milliseconds: 300)).whenComplete(() {
      setState(() => _left = 16);
      FlameAudio.play('sfx/mission_notification.mp3');
      Future.delayed(const Duration(seconds: 3))
          .whenComplete(() => setState(() => _left = -1000));
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx < 0) {
      setState(() => _left += details.delta.dx);
    }
    if (_left < -100) {
      setState(() {
        _left = -1000;
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_left >= -100) {
      setState(() => _left = 16);
    }
  }

  void _listener(BuildContext context, UserState state) {
    setState(() => _left = 16);
    Future.delayed(const Duration(seconds: 3))
        .whenComplete(() => setState(() => _left = -1000));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const borderSide = BorderSide(
      color: NGTheme.purple3,
      width: 4,
    );
    return BlocListener<UserCubit, UserState>(
      listenWhen: (previous, current) => !previous.educated && current.educated,
      listener: _listener,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: _left,
            width: MediaQuery.of(context).size.width / 2.4,
            child: GestureDetector(
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(child: MissionsList(disabled: true)),
                  Container(
                    decoration: const BoxDecoration(
                        color: NGTheme.purple2,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        border: Border(
                          right: borderSide,
                          top: borderSide,
                          bottom: borderSide,
                        )),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                    child: Text('<', style: textTheme.displayLarge),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
