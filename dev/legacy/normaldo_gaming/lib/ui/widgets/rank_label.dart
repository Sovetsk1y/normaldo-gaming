import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/domain/pull_up_game/level_manager.dart';
import 'package:normaldo_gaming/injection/injection.dart';

class RankLabel extends StatelessWidget {
  RankLabel({super.key, this.style});

  final TextStyle? style;

  final LevelManager _levelManager = injector.get();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<UserCubit, UserState>(builder: (context, state) {
      return Text(_levelManager.rank(state.user).tr(),
          style: style ?? textTheme.displayMedium);
    });
  }
}
