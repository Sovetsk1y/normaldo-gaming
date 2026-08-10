import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/application/mission/mission_cubit.dart';
import 'package:normaldo_gaming/application/slot_machine/cubit/slot_machine_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/core/widgets/blinking_text.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/pull_up_game/level_manager.dart';
import 'package:normaldo_gaming/injection/injection.dart';
import 'package:normaldo_gaming/routing/ng_router.dart';
import 'package:normaldo_gaming/ui/main_screen/widgets/user_level_bar.dart';
import 'package:normaldo_gaming/ui/missions/missions_list.dart';
import 'package:normaldo_gaming/ui/slot_machine/slot_machine_screen.dart';
import 'package:normaldo_gaming/ui/widgets/bouncing_button.dart';

class DeathScreen extends StatefulWidget {
  const DeathScreen({super.key});

  @override
  State<DeathScreen> createState() => _DeathScreenState();
}

class _DeathScreenState extends State<DeathScreen> with HasNgAudio {
  static const _iconDimension = 30.0;

  final _levelManager = injector.get<LevelManager>();

  double _opacity = 0.0;
  bool _ignoring = true;

  @override
  void initState() {
    super.initState();

    audio.playAssetBgm('/audio/death_audio.mp3', loop: true);

    final gameCubit = context.read<GameSessionCubit>();
    final userCubit = context.read<UserCubit>();

    if (gameCubit.state.score > userCubit.state.user.highScore) {
      userCubit.changeHighScore(gameCubit.state.score);
    }
    userCubit.addDollars(gameCubit.state.dollars);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      // await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _opacity = 1.0;
      });
      if (context.read<MissionCubit>().state.missions.any((m) => m.completed)) {
        Future.delayed(const Duration(seconds: 3))
            .whenComplete(() => setState(() => _ignoring = false));
      } else {
        setState(() => _ignoring = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameSessionCubit>();
    return IgnorePointer(
      ignoring: _ignoring,
      child: Scaffold(
        backgroundColor: Colors.black45,
        body: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(seconds: 1),
          child: Stack(
            children: [
              SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildMissions(),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: NGTheme.purple3, width: 3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 8.0,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Column(
                          children: [
                            UserLevelBar(
                              levelManager: _levelManager,
                              barWidth: 180,
                            ),
                            const SizedBox(height: 32.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildScore(context, cubit.state.score),
                                _buildDollars(context, cubit.state.dollars),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildNewRecordText(),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                BouncingButton(
                                  onPressed: () async {
                                    await audio.stopAssetBgm();
                                    context.pop();
                                  },
                                  child: Image.asset(
                                      'assets/images/menu_bubble_button.png'),
                                ),
                                BouncingButton(
                                  onPressed: () async {
                                    await audio.stopAssetBgm();
                                    context.pushReplacement(
                                      NGRoutes.pullUpGame.path,
                                    );
                                  },
                                  child: Image.asset(
                                      'assets/images/retry_bubble_button.png'),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 24,
                bottom: 0,
                child: _buildBuildings(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuildings() {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0)
              .add(const EdgeInsets.only(left: 32.0)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BouncingButton(
                onPressed: () => context.push(NGRoutes.shop.path),
                // onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                //     builder: (context) =>
                //         ShopScreen(injector.get(key: 'skins_test')))),
                child: Image.asset('assets/images/main_screen/shop.png'),
              ),
              BouncingButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => BlocProvider<SlotMachineCubit>(
                          create: (context) => injector.get(),
                          child: const SlotMachineScreen(),
                        ))),
                child: Image.asset('assets/images/main_screen/slots.png'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlots() {
    return BouncingButton(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => BlocProvider<SlotMachineCubit>(
                create: (context) => injector.get(),
                child: const SlotMachineScreen(),
              ))),
      child: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/images/slot_machine.png',
              fit: BoxFit.contain,
            ),
          ),
          Align(
              alignment: const Alignment(-0.005, -0.35),
              child: Image.asset(
                'assets/images/normaldo/normaldo2.png',
                width: 30,
                height: 30,
              ))
        ],
      ),
    );
  }

  Widget _buildNewRecordText() {
    print(
        'CURRENT GAME SCORE: ${context.read<GameSessionCubit>().state.score}');
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<UserCubit, UserState>(builder: (context, state) {
      return Visibility(
        visible:
            state.user.highScore < context.read<GameSessionCubit>().state.score,
        child: BlinkingText(
          'NEW HIGH SCORE!!!',
          style: textTheme.displaySmall?.copyWith(color: NGTheme.green1),
          duration: const Duration(milliseconds: 500),
          endDelay: const Duration(seconds: 1),
        ),
      );
    });
  }

  Widget _buildMissions() {
    return const MissionsList(
      padding: EdgeInsets.symmetric(vertical: 12.0),
    );
  }

  Widget _buildScore(BuildContext context, int score) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/pizza.png',
          height: _iconDimension,
          width: _iconDimension,
        ),
        const SizedBox(width: 8),
        Text(
          score.toString(),
          style: textTheme.displayLarge,
        ),
      ],
    );
  }

  Widget _buildDollars(BuildContext context, int dollars) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Image.asset(
          'assets/images/dollar.png',
          height: _iconDimension,
          width: _iconDimension,
        ),
        const SizedBox(width: 8),
        Text(
          dollars.toString(),
          style: textTheme.displayLarge,
        )
      ],
    );
  }
}
