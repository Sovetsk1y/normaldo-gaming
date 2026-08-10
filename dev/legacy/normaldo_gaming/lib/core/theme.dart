import 'package:flutter/material.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';

abstract class NGTheme {
  const NGTheme._();

  static const _fontFamily = 'NormaldoFont';

  static const green1 = Color(0xff22B14C);
  static const green2 = Color(0xffB5E61D);
  static const green3 = Color(0xff22B14C);
  static const bgSemiBlack = Colors.black38;
  static const heartRed = Color(0xffDC0000);
  static const purple1 = Color(0xffA349A4);
  static const purple2 = Color(0xff7C347C);
  static const purple3 = Color(0xff5E265E);
  static const orange1 = Color(0xffFFCC00);
  static const gray1 = Color(0xffADADAD);
  static const gray2 = Color(0xff3C3838);

  static const tgBlue = Color(0xff24A1DE);

  static const classicSkin = Color(0xffA3A3A3);
  static const commonSkin = Color(0xff2FB10F);
  static const rareSkin = Color(0xff376AEC);
  static const epicSkin = Color(0xffC450E1);
  static const legendarySkin = Color(0xffF8B404);

  static const auraGreen = green1;
  static const auraRed = Color(0xffDC0000);
  static const auraBlue = Color.fromARGB(255, 103, 179, 254);

  static Color colorOf(SkinRarity rarity) {
    return switch (rarity) {
      SkinRarity.classic => classicSkin,
      SkinRarity.common => commonSkin,
      SkinRarity.rare => rareSkin,
      SkinRarity.epic => epicSkin,
      SkinRarity.legendary => legendarySkin,
    };
  }

  static const displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    color: Colors.white,
  );

  static const displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    color: Colors.white,
  );

  static const displaySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    color: Colors.white,
  );

  static const bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    color: Colors.white,
  );
  static const labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    color: Colors.white,
  );
  static const labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    color: gray2,
  );
  static const rareSkinStyle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    color: rareSkin,
  );
}
