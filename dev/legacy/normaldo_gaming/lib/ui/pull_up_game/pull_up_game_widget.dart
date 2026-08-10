import 'package:easy_localization/easy_localization.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/application/ads/ads_cubit.dart';
import 'package:normaldo_gaming/application/education/cubit/education_cubit.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
import 'package:normaldo_gaming/application/mission/mission_cubit.dart';
import 'package:normaldo_gaming/application/pre_death/pre_death_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/app/audio_pools.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';
import 'package:normaldo_gaming/game/utils/overlays.dart';
import 'package:normaldo_gaming/injection/injection.dart';
import 'package:normaldo_gaming/snowfall_widget/snowfall_widget.dart';
import 'package:normaldo_gaming/ui/ads_widget/ads_widget.dart';
import 'package:normaldo_gaming/ui/education/education_overlay.dart';
import 'package:normaldo_gaming/ui/missions/notification_overlay.dart';
import 'package:normaldo_gaming/ui/pull_up_game/widgets/missions_on_start_overlay.dart';
import 'package:normaldo_gaming/ui/pull_up_game/widgets/pause_menu.dart';
import 'package:normaldo_gaming/ui/pull_up_game/widgets/pre_death_screen.dart';

class PullUpGameWidget extends StatefulWidget {
  const PullUpGameWidget({super.key});

  @override
  State<PullUpGameWidget> createState() => _PullUpGameWidgetState();
}

class _PullUpGameWidgetState extends State<PullUpGameWidget>
    with WidgetsBindingObserver, HasNgAudio {
  bool _canPlay = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cubit = context.read<GameSessionCubit>();
    switch (state) {
      case AppLifecycleState.detached:
        if (!cubit.state.isDead) {
          context.read<MissionCubit>().resetAllProgress();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (cubit.state.isDead) {
          break;
        }
        if (!cubit.state.paused) {
          cubit.togglePause();
        }
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    final sfxPools = injector.get<AudioPools>();
    if (!sfxPools.initialized) {
      sfxPools.init(context.read<UserCubit>().state.skin).whenComplete(() {
        setState(() {
          _canPlay = true;
        });
      }).catchError((e) {
        final textTheme = Theme.of(context).textTheme;
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
          // ignore: prefer_interpolation_to_compose_strings
          'Cannot load game'.tr() + '. $e',
          style: textTheme.displayMedium,
        )));
      });
    } else {
      _canPlay = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdsWidget(
      child: PopScope(
        canPop: false,
        child: !_canPlay
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : EducationOverlay(
                child: Stack(
                  children: [
                    GameWidget(
                      game: PullUpGame(
                        gameSessionCubit: context.read<GameSessionCubit>(),
                        levelBloc: context.read<LevelBloc>(),
                        userCubit: context.read(),
                        missionCubit: context.read(),
                        educationCubit: context.read<EducationCubit>(),
                        sfxPools: injector.get(),
                        adsCubit: context.read<AdsCubit>(),
                      ),
                      overlayBuilderMap: {
                        Overlays.pauseMenu.name: (context, game) =>
                            const PauseMenu(),
                        Overlays.deathScreen.name: (context, game) =>
                            BlocProvider<PreDeathCubit>(
                              create: (context) => injector.get(),
                              child: const PreDeathScreen(),
                            ),
                        Overlays.snowfall.name: (context, PullUpGame game) =>
                            const IgnorePointer(
                              child: SnowfallWidget(
                                isRunning: true,
                                totalSnow: 100,
                                speed: 0.2,
                                maxRadius: 4,
                                snowColor: Colors.white,
                              ),
                            ),
                        Overlays.missions.name: (context, PullUpGame game) =>
                            const MissionsOnStartOverlay(),
                      },
                    ),
                    const IgnorePointer(child: MissionNotificationOverlay())
                  ],
                ),
              ),
      ),
    );
  }
}
