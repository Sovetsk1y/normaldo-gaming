import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:normaldo_gaming/application/ads/ads_cubit.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/ui/widgets/earn_dollars_dialog.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdsWidget extends StatefulWidget {
  const AdsWidget({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AdsWidget> createState() => _AdsWidgetState();
}

class _AdsWidgetState extends State<AdsWidget>
    with SingleTickerProviderStateMixin {
  late final Animation<double> rotationAnimation;
  late final AnimationController rotationAnimationController;

  void _blocListener(BuildContext context, AdsState state) {
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<AdsCubit>();
    state.maybeWhen(
      readyToShow: (placementId, rewardType, onComplete) {
        UnityAds.showVideoAd(
          placementId: placementId,
          onSkipped: (_) {
            cubit.reset();
          },
          onComplete: (placementId) {
            rewardType.maybeWhen(
              bucks: (amount) {
                context.read<UserCubit>().addDollars(amount);
                showDialog(
                        context: context,
                        builder: (context) => EarnDollarsDialog(amount: amount))
                    .then((value) => onComplete?.call());
              },
              bucksInGame: (amount) {
                context.read<GameSessionCubit>().addDollars(amount);
                showDialog(
                        context: context,
                        builder: (context) => EarnDollarsDialog(amount: amount))
                    .then((value) => onComplete?.call());
              },
              custom: (applyReward) {
                applyReward();
              },
              orElse: () {},
            );
            cubit.reset();
          },
          onFailed: (placementId, error, errorMessage) {
            cubit.reset();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
              '${'Cannot show a video ad'.tr()}!\n$errorMessage',
              style: textTheme.displayMedium,
            )));
          },
        );
      },
      failed: (errorMessage, onComplete) {
        cubit.reset();
        onComplete?.call();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
          '${'Cannot load a video ad'.tr()}!\n$errorMessage',
          style: textTheme.displayMedium,
        )));
      },
      orElse: () {},
    );
  }

  @override
  void initState() {
    rotationAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    rotationAnimationController.repeat();
    rotationAnimation = Tween<double>(begin: 0, end: 2 * pi)
        .animate(rotationAnimationController);
    super.initState();
  }

  @override
  void dispose() {
    rotationAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdsCubit, AdsState>(
      listener: _blocListener,
      builder: (context, state) {
        return Stack(
          children: [
            widget.child,
            _buildOverlay(state),
          ],
        );
      },
    );
  }

  Widget _buildOverlay(AdsState state) {
    return state.maybeWhen(
      initial: () => const SizedBox.shrink(),
      loading: () => _buildLoading(),
      orElse: () => _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: AnimatedBuilder(
          animation: rotationAnimation,
          builder: (context, child) => Transform.rotate(
            angle: rotationAnimation.value,
            child: child,
          ),
          child: Image.asset(
            'assets/images/hourglass.png',
            width: 70,
            height: 70,
          ),
        ),
      ),
    );
  }
}
