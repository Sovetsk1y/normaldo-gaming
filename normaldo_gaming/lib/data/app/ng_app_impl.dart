import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/domain/app/ng_app.dart';
import 'package:normaldo_gaming/injection/injection.dart';
import 'package:normaldo_gaming/routing/ng_router.dart';

class NGAppImpl implements NGApp {
  @override
  Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    initializeInjector();
    runApp(MaterialApp.router(
      routerConfig: NGRouter.router,
      debugShowCheckedModeBanner: false,
      theme: _theme,
    ));
  }
}

final _theme = ThemeData(
    fontFamily: "HyperStiffRoundBootiedOpossumRegular",
    textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(
      shadowColor: MaterialStatePropertyAll(Colors.transparent),
      overlayColor: MaterialStatePropertyAll(Colors.transparent),
    )),
    textTheme: const TextTheme(
      displayLarge: NGTheme.displayLarge,
    ));
