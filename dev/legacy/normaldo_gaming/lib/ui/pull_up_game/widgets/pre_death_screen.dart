import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/application/pre_death/pre_death_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/core/widgets/blinking_text.dart';
import 'package:normaldo_gaming/domain/ads/ad_manager.dart';
import 'package:normaldo_gaming/injection/injection.dart';
import 'package:normaldo_gaming/ui/pull_up_game/widgets/death_screen.dart';
import 'package:normaldo_gaming/ui/widgets/bouncing_button.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class PreDeathScreen extends StatefulWidget {
  const PreDeathScreen({super.key});

  @override
  State<PreDeathScreen> createState() => _PreDeathScreenState();
}

class _PreDeathScreenState extends State<PreDeathScreen> {
  double _opacity = 0.0;

  void _cubitListener(BuildContext context, PreDeathState state) {}

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      // await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _opacity = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<PreDeathCubit>();
    return BlocConsumer<PreDeathCubit, PreDeathState>(
        listener: _cubitListener,
        builder: (context, state) {
          if (state.skipped) return const DeathScreen();
          if (state.adState is Finished) {
            return Scaffold(
              backgroundColor: Colors.black87,
              body: Center(
                  child: Text(
                'Get ready...'.tr(),
                style: textTheme.displayLarge,
              )),
            );
          }
          return Scaffold(
            backgroundColor: NGTheme.bgSemiBlack,
            body: AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(seconds: 1),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: NGTheme.purple3, width: 3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAccountRevives(),
                          Visibility(
                              visible: !context
                                  .read<GameSessionCubit>()
                                  .state
                                  .revivedWithAd,
                              child: const SizedBox(width: 32)),
                          Visibility(
                            visible: !context
                                .read<GameSessionCubit>()
                                .state
                                .revivedWithAd,
                            child: BouncingButton(
                              onPressed: () async {
                                final placementId = injector
                                    .get<BaseAdManager>()
                                    .rewardedVideoAdPlacementId;
                                cubit.setAdState(Loading());
                                await UnityAds.load(
                                    placementId: placementId,
                                    onComplete: (placementId) {
                                      cubit.setAdState(Showing());
                                      UnityAds.showVideoAd(
                                          placementId: placementId,
                                          onStart: (placementId) =>
                                              cubit.setAdState(Showing()),
                                          onClick: (placementId) => print(
                                              'Video Ad $placementId click'),
                                          onSkipped: (placementId) =>
                                              cubit.skip(),
                                          onComplete: (placementId) async {
                                            cubit.setAdState(Finished());
                                            await Future.delayed(
                                                const Duration(seconds: 2));
                                            context
                                                .read<GameSessionCubit>()
                                                .revive(withAd: true);
                                            cubit.setAdState(Initial());
                                          },
                                          onFailed:
                                              (placementId, error, message) =>
                                                  cubit.skip());
                                    },
                                    onFailed:
                                        (placementId, error, errorMessage) {
                                      cubit.skip();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                        errorMessage,
                                        style: textTheme.displayMedium,
                                      )));
                                    });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/tv.png',
                                    width: 70,
                                    height: 70,
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('+ 1',
                                          style: textTheme.displaySmall),
                                      const SizedBox(width: 8),
                                      Image.asset('assets/images/heart.png',
                                          width: 20)
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0.3, 0),
                    child: _buildSkipButton(state.skipValue),
                  ),
                  Visibility(
                    visible: state.adState == Loading(),
                    child: Container(
                      color: Colors.black54,
                      child: Center(
                        child: BlinkingText(
                          'Loading your Ad...',
                          duration: const Duration(seconds: 1),
                          style: textTheme.displayMedium,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        });
  }

  Widget _buildAccountRevives() {
    final textTheme = Theme.of(context).textTheme;
    return Opacity(
      opacity: context.read<UserCubit>().state.user.extraLives == 0 ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: context.read<UserCubit>().state.user.extraLives == 0,
        child: BouncingButton(
          onPressed: () {
            if (context.read<UserCubit>().state.user.extraLives == 0) return;
            context.read<UserCubit>().takeExtraLife(1);
            context.read<GameSessionCubit>().revive();
          },
          child: BlocBuilder<UserCubit, UserState>(
            builder: (context, state) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/heart.png',
                  width: 40,
                  height: 40,
                ),
                Text(state.user.extraLives.toString(),
                    style: textTheme.displaySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton(double skipValue) {
    final textTheme = Theme.of(context).textTheme;
    return BouncingButton(
      onPressed: () => context.read<PreDeathCubit>().skip(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: SizedBox(
              height: 50,
              width: 50,
              child: Stack(
                children: [
                  CircularProgressIndicator(
                    color: NGTheme.purple1,
                    value: skipValue,
                  ),
                  Positioned.fill(
                    top: 11,
                    left: 11,
                    child: Text(
                      '>>',
                      style: textTheme.displaySmall,
                    ),
                  )
                ],
              ),
            ),
          ),
          Text('Skip', style: textTheme.displaySmall)
        ],
      ),
    );
  }
}
