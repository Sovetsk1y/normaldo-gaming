import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/routing/ng_router.dart';
import 'package:normaldo_gaming/ui/audio/ng_audio_widget.dart';
import 'package:normaldo_gaming/ui/main_screen/main_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      FlutterNativeSplash.remove();
      if (context.read<UserCubit>().state.user.name.isEmpty) {
        context.go(NGRoutes.signUp.path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NgAudioWidget(
      child: BlocListener<UserCubit, UserState>(
        listener: (context, state) {
          if (state.user.name.isEmpty) {
            context.go(NGRoutes.signUp.path);
          }
        },
        child: const MainScreen(),
      ),
    );
  }
}
