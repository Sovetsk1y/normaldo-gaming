import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/application/ads/ads_cubit.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
import 'package:normaldo_gaming/application/shop_items_list/shop_items_list_cubit.dart';
import 'package:normaldo_gaming/application/sign_in/sign_in_cubit.dart';
import 'package:normaldo_gaming/application/sign_up/sign_up_cubit.dart';
import 'package:normaldo_gaming/application/slot_machine/cubit/slot_machine_cubit.dart';
import 'package:normaldo_gaming/injection/injection.dart';
import 'package:normaldo_gaming/ui/audio/ng_audio_widget.dart';
import 'package:normaldo_gaming/ui/auth/sign_in_screen.dart';
import 'package:normaldo_gaming/ui/auth/sign_up_screen.dart';
import 'package:normaldo_gaming/ui/base_screen/base_screen.dart';
import 'package:normaldo_gaming/ui/knowledge_book/knowledge_book_screen.dart';
import 'package:normaldo_gaming/ui/main_screen/main_screen.dart';
import 'package:normaldo_gaming/ui/main_screen/missions_screen.dart';
import 'package:normaldo_gaming/ui/pull_up_game/pull_up_game_widget.dart';
import 'package:normaldo_gaming/ui/root/root_screen.dart';
import 'package:normaldo_gaming/ui/settings/settings_screen.dart';
import 'package:normaldo_gaming/ui/shop/shop_screen.dart';
import 'package:normaldo_gaming/ui/slot_machine/slot_machine_screen.dart';

part 'utils/go_route_ext.dart';
part 'utils/ng_routes.dart';

abstract class NGRouter {
  static final router = GoRouter(
    debugLogDiagnostics: true,
    observers: [AudioObserver()],
    initialLocation: NGRoutes.root.path,
    routes: [
      GoRoute(
          path: NGRoutes.root.path,
          name: NGRoutes.root.name,
          builder: (context, state) => const RootScreen(),
          routes: [
            GoRoute(
                path: NGRoutes.main.name,
                name: NGRoutes.main.name,
                builder: (context, state) => const MainScreen(),
                routes: [
                  GoRoute(
                    path: NGRoutes.pullUpGame.name,
                    name: NGRoutes.pullUpGame.name,
                    builder: (context, state) => MultiBlocProvider(
                      providers: [
                        BlocProvider<GameSessionCubit>(
                            create: (context) => injector.get()),
                        BlocProvider<LevelBloc>(
                            create: (context) => injector.get()),
                        BlocProvider<AdsCubit>(
                            create: (context) => injector.get()),
                      ],
                      child: const PullUpGameWidget(),
                    ),
                  ),
                  GoRoute(
                    path: NGRoutes.missions.name,
                    name: NGRoutes.missions.name,
                    pageBuilder: (context, state) => CustomTransitionPage(
                      key: state.pageKey,
                      child: const MissionsScreen(),
                      transitionDuration: const Duration(milliseconds: 300),
                      reverseTransitionDuration:
                          const Duration(milliseconds: 300),
                      opaque: false,
                      barrierColor: Colors.transparent,
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        final tween = Tween<double>(begin: 0, end: 1);
                        final fadeAnimation = animation.drive(tween);

                        return FadeTransition(
                          opacity: fadeAnimation,
                          child: child,
                        );
                      },
                    ),
                  ),
                  GoRoute(
                    path: NGRoutes.settings.name,
                    name: NGRoutes.settings.name,
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: NGRoutes.slots.name,
                    name: NGRoutes.slots.name,
                    builder: (context, state) => BlocProvider<SlotMachineCubit>(
                        create: (context) => injector.get(),
                        child: const SlotMachineScreen()),
                  ),
                  GoRoute(
                    path: NGRoutes.shop.name,
                    name: NGRoutes.shop.name,
                    builder: (context, state) => MultiBlocProvider(providers: [
                      BlocProvider<ShopItemsListCubit>(
                          create: (context) => injector.get()..loadList()),
                      BlocProvider<AdsCubit>(
                          create: (context) => injector.get()),
                    ], child: ShopScreen(injector.get(key: 'skins_test'))),
                  ),
                  GoRoute(
                    path: NGRoutes.knowledgeBook.name,
                    name: NGRoutes.knowledgeBook.name,
                    builder: (context, state) => const KnowledgeBookScreen(),
                  ),
                  GoRoute(
                    path: NGRoutes.basement.name,
                    name: NGRoutes.basement.name,
                    builder: (context, state) => const BaseScreen(),
                  ),
                ]),
            GoRoute(
                path: NGRoutes.signUp.name,
                name: NGRoutes.signUp.name,
                builder: (context, state) => BlocProvider<SignUpCubit>(
                      create: (context) => injector.get(),
                      child: const SignUpScreen(),
                    ),
                routes: [
                  GoRoute(
                    path: NGRoutes.signIn.name,
                    name: NGRoutes.signIn.name,
                    builder: (context, state) => BlocProvider<SignInCubit>(
                      create: (context) => injector.get(),
                      child: const SignInScreen(),
                    ),
                  ),
                ]),
          ]),
    ],
  );
}
