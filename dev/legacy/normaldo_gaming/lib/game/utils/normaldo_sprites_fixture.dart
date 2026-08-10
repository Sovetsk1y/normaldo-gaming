import 'package:flame/components.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';

Future<Map<NormaldoFatState, Sprite>> normaldoSprites(Skin skin) async {
  final skinnySprite = await Sprite.load(skin.assets.skinny);
  final slimSprite = await Sprite.load(skin.assets.slim);
  final fatSprite = await Sprite.load(skin.assets.fat);
  final uberFatSprite = await Sprite.load(skin.assets.superFat);

  final skinnyEatSprite = await Sprite.load(skin.assets.skinnyBite);
  final slimEatSprite = await Sprite.load(skin.assets.slimBite);
  final fatEatSprite = await Sprite.load(skin.assets.fatBite);
  final uberFatEatSprite = await Sprite.load(skin.assets.superFatBite);

  final skinnyDeadSprite = await Sprite.load(skin.assets.dead);

  return {
    NormaldoFatState.skinny: skinnySprite,
    NormaldoFatState.slim: slimSprite,
    NormaldoFatState.fat: fatSprite,
    NormaldoFatState.uberFat: uberFatSprite,

    // eating
    NormaldoFatState.skinnyEat: skinnyEatSprite,
    NormaldoFatState.slimEat: slimEatSprite,
    NormaldoFatState.fatEat: fatEatSprite,
    NormaldoFatState.uberFatEat: uberFatEatSprite,

    // dead
    NormaldoFatState.skinnyDead: skinnyDeadSprite,
  };
}
