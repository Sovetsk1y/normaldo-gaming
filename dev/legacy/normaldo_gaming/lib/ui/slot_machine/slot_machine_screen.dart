import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/application/slot_machine/cubit/slot_machine_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/components/slot_machine_widget.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/app/audio_pools.dart';
import 'package:normaldo_gaming/domain/roller/rolls.dart';
import 'package:normaldo_gaming/injection/injection.dart';
import 'package:normaldo_gaming/ui/main_screen/widgets/user_level_bar.dart';
import 'package:normaldo_gaming/ui/slot_machine/widgets/bid_widget.dart';
import 'package:normaldo_gaming/ui/slot_machine/widgets/slot_win_dialog.dart';
import 'package:normaldo_gaming/ui/slot_machine/widgets/slots_info_dialog.dart';
import 'package:normaldo_gaming/ui/widgets/bouncing_button.dart';

class SlotMachineScreen extends StatefulWidget {
  const SlotMachineScreen({super.key});

  @override
  State<SlotMachineScreen> createState() => _SlotMachineScreenState();
}

class _SlotMachineScreenState extends State<SlotMachineScreen>
    with SingleTickerProviderStateMixin, HasNgAudio {
  late final SlotMachineController _controller;
  late final _spinAnimationController = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  );

  final _rollItems = <Rolls, RollItem>{
    Rolls.exp1: RollItem(
      index: 0,
      child: Image.asset('assets/images/pizza_pack1.png'),
    ),
    Rolls.exp2: RollItem(
      index: 1,
      child: Image.asset('assets/images/pizza_pack2.png'),
    ),
    Rolls.exp3: RollItem(
      index: 2,
      child: Image.asset('assets/images/pizza_pack3.png'),
    ),
    Rolls.extraLife: RollItem(
      index: 3,
      child: Image.asset('assets/images/heart.png'),
    ),
    Rolls.half1: RollItem(
      index: 4,
      child: Image.asset('assets/images/cocktail.png'),
    ),
    Rolls.win: RollItem(
      index: 5,
      child: Image.asset('assets/images/dollar.png'),
    ),
    Rolls.jackpot: RollItem(
      index: 6,
      child: Image.asset('assets/images/pizza.png'),
    ),
  };

  AudioPlayer? _rollingAudioPlayer;

  dynamic _onCreated(SlotMachineController controller) async {
    _controller = controller;
    Future.delayed(const Duration(milliseconds: 100)).then((value) {
      _controller.start(
          hitRollItemIndex: Random().nextInt(Rolls.values.length));
      _controller.stop(reelIndex: 0);
      _controller.stop(reelIndex: 1);
      _controller.stop(reelIndex: 2);
    });
  }

  void _onInfoPressed() {
    showDialog(context: context, builder: (context) => const SlotsInfoDialog());
  }

  Future<void> _onSpinPressed({required bool spinning}) async {
    if (spinning) return;
    audio.playMenuSfx(MenuSfx.roll, stopPrevious: false);
    _rollingAudioPlayer = await audio.playAssetSfx('audio/rolling.mp3');
    final cubit = context.read<SlotMachineCubit>();
    cubit.roll();
  }

  Future<void> _slotsListener(
      BuildContext context, SlotMachineState state) async {
    final cubit = context.read<SlotMachineCubit>();
    final userCubit = context.read<UserCubit>();

    if (state.winRoll != null) {
      _spinAnimationController.forward();
      final winRoll = state.winRoll!;
      userCubit.takeDollars(state.bid);
      if (state.winRoll == Rolls.empty) {
        _controller.start(hitRollItemIndex: null);
      } else {
        _controller.start(hitRollItemIndex: _rollItems[winRoll]?.index);
      }
      final reelIndexes = [0, 1, 2]..shuffle();
      const rollDropDuration = Duration(milliseconds: 300);
      await Future.delayed(
          Duration(milliseconds: 300 + Random().nextInt(1700)));
      _controller.stop(reelIndex: reelIndexes.removeAt(0));
      await Future.delayed(rollDropDuration);
      await audio.playAssetSfx('audio/sfx/roll_dropped.mp3');
      // await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(200)));
      _controller.stop(reelIndex: reelIndexes.removeAt(0));
      await Future.delayed(rollDropDuration);
      await audio.playAssetSfx('audio/sfx/roll_dropped.mp3');
      // await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(200)));
      _controller.stop(reelIndex: reelIndexes.removeAt(0));
      await Future.delayed(rollDropDuration);
      await audio.playAssetSfx('audio/sfx/roll_dropped.mp3');
      if (_rollingAudioPlayer != null) {
        _rollingAudioPlayer?.stop();
      }
      await Future.delayed(const Duration(milliseconds: 1000));
      cubit.stopSpin();
      _spinAnimationController.reverse();
      if (winRoll != Rolls.empty) {
        // ignore: use_build_context_synchronously
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => SlotWinDialog(
            winRoll: winRoll,
            bid: state.bid,
          ),
        );
      }
      _applyWin(winRoll, state.bid);
    }
  }

  void _applyWin(Rolls winRoll, int bid) {
    final userCubit = context.read<UserCubit>();
    switch (winRoll) {
      case Rolls.empty:
        break;
      case Rolls.exp1:
        userCubit.addExp(1);
      case Rolls.exp2:
        userCubit.addExp(2);
      case Rolls.exp3:
        userCubit.addExp(3);
      case Rolls.extraLife:
        userCubit.addExtraLife(1);
      case Rolls.half1:
        userCubit.addDollars(bid ~/ 2);
      case Rolls.win:
        userCubit.addDollars(bid * 2);
      case Rolls.jackpot:
        userCubit.addDollars(bid * 100);
    }
  }

  @override
  void initState() {
    super.initState();

    audio.pauseBgm();
    audio.playAssetBgm('audio/avtiki.mp3', loop: true);
  }

  @override
  void dispose() {
    audio.stopAssetBgm().then((value) => audio.resumeBgm());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !context.read<SlotMachineCubit>().state.spinning,
      child: BlocListener<SlotMachineCubit, SlotMachineState>(
        listener: _slotsListener,
        listenWhen: (previous, current) => previous.winRoll != current.winRoll,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: BlocBuilder<SlotMachineCubit, SlotMachineState>(
              builder: (context, state) {
            return Container(
              decoration: const BoxDecoration(
                  image: DecorationImage(
                image: AssetImage(
                    'assets/images/backgrounds/slot_machine_screen.png'),
                fit: BoxFit.cover,
              )),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: _buildBackButton(state),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: _buildUserLevel(),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildBottomPanel(state),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildInfoButton(),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: IgnorePointer(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SlotMachineWidget.stacked(
                          shuffle: false,
                          height: 110,
                          width: MediaQuery.of(context).size.width,
                          reelHeight: 300,
                          rollAlignments: constraints.maxWidth > 720
                              ? const [
                                  Alignment(-0.6, 0),
                                  Alignment(-0.01, 0),
                                  Alignment(0.58, 0),
                                ]
                              : const [
                                  Alignment(-0.77, 0),
                                  Alignment(-0.01, 0),
                                  Alignment(0.73, 0),
                                ],
                          reelItemExtent: 100,
                          rollItems: _rollItems.values.toList(),
                          onCreated: _onCreated,
                          onFinished: (resultIndexes) {},
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(SlotMachineState state) {
    final textTheme = Theme.of(context).textTheme;
    const borderSide = BorderSide(
      width: 3,
      color: NGTheme.purple2,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _spinAnimationController,
          builder: (context, child) => Transform.translate(
            offset: const Offset(0, 150) * _spinAnimationController.value,
            child: child,
          ),
          child: Container(
            height: 70,
            padding: const EdgeInsets.only(left: 8, top: 8, right: 8),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(
                left: borderSide,
                top: borderSide,
                right: borderSide,
              ),
            ),
            child: SafeArea(
              left: false,
              right: false,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildExtraLives(),
                  _buildBalance(),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: BidWidget(onBidChanged: (newBid) {
                      context.read<SlotMachineCubit>().changeBid(bid: newBid);
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: context.read<UserCubit>().state.user.dollars < state.bid ||
                  context.read<UserCubit>().state.user.dollars == 0 ||
                  state.bid == 0
              ? null
              : () => _onSpinPressed(spinning: state.spinning),
          child: Container(
            height: 70,
            padding: const EdgeInsets.only(left: 8, top: 16, right: 8),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(
                left: borderSide,
                top: borderSide,
                right: borderSide,
              ),
            ),
            child: SafeArea(
              left: false,
              right: false,
              child: Text(
                'Spin'.tr(),
                style: textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExtraLives() {
    final textTheme = Theme.of(context).textTheme;
    const double side = 20;
    return BlocBuilder<UserCubit, UserState>(
      builder: (context, state) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Image.asset('assets/images/heart.png', width: side, height: side),
            const SizedBox(width: 8),
            SizedBox(
              width: 30,
              child: Text(state.user.extraLives.toString(),
                  style: textTheme.displayMedium),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBalance() {
    const double side = 20;
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<UserCubit, UserState>(builder: (context, state) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Image.asset('assets/images/dollar.png', width: side, height: side),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(state.user.dollars.toString(),
                style: textTheme.displayMedium),
          ),
        ],
      );
    });
  }

  Widget _buildUserLevel() {
    final textTheme = Theme.of(context).textTheme;
    const borderSide = BorderSide(
      width: 3,
      color: NGTheme.purple2,
    );
    return AnimatedBuilder(
      animation: _spinAnimationController,
      builder: (context, child) => Transform.translate(
        offset: const Offset(200, -100) * _spinAnimationController.value,
        child: Transform.rotate(
          angle: pi / 2 * _spinAnimationController.value,
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            .add(const EdgeInsets.only(right: 32)),
        decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(
              bottom: borderSide,
              left: borderSide,
            )),
        child: UserLevelBar(
          levelManager: injector.get(),
          barWidth: 100,
          rankStyle: textTheme.bodySmall,
          iconSize: 20,
        ),
      ),
    );
  }

  Widget _buildInfoButton() {
    final textTheme = Theme.of(context).textTheme;
    return BouncingButton(
      onPressed: _onInfoPressed,
      child: Container(
        padding: const EdgeInsets.only(
          left: 12,
          top: 8,
          bottom: 8,
          right: 32,
        ),
        decoration: const BoxDecoration(
          color: NGTheme.purple2,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(100),
            bottomLeft: Radius.circular(100),
          ),
        ),
        child: Text('?', style: textTheme.displayLarge),
      ),
    );
  }

  Widget _buildBackButton(SlotMachineState state) {
    final textTheme = Theme.of(context).textTheme;
    const borderSide = BorderSide(
      width: 3,
      color: NGTheme.purple2,
    );
    return IgnorePointer(
      ignoring: state.spinning,
      child: AnimatedBuilder(
        animation: _spinAnimationController,
        builder: (context, child) => Transform.translate(
          offset: const Offset(-100, -100) * _spinAnimationController.value,
          child: Transform.rotate(
            alignment: Alignment.topLeft,
            angle: _spinAnimationController.value * -pi / 2,
            child: BouncingButton(
              onPressed: () => context.pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                    color: Colors.black,
                    border: Border(
                      bottom: borderSide,
                      right: borderSide,
                    )),
                child: Padding(
                  padding: const EdgeInsets.only(left: 24, top: 16),
                  child: Text('Exit'.tr(), style: textTheme.displayMedium),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
