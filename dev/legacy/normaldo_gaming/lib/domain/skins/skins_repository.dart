import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';

abstract class SkinsRepository {
  List<Skin> get skinsData;
  Skin getSkinById(String uniqueId);
}

enum SkinRarity { classic, common, rare, epic, legendary }

final class Skin {
  final String uniqueId;
  final String name;
  final SkinRarity rarity;
  final SkinAssets assets;
  final List<Items> resistanceToItems;
  final String? uniqueSkill;

  const Skin({
    required this.uniqueId,
    required this.name,
    required this.rarity,
    required this.assets,
    required this.resistanceToItems,
    this.uniqueSkill,
  });

  int get price => switch (rarity) {
        SkinRarity.classic => 0,
        SkinRarity.common => 500,
        SkinRarity.rare => 1000,
        SkinRarity.epic => 1500,
        SkinRarity.legendary => 2000,
      };

  factory Skin.basic() => const Skin(
        uniqueId: 'basic',
        name: 'Normaldo',
        rarity: SkinRarity.classic,
        assets: SkinAssets(
          skinny: 'normaldo/normaldo1.png',
          slim: 'normaldo/normaldo2.png',
          fat: 'normaldo/normaldo3.png',
          superFat: 'normaldo/normaldo4.png',
          skinnyBite: 'normaldo/normaldo1_eat.png',
          slimBite: 'normaldo/normaldo2_eat.png',
          fatBite: 'normaldo/normaldo3_eat.png',
          superFatBite: 'normaldo/normaldo4_eat.png',
          dead: 'normaldo/normaldo1_dead.png',
          mask: 'normaldo/mask.png',
        ),
        resistanceToItems: [],
      );
}

final class SkinAssets {
  const SkinAssets({
    required this.skinny,
    required this.slim,
    required this.fat,
    required this.superFat,
    required this.skinnyBite,
    required this.slimBite,
    required this.fatBite,
    required this.superFatBite,
    required this.dead,
    required this.mask,
    this.url = false,
    this.sfx = const {},
  });

  final bool url;
  final String skinny;
  final String slim;
  final String fat;
  final String superFat;
  final String skinnyBite;
  final String slimBite;
  final String fatBite;
  final String superFatBite;
  final String dead;
  final String mask;

  final Map<String, List<String>> sfx;

  String fatFromIndex(int index) {
    return switch (index) {
      0 => skinny,
      1 => slim,
      2 => fat,
      3 => superFat,
      _ => throw UnexpectedError(),
    };
  }

  String fatBiteFromIndex(int index) {
    return switch (index) {
      0 => skinnyBite,
      1 => slimBite,
      2 => fatBite,
      3 => superFatBite,
      _ => throw UnexpectedError(),
    };
  }
}
