import 'dart:async';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/extensions.dart';
import 'package:flame/rendering.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:flutter/material.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/core/roller/roller.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';
import 'package:normaldo_gaming/game/components/effects_controller.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/notification_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';
import 'package:normaldo_gaming/game/utils/normaldo_sprites_fixture.dart';
import 'package:normaldo_gaming/game/utils/overlays.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';

enum NormaldoHitState {
  idle,
  hit,
}

enum NormaldoFatState {
  skinny,
  slim,
  fat,
  uberFat,

  // eating states
  skinnyEat,
  slimEat,
  fatEat,
  uberFatEat,

  // dead states
  skinnyDead;

  int pizzaToFat([int? amount]) {
    if (amount != null) return amount;
    return switch (this) {
      skinny || skinnyEat => 10,
      slim || slimEat => 20,
      fat || fatEat => 30,
      uberFat || uberFatEat => 50,
      _ => 1
    };
  }

  NormaldoFatState get dead {
    switch (this) {
      case NormaldoFatState.skinny:
      case NormaldoFatState.skinnyEat:
        return NormaldoFatState.skinnyDead;
      default:
        return this;
    }
  }

  static List<NormaldoFatState> get onlyIdle => [
        skinny,
        slim,
        fat,
        uberFat,
      ];

  static List<NormaldoFatState> get onlyEating => [
        skinnyEat,
        slimEat,
        fatEat,
        uberFatEat,
      ];
}

class FatStateIterator {
  FatStateIterator(this.current)
      : assert(NormaldoFatState.onlyIdle.contains(current));

  final onlyIdle = NormaldoFatState.onlyIdle;

  int get currIndex {
    return onlyIdle.indexOf(current);
  }

  NormaldoFatState current;

  bool deadlyDamage(int step) {
    return currIndex - step < 0;
  }

  NormaldoFatState next({int step = 1}) {
    assert(step > 0);
    for (int i = 0; i < step; i++) {
      current = _next();
    }
    return current;
  }

  NormaldoFatState prev({int step = 1}) {
    assert(step > 0);
    for (int i = 0; i < step; i++) {
      current = _prev();
    }
    return current;
  }

  NormaldoFatState _next() {
    var newIndex = currIndex + 1;
    if (newIndex >= onlyIdle.length) {
      newIndex = onlyIdle.length - 1;
    }
    return onlyIdle[newIndex];
  }

  NormaldoFatState _prev() {
    var newIndex = currIndex - 1;
    if (newIndex < 0) {
      newIndex = 0;
    }
    return onlyIdle[newIndex];
  }
}

class Normaldo extends PositionComponent
    with
        FlameBlocReader<GameSessionCubit, GameSessionState>,
        CollisionCallbacks,
        HasNgAudio,
        HasGameRef<PullUpGame> {
  static const smallHitboxRatio = 0.46;
  static const bigHitboxRatio = 0.5957;

  Normaldo({
    required Vector2 size,
    required this.skin,
    this.customPizzaToGetFatter,
  }) : super(size: size, anchor: Anchor.center);

  late final AudioPool _deathSfxPool;
  late final AudioPool _hitSfxPool;
  late final AudioPool _maxFatSfxPool;
  late final List<AudioPool> _resistSfxPools;
  late final List<AudioPool> _fatUpSfxPools;
  late final Sprite _x3Sprite;

  final Skin skin;
  final FatStateIterator fatIterator =
      FatStateIterator(NormaldoFatState.skinny);

  bool _immortal = false;
  bool get immortal => _immortal;
  bool isBiting(NormaldoFatState? current) =>
      NormaldoFatState.onlyEating.contains(current);

  Set<Items> _immuneTo = {};

  bool hasImmuneTo(Items item) {
    return _immuneTo.contains(item);
  }

  void addImmuneTo(List<Items> items) {
    _immuneTo.addAll(items);
  }

  void removeImmuneTo(List<Items> items) {
    _immuneTo.removeAll(items);
  }

  set immortal(bool newValue) {
    _immortal = newValue;
  }

  double speedMultiplier = 1;
  double get speed {
    double speed;
    switch (nComponent.current) {
      case NormaldoFatState.skinny:
      case NormaldoFatState.skinnyEat:
      case NormaldoFatState.skinnyDead:
        speed = 1;
      case NormaldoFatState.slim:
      case NormaldoFatState.slimEat:
        speed = 0.7;
      case NormaldoFatState.fat:
      case NormaldoFatState.fatEat:
        speed = 0.5;
      case NormaldoFatState.uberFat:
      case NormaldoFatState.uberFatEat:
        speed = 0.4;
      case null:
        throw UnexpectedError();
    }
    if (skin.uniqueId == 'glasses') {
      speed = 1;
    }
    return speed * speedMultiplier;
  }

  final int? customPizzaToGetFatter;
  late final EffectsController effectsController;
  late final SpriteGroupComponent<NormaldoFatState> nComponent;

  var _state = NormaldoHitState.idle;

  int? get pizzaToGetFatter =>
      nComponent.current?.pizzaToFat(customPizzaToGetFatter);

  void takeHit({int damage = 1}) {
    if (_immortal) return;
    if (fatIterator.deadlyDamage(damage)) {
      _deathSfxPool.start(volume: gameRef.audio.sfxVolume);
      nComponent.current = NormaldoFatState.skinnyDead;
      bloc.die(gameRef.missionCubit, gameRef.scene.currentLocationIndex);
      return;
    }

    _pizzaEaten = 0;
    state = NormaldoHitState.hit;
    _hitSfxPool.start(volume: gameRef.audio.sfxVolume);
    final newFatState = fatIterator.prev(step: damage);
    _changeFatAnimation(newFatState);
  }

  // 4DEV
  late final _circle = CircleComponent.relative(
    0.46,
    parentSize: size,
    anchor: anchor,
    position: Vector2(size.x / 2, size.y / 2 + size.y * 0.037),
    paint: Paint()..color = Colors.white.withOpacity(0.7),
  );
  late final hitbox = CircleHitbox.relative(
    0.46,
    parentSize: size,
    anchor: anchor,
    position: Vector2(size.x / 2 + 10, size.y / 2 + size.y * 0.037),
  );

  void setHitboxPositionAndSize({Vector2? position, Vector2? size}) {
    if (position != null) {
      hitbox.position = position;
      _circle.position = position;
    }
    if (size != null) {
      hitbox.size = size;
      _circle.size = size;
    }
  }

  var _pizzaEaten = 0;
  int get fatPoints => _pizzaEaten;

  bool get isUberFat =>
      nComponent.current == NormaldoFatState.uberFat ||
      nComponent.current == NormaldoFatState.uberFatEat;
  bool get isSkinny =>
      nComponent.current == NormaldoFatState.skinny ||
      nComponent.current == NormaldoFatState.skinnyEat;

  bool get isSlim =>
      nComponent.current == NormaldoFatState.slim ||
      nComponent.current == NormaldoFatState.slimEat;

  bool get isFat =>
      nComponent.current == NormaldoFatState.fat ||
      nComponent.current == NormaldoFatState.fatEat;

  bool get isPreEating {
    switch (nComponent.current) {
      case NormaldoFatState.skinny:
      case NormaldoFatState.slim:
      case NormaldoFatState.fat:
      case NormaldoFatState.uberFat:
        return false;
      default:
        return true;
    }
  }

  bool get canGetX3Money =>
      skin.uniqueId == 'pirate' && Roller<bool>([(true, 3), (false, 7)]).roll();

  set state(NormaldoHitState newState) {
    switch (newState) {
      case NormaldoHitState.idle:
        _immortal = false;
        stopImmortalityFlick();
        break;
      case NormaldoHitState.hit:
        _immortal = true;
        startImmortalityFlick();
        break;
    }
  }

  final List<NormaldoFatState> _fatCounter = [];

  void resist() {
    if (_resistSfxPools.isNotEmpty) {
      _resistSfxPools.random().start(volume: gameRef.audio.sfxVolume);
    }
  }

  NormaldoFatState _nextFat() {
    toIdleFatState();
    if (_fatCounter.isNotEmpty) {
      final current = _fatCounter.last;
      final indexOfCurrent = NormaldoFatState.onlyIdle.indexOf(current);
      if (indexOfCurrent + 1 == NormaldoFatState.onlyIdle.length) {
        return current;
      } else {
        final nextFat = NormaldoFatState.onlyIdle[indexOfCurrent + 1];
        if (nextFat != nComponent.current) {
          if (nextFat == NormaldoFatState.uberFat) {
            _maxFatSfxPool.start(volume: gameRef.audio.sfxVolume);
          } else {
            _fatUpSfxPools.random().start(volume: gameRef.audio.sfxVolume);
          }
          return nextFat;
        }
      }
    }
    final indexOfCurrent =
        NormaldoFatState.onlyIdle.indexOf(nComponent.current!);
    if (indexOfCurrent + 1 == NormaldoFatState.onlyIdle.length) {
      return nComponent.current!;
    } else {
      if (indexOfCurrent + 1 == NormaldoFatState.uberFat.index) {
        _maxFatSfxPool.start(volume: gameRef.audio.sfxVolume);
      } else {
        _fatUpSfxPools.random().start(volume: gameRef.audio.sfxVolume);
      }
      return NormaldoFatState.onlyIdle[indexOfCurrent + 1];
    }
  }

  void increaseFatPoints(int by) {
    assert(by > 0);
    final pizzaToGetFatter =
        nComponent.current!.pizzaToFat(customPizzaToGetFatter);
    _pizzaEaten += by;
    if (_pizzaEaten >= pizzaToGetFatter && !isFat && !isUberFat) {
      _pizzaEaten = _pizzaEaten % pizzaToGetFatter;
      final nextFat = _nextFat();
      _fatCounter.add(nextFat);
    } else if (_pizzaEaten >= pizzaToGetFatter && isFat) {
      _pizzaEaten = NormaldoFatState.uberFat.pizzaToFat();
      final nextFat = _nextFat();
      _fatCounter.add(nextFat);
    } else if (_pizzaEaten >= pizzaToGetFatter && isUberFat) {
      _pizzaEaten = NormaldoFatState.uberFat.pizzaToFat();
    }
  }

  Future<void> decreaseFatPoints(int by) async {
    assert(by > 0);
    _pizzaEaten -= by;
    bloc.takeHit();
    if (_pizzaEaten <= 0 && !isSlim && !isSkinny) {
      _pizzaEaten = 0;
      await prevFatState();
    } else if (_pizzaEaten <= 0 && isSlim) {
      _pizzaEaten = 0;
      await prevFatState();
    } else if (_pizzaEaten <= 0 && isSkinny) {
      _pizzaEaten = 0;
      bloc.die(gameRef.missionCubit, gameRef.scene.currentLocationIndex);
    }
  }

  void _handleFat() {
    if (_fatCounter.isNotEmpty) {
      final nextFat = _fatCounter.last;
      final fatUpPath = skin.assets.sfx['fatUp'];
      if (fatUpPath != null) {
        audio.playAssetSfx(
          Utils.skinSfxWrapper(fatUpPath.random()),
        );
      }
      _changeFatAnimation(nextFat);
      _fatCounter.clear();
    }
  }

  void showX3Money() {
    final comp = SpriteComponent(
      sprite: _x3Sprite,
      size: size * 0.7,
      anchor: Anchor.center,
      position: size / 2,
      angle: -0.2,
      scale: Vector2.all(0),
    );
    final uniquePath = skin.assets.sfx['unique'];
    if (uniquePath != null) {
      audio.playAssetSfx(Utils.skinSfxWrapper(uniquePath.random()));
    }
    add(comp
      ..addAll([
        ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.2)),
        MoveByEffect(
            Vector2(0, -size.y * 0.8), EffectController(duration: 0.2)),
        RotateEffect.by(
            0.2,
            EffectController(
              duration: 0.1,
              reverseDuration: 0.1,
              repeatCount: 10,
              startDelay: 0.2,
            ), onComplete: () {
          comp.add(SequenceEffect([
            ScaleEffect.to(
              Vector2.all(1.1),
              EffectController(
                duration: 0.2,
              ),
            ),
            ScaleEffect.to(
              Vector2.all(0),
              EffectController(
                duration: 0.1,
              ),
            ),
            RemoveEffect(),
          ]));
        })
      ]));
  }

  Future<void> toMaxFat() async {
    await Future.delayed(const Duration(milliseconds: 200));
    toIdleFatState();
    const state = NormaldoFatState.uberFat;
    final maxFatPath = skin.assets.sfx['maxFat'];
    if (maxFatPath != null) {
      audio.playAssetSfx(maxFatPath.random());
    }
    notify(
      text: 'MAX FAT!'.tr(),
      color: NGTheme.green1,
      fontSize: 18,
    );
    _changeFatAnimation(state);
    fatIterator.current = state;
    setHitboxPositionAndSize(size: size * bigHitboxRatio);
  }

  Future<void> nextFatState() async {
    NormaldoFatState state;
    await Future.delayed(const Duration(milliseconds: 200));
    toIdleFatState();
    final indexOfCurrent =
        NormaldoFatState.onlyIdle.indexOf(nComponent.current!);
    if (indexOfCurrent + 1 == NormaldoFatState.onlyIdle.length) {
      state = nComponent.current!;
    } else {
      state = NormaldoFatState.onlyIdle[indexOfCurrent + 1];
    }
    final index = NormaldoFatState.onlyIdle.indexOf(state);
    if (index == 3) {
      final maxFatPath = skin.assets.sfx['maxFat'];
      if (maxFatPath != null) {
        audio.playAssetSfx(maxFatPath.random());
      }
      notify(
        text: 'MAX FAT!'.tr(),
        color: NGTheme.green1,
        fontSize: 18,
      );
    } else {
      if (customPizzaToGetFatter == null) {
        notify(text: '${'Fat'.tr()} ${index + 1} / 4', color: NGTheme.green1);
      }
    }
    if (nComponent.current != state) {
      if (index != 3 || (skin.assets.sfx['maxFat'] == null && index == 3)) {
        final fatUpPath = skin.assets.sfx['fatUp'];
        if (fatUpPath != null) {
          audio.playAssetSfx(
            fatUpPath.random(),
          );
        }
      }
      _changeFatAnimation(state);
      fatIterator.current = state;
    }
    if (index >= 2) {
      setHitboxPositionAndSize(size: size * bigHitboxRatio);
    }
  }

  Future<void> prevFatState() async {
    NormaldoFatState state;
    await Future.delayed(const Duration(milliseconds: 200));
    toIdleFatState();
    final indexOfCurrent =
        NormaldoFatState.onlyIdle.indexOf(nComponent.current!);
    if (indexOfCurrent - 1 < 0) {
      state = nComponent.current!;
    } else {
      state = NormaldoFatState.onlyIdle[indexOfCurrent - 1];
    }
    final index = NormaldoFatState.onlyIdle.indexOf(state);
    if (customPizzaToGetFatter == null) {
      notify(text: '${'Fat'.tr()} ${index + 1} / 4', color: NGTheme.green1);
    }
    if (nComponent.current != state) {
      _changeFatAnimation(state);
      // final changed = _changeFatAnimation(state);
      // if (!changed) {
      //   nComponent.current = state;
      // }
    }
    if (index < 2) {
      setHitboxPositionAndSize(size: size * smallHitboxRatio);
    }
  }

  List<Items> _satellites = [];

  void removeSatellite(Items item) {
    if (_satellites.contains(item)) {
      final timerKey = '${item.name}_timer';
      _satellites.remove(item);
      game.findByKeyName<TimerComponent>(timerKey)?.removeFromParent();
      game.findByKeyName<SpriteComponent>(item.name)?.removeFromParent();
    }
  }

  Future<void> addSatellite(Items item) async {
    if (_satellites.contains(item)) return;
    const duration = 0.5;
    _satellites.add(item);
    final spritePath = switch (item) {
      Items.caseyMask => 'kasey mask2 flipped.png',
      Items.magicHat => 'magic 3.png',
      _ => throw UnexpectedError(),
    };
    final timerKey = '${item.name}_timer';
    final itemKey = item.name;
    final scale = Vector2.all(0.7);
    final component = SpriteComponent(
      key: ComponentKey.named(itemKey),
      sprite: (await Sprite.load(spritePath)),
      size: Vector2(25, 25),
      anchor: anchor,
      priority: 1,
      scale: Vector2.all(0.85),
    );
    final path = Utils.getSatellitePath2(Vector2(size.x, size.y * 0.9));
    addAll([
      component
        ..addAll([
          MoveAlongPathEffect(
            path,
            EffectController(
              duration: duration,
              infinite: true,
            ),
          ),
          SequenceEffect(
            [
              ScaleEffect.to(
                  Vector2.all(1),
                  EffectController(
                    duration: 0.75,
                  )),
              ScaleEffect.to(
                  Vector2.all(0.85),
                  EffectController(
                    duration: 0.75,
                  )),
              ScaleEffect.to(
                  scale,
                  EffectController(
                    duration: 0.75,
                  )),
              ScaleEffect.to(
                  Vector2.all(0.85),
                  EffectController(
                    duration: 0.75,
                  )),
            ],
            infinite: true,
          ),
        ]),
      TimerComponent(
          period: duration / 2,
          key: ComponentKey.named(timerKey),
          repeat: true,
          onTick: () {
            if (component.priority > 0) {
              component.priority = 0;
            } else {
              component.priority = 2;
            }
          }),
    ]);
  }

  void notify({
    required String text,
    Color? color,
    double? fontSize,
  }) {
    final grid = gameRef.grid;
    grid.add(
      NotificationComponent(
        text: text,
        color: color,
        fontSize: fontSize,
      )..position = position + Vector2(-10, -size.y / 2),
    );
  }

  void _evadeTimer() {
    add(TimerComponent(
        period: (10 + Random().nextInt(21)).toDouble(),
        removeOnFinish: true,
        onTick: () {
          nComponent.add(OpacityEffect.to(
              0.5,
              EffectController(
                duration: 0.3,
                reverseDuration: 0.3,
                atMaxDuration: 3,
              )));
          _immortal = true;
          final uniquePath = skin.assets.sfx['unique'];
          if (uniquePath != null) {
            audio.playAssetSfx(Utils.skinSfxWrapper(uniquePath.random()));
          }
          add(TimerComponent(
              period: 3,
              removeOnFinish: true,
              onTick: () {
                nComponent.add(OpacityEffect.to(
                    1,
                    EffectController(
                      duration: 0.3,
                    )));
                _immortal = false;
                _evadeTimer();
              }));
        }));
  }

  @override
  bool get debugMode => false;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    nComponent = SpriteGroupComponent<NormaldoFatState>(
      anchor: anchor,
      size: size,
      position: size / 2,
      priority: 1,
    );

    _x3Sprite = await Sprite.load('x3 (2) 3.png');

    nComponent.sprites = await normaldoSprites(skin);

    nComponent.current = NormaldoFatState.skinny;

    _deathSfxPool = await AudioPool.createFromAsset(
      path: 'audio/sfx/death.mp3',
      maxPlayers: 1,
    );
    _hitSfxPool = await AudioPool.createFromAsset(
      path: skin.assets.sfx['hit'] != null
          ? 'audio/skins/${skin.assets.sfx['hit']!.random()}'
          : 'audio/sfx/ydar.mp3',
      maxPlayers: 1,
    );
    _maxFatSfxPool = await AudioPool.createFromAsset(
      path: skin.assets.sfx['maxFat'] != null
          ? 'audio/skins/${skin.assets.sfx['maxFat']!.random()}'
          : 'audio/sfx/eeeeee.mp3',
      maxPlayers: 1,
    );
    _resistSfxPools = await Future.wait(
        skin.assets.sfx['resist']?.map((e) => AudioPool.createFromAsset(
                  path: 'audio/skins/$e',
                  maxPlayers: 1,
                )) ??
            []);

    _fatUpSfxPools = await Future.wait(
        skin.assets.sfx['fatUp']?.map((e) => AudioPool.createFromAsset(
                  path: 'audio/skins/$e',
                  maxPlayers: 1,
                )) ??
            []);
    if (_fatUpSfxPools.isEmpty) {
      _fatUpSfxPools.add(await AudioPool.createFromAsset(
          path: 'audio/sfx/FATUP.mp3', maxPlayers: 1));
    }

    add(nComponent);

    final startPath = skin.assets.sfx['start'];
    if (startPath != null) {
      audio.playAssetSfx(Utils.skinSfxWrapper(startPath.random()));
    }

    effectsController =
        EffectsController(onNewState: ((ItemEffect effect, double duration) {
      final durString = duration.toInt().toString();
      final text = switch (effect) {
        ItemEffect.slow => '${'Slowed'.tr()} $durString',
        ItemEffect.slowMo => '${'Slow mo'.tr()} $durString',
        ItemEffect.immortality => 'IMMORTALDO $durString',
        ItemEffect.disorient => 'DISORIENTED $durString',
        ItemEffect.speedUp => 'FLASH $durString',
        ItemEffect.immuneToSlowingItems => 'SLOW IMMUNITY $durString',
        ItemEffect.immuneToAttackingItems => 'DAMAGE IMMUNITY $durString',
      };
      final color = switch (effect) {
        ItemEffect.slow => Colors.purple,
        ItemEffect.slowMo => Colors.orange,
        ItemEffect.immortality => Colors.red,
        ItemEffect.disorient => Colors.blueGrey,
        ItemEffect.speedUp => Colors.yellow[600],
        ItemEffect.immuneToSlowingItems => Colors.deepPurple[400],
        ItemEffect.immuneToAttackingItems => Colors.redAccent[300],
      };
      if (duration > 0) {
        notify(text: text, color: color);
      }
      if (effect == ItemEffect.slow || effect == ItemEffect.speedUp) {
        decorator.removeLast();
        decorator.addLast(
            PaintDecorator.tint(color?.withOpacity(0.4) ?? Colors.black));
      }
      if (duration == 0 &&
          (effect == ItemEffect.slow || effect == ItemEffect.speedUp)) {
        decorator.removeLast();
      }
    }));
    add(effectsController);

    add(TimerComponent(
      period: 0.5,
      repeat: true,
      onTick: _handleFat,
    ));

    if (skin.uniqueId == 'wizard') {
      add(TimerComponent(
          period: 10,
          repeat: true,
          removeOnFinish: true,
          onTick: () {
            gameRef.grid.vanishRandomItem();
            final uniquePath = skin.assets.sfx['unique'];
            if (uniquePath != null) {
              audio.playAssetSfx(Utils.skinSfxWrapper(uniquePath.random()));
            }
          }));
    }
    if (skin.uniqueId == 'harry_potter') {
      add(TimerComponent(
          period: 7,
          repeat: true,
          removeOnFinish: true,
          onTick: () {
            gameRef.grid.vanishRandomItem();
            final uniquePath = skin.assets.sfx['unique'];
            if (uniquePath != null) {
              audio.playAssetSfx(Utils.skinSfxWrapper(uniquePath.random()));
            }
          }));
    }
    if (skin.uniqueId == 'spider-man') {
      _evadeTimer();
    }

    // 4DEV
    // add(_circle);

    add(hitbox);

    await add(FlameBlocListener<GameSessionCubit, GameSessionState>(
        listenWhen: (prevState, newState) => prevState.hit != newState.hit,
        onNewState: (cState) {
          if (cState.hit) {
            state = NormaldoHitState.hit;
          } else {
            state = NormaldoHitState.idle;
          }
        }));
    await add(FlameBlocListener<GameSessionCubit, GameSessionState>(
        listenWhen: (prevState, newState) =>
            prevState.isDead != newState.isDead,
        onNewState: (gameState) {
          if (gameState.isDead) {
            nComponent.current = nComponent.current?.dead;
            state = NormaldoHitState.hit;
          } else {
            nComponent.current = NormaldoFatState.skinny;
            Future.delayed(const Duration(seconds: 2)).whenComplete(() {
              state = NormaldoHitState.idle;
            });
          }
        }));

    if (skin.uniqueId == 'new_year') {
      game.overlays.add(Overlays.snowfall.name);
    }
  }

  @override
  void update(double dt) {
    if (skin.uniqueId == 'dracula') {
      final anyEatableClose =
          gameRef.grid.children.whereType<Item>().where((e) {
        return (e is Eatable || skin.resistanceToItems.contains(e.item));
      }).any((element) => element.distance(this) < element.size.x * 1.5);
      if (anyEatableClose && !isBiting(nComponent.current)) {
        toEatingState();
        Future.delayed(const Duration(milliseconds: 200))
            .whenComplete(() => toIdleFatState());
      }
    } else {
      final anyEatableClose = gameRef.grid.children
          .whereType<Eatable>()
          .any((element) => element.distance(this) < element.size.x * 1.5);
      if (anyEatableClose && !isBiting(nComponent.current)) {
        toEatingState();
        Future.delayed(const Duration(milliseconds: 200))
            .whenComplete(() => toIdleFatState());
      }
    }
    super.update(dt);
  }

  @override
  void onRemove() {
    if (skin.uniqueId == 'new_year') {
      game.overlays.remove(Overlays.snowfall.name);
    }
    super.onRemove();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is Eatable && !isPreEating) {
      toEatingState();
      Future.delayed(const Duration(milliseconds: 200))
          .whenComplete(() => toIdleFatState());
    }
    if (skin.uniqueId == 'dracula' &&
        (other is Item && skin.resistanceToItems.contains(other.item))) {
      game.grid.normaldo.increaseFatPoints(1);
      gameRef.sfxPools.playSfx(Items.pizza);
    }
    if (!_immortal && _immuneTo.isNotEmpty) {
      if (other is Item) {
        if (_immuneTo.contains(other.item) && nComponent.opacity == 1) {
          nComponent.add(OpacityEffect.to(
              0.5,
              EffectController(
                duration: 0.3,
                reverseDuration: 0.3,
                atMaxDuration: 0.5,
              )));
        }
      }
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  void toEatingState() {
    switch (nComponent.current) {
      case NormaldoFatState.skinny:
        nComponent.current = NormaldoFatState.skinnyEat;
        break;
      case NormaldoFatState.slim:
        nComponent.current = NormaldoFatState.slimEat;
        break;
      case NormaldoFatState.fat:
        nComponent.current = NormaldoFatState.fatEat;
        break;
      case NormaldoFatState.uberFat:
        nComponent.current = NormaldoFatState.uberFatEat;
        break;
      default:
        break;
    }
  }

  void toIdleFatState() {
    switch (nComponent.current) {
      case NormaldoFatState.skinnyEat:
        nComponent.current = NormaldoFatState.skinny;
        break;
      case NormaldoFatState.slimEat:
        nComponent.current = NormaldoFatState.slim;
        break;
      case NormaldoFatState.fatEat:
        nComponent.current = NormaldoFatState.fat;
        break;
      case NormaldoFatState.uberFatEat:
        nComponent.current = NormaldoFatState.uberFat;
        break;
      default:
        break;
    }
  }

  void _changeFatAnimation(NormaldoFatState state) {
    const dur = 0.25;
    const curve = Curves.bounceOut;
    nComponent.addAll([
      RotateEffect.to(
          (Random().nextBool() ? pi : -pi) * 2,
          EffectController(
            duration: dur,
            reverseDuration: dur * 2,
            curve: curve,
          )),
      ScaleEffect.to(
          Vector2.all(0.1),
          EffectController(
              duration: dur,
              reverseDuration: dur * 2,
              curve: curve,
              onMax: () {
                nComponent.current = state;
                fatIterator.current = state;
              }))
    ]);
  }

  Future<void> startImmortalityFlick() async {
    final controller = EffectController(
      duration: 0.1,
      reverseDuration: 0.1,
      repeatCount: 20,
    );
    nComponent.add(
      OpacityEffect.to(0, controller,
          onComplete: () => state = NormaldoHitState.idle),
    );
  }

  Future<void> stopImmortalityFlick() async {
    nComponent.removeWhere((component) => component is OpacityEffect);
    nComponent.add(OpacityEffect.to(1, EffectController(duration: 0.1)));
  }
}
