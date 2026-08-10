// import 'package:flame/collisions.dart';
// import 'package:flame/components.dart';
// import 'package:flame_bloc/flame_bloc.dart';
// import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
// import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
// import 'package:normaldo_gaming/domain/app/sfx.dart';
// import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
// import 'package:normaldo_gaming/game/components/item_component.dart';
// import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/predator_attack.dart';
// import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/shuriken_shower_attack.dart';
// import 'package:normaldo_gaming/game/components/normaldo.dart';
// import 'package:normaldo_gaming/game/pull_up_game.dart';

// class Shredder extends PositionComponent
//     with
//         CollisionCallbacks,
//         HasGameRef<PullUpGame>,
//         FlameBlocListenable<LevelBloc, LevelState>,
//         Item,
//         HasNgAudio {
//   Shredder({this.audioId}) : super(anchor: Anchor.center);

//   final int? audioId;

//   final List<SAttack> _attacks = [];

//   late final SpriteComponent shredderSprite;

//   @override
//   bool listenWhen(LevelState previousState, LevelState newState) {
//     return previousState.level != newState.level;
//   }

//   @override
//   void onNewState(LevelState state) {
//     if (!hearsBloc) return;
//     speed = state.level.speed;
//   }

//   @override
//   void onCollisionStart(
//     Set<Vector2> intersectionPoints,
//     PositionComponent other,
//   ) {
//     if (other is Normaldo && !other.immortal) {
//       other.takeHit();
//       audio.playSfx(Sfx.binCrash, customAssets: other.skin.assets.sfx['hit']);
//     }
//     if (other is GameObject && !disabled && other is! Normaldo) {
//       other.removeFromParent();
//     }
//     super.onCollisionStart(intersectionPoints, other);
//   }

//   @override
//   Future<void> onLoad() async {
//     autoRemove = false;
//     onRemoved = () {
//       if (audioId != null) {
//         final grid = (gameRef as PullUpGame).grid;
//         grid.add(AudioFadeComponent(onTick: () {
//           if (audio.bgmVolume >= 0.1) {
//             audio.stopAudio(audioId!);
//             audio.setVolumeToBgm(volume: 0.1);
//             grid.removeWhere((component) => component is AudioFadeComponent);
//             return;
//           }
//           audio.setVolumeToBgm(volume: audio.bgmVolume + 0.01);
//           audio.setVolumeToAudio(
//               audioId: audioId!,
//               volume: audio.audioVolume(audioId: audioId!) - 0.02);
//         }));
//       }
//       final items = [
//         Items.dollar,
//         Items.pizza,
//       ]..shuffle();
//       final item = items.first;
//       bloc.add(const LevelEvent.finishMiniGame());
//       bloc.add(
//           LevelEvent.startFigure(figure: FigureEvent.winLabel(item: item)));
//     };
//     speed = (gameRef as PullUpGame).levelBloc.state.level.speed;
//     shredderSprite = SpriteComponent(
//       size: size,
//       sprite: await Sprite.load('shredder.png'),
//     );
//     add(shredderSprite);

//     add(eatingHitbox);

//     final grid = gameRef.grid;
//     _attacks.addAll([
//       ShurikenShowerAttack(),
//       ShurikenShowerAttack(),
//       ShurikenShowerAttack(),
//       ShurikenShowerAttack(),
//       PredatorAttack(),
//       PredatorAttack(),
//       PredatorAttack(),
//       PredatorAttack(),
//       PredatorAttack(),
//       PredatorAttack(),
//     ]);
//     _attacks.shuffle();
//     if (_attacks.isNotEmpty) {
//       _attacks.first.start(this, grid);
//     }

//     return super.onLoad();
//   }

//   @override
//   void update(double dt) {
//     super.update(dt);

//     if (_attacks.isNotEmpty) {
//       if (_attacks.first.completed) {
//         _attacks.removeAt(0);
//         if (_attacks.isNotEmpty) {
//           _attacks.first.start(this, gameRef.grid);
//         }
//       }
//     } else {
//       removeFromParent();
//     }
//   }

//   @override
//   Items get item => Items.shredder;

//   @override
//   PositionComponent get hitbox => throw UnimplementedError();
// }
