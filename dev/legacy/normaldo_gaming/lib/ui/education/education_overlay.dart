import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:normaldo_gaming/application/education/cubit/education_cubit.dart';
import 'package:normaldo_gaming/core/theme.dart';

class EducationOverlay extends StatelessWidget {
  final Widget child;
  final bool fromBottom;

  EducationOverlay({
    super.key,
    required this.child,
    this.fromBottom = true,
  });

  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screenSize = MediaQuery.of(context).size;
    return Material(
      color: Colors.transparent,
      child: BlocBuilder<EducationCubit, EducationState>(
          builder: (context, state) {
        return SizedBox(
          width: screenSize.width,
          height: screenSize.height,
          child: Stack(
            children: [
              child,
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                left: 0,
                right: 0,
                top: fromBottom
                    ? null
                    : state.map(
                        idle: (_) => -screenSize.height, message: (_) => 0),
                bottom: fromBottom
                    ? state.map(
                        idle: (_) => -screenSize.height, message: (_) => 0)
                    : null,
                child: IgnorePointer(
                  ignoring: false,
                  child: Container(
                    key: _key,
                    decoration:
                        BoxDecoration(color: NGTheme.purple3.withOpacity(0.87)),
                    padding: const EdgeInsets.all(16.0),
                    child: SafeArea(
                      top: !fromBottom,
                      bottom: fromBottom,
                      child: AnimatedTextKit(
                        displayFullTextOnTap: true,
                        stopPauseOnTap: true,
                        animatedTexts: [
                          TypewriterAnimatedText(
                            state.maybeMap(
                              message: (state) => state.message,
                              orElse: () => '',
                            ),
                            speed: const Duration(milliseconds: 90),
                            cursor: r'$',
                            textStyle: textTheme.displayMedium,
                          ),
                        ],
                        key: ValueKey(state.maybeMap(
                          message: (state) => state.message,
                          orElse: () => '',
                        )),
                        onFinished: state.map(
                            idle: (_) => null,
                            message: (state) => state.onTypeWritingFinished),
                        isRepeatingAnimation: false,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
