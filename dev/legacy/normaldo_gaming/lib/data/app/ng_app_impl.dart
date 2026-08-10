import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive/hive.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:normaldo_gaming/application/daily_reward/cubit/daily_reward_cubit.dart';
import 'package:normaldo_gaming/application/education/cubit/education_cubit.dart';
import 'package:normaldo_gaming/application/mission/mission_cubit.dart';
import 'package:normaldo_gaming/application/sign_in/sign_in_cubit.dart';
import 'package:normaldo_gaming/application/sign_up/sign_up_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/config/config.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/domain/app/ng_app.dart';
import 'package:normaldo_gaming/injection/injection.dart';
import 'package:normaldo_gaming/routing/ng_router.dart';
import 'package:normaldo_gaming/ui/widgets/config_inherited_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class NGAppImpl implements NGApp {
  @override
  Future<void> run() async {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await EasyLocalization.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: binding);
    FlameAudio.bgm.initialize();
    final config = kDebugMode ? Config.dev() : Config.prod();
    bool initAds = true;
    print('''
Init Ads: $initAds
OS: ${Platform.operatingSystem}
OS Version: ${Platform.operatingSystemVersion}
''');
    if (Platform.isIOS) {
      final version = double.parse(Platform.operatingSystemVersion
          .split('(')
          .first
          .split(' ')[1]
          .split('.')[0]);
      if (version >= 17) {
        initAds = true;
      }
    } else {
      initAds = true;
    }
    if (initAds) {
      UnityAds.init(
        gameId: Platform.isIOS ? config.iosAdId : config.androidAdId,
        testMode: kDebugMode,
        onComplete: () => print('Initialization Complete'),
        onFailed: (error, message) =>
            print('Initialization Failed: $error $message'),
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    Hive.init(directory.path);

    // HomeIndicator.deferScreenEdges(ScreenEdge.values);

    HydratedBloc.storage = await HydratedStorage.build(
        storageDirectory: await getApplicationDocumentsDirectory());

    initializeInjector(config);
    const supportedLocales = [Locale('ru'), Locale('en')];
    final userCubit = injector.get<UserCubit>();
    runApp(EasyLocalization(
      useOnlyLangCode: true,
      supportedLocales: supportedLocales,
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MultiBlocProvider(
        providers: [
          // BlocProvider<AuthCubit>(create: (context) => injector.get()..auth()),
          BlocProvider<UserCubit>(create: (context) => userCubit),
          BlocProvider<EducationCubit>(create: (context) => EducationCubit()),
          BlocProvider<SignUpCubit>(create: (context) => injector.get()),
          BlocProvider<SignInCubit>(create: (context) => injector.get()),
          BlocProvider<MissionCubit>(create: (context) => injector.get()),
          BlocProvider<DailyRewardCubit>(create: (context) => injector.get()),
        ],
        child: ConfigInheritedWidget(
          config: config,
          child: const _AppWidget(),
        ),
      ),
    ));
  }
}

class _AppWidget extends StatelessWidget {
  const _AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.0)),
      child: MaterialApp.router(
        routerConfig: NGRouter.router,
        debugShowCheckedModeBanner: false,
        theme: _theme,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        locale: context.locale,
      ),
    );
  }
}

final _theme = ThemeData(
    fontFamily: "NormaldoFont",
    textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(
      shadowColor: MaterialStatePropertyAll(Colors.transparent),
      overlayColor: MaterialStatePropertyAll(Colors.transparent),
    )),
    textTheme: const TextTheme(
      displayLarge: NGTheme.displayLarge,
      displayMedium: NGTheme.displayMedium,
      displaySmall: NGTheme.displaySmall,
      bodySmall: NGTheme.bodySmall,
      labelSmall: NGTheme.labelSmall,
      labelMedium: NGTheme.labelMedium,
    ));
