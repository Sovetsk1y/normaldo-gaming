import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/routing/ng_router.dart';
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
      if (context.read<UserCubit>().state.name.isEmpty) {
        context.goRoute(NGRoutes.createUser);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}
