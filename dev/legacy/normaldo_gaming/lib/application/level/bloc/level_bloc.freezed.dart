// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'level_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$LevelEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int level, List<ItemEffect> effects) changeLevel,
    required TResult Function(FigureEvent figure) startFigure,
    required TResult Function(MiniGame game) startMiniGame,
    required TResult Function() finishMiniGame,
    required TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)
        startRandomFigure,
    required TResult Function(double speed, List<ItemEffect> effects)
        changeSpeed,
    required TResult Function() finishFigure,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult? Function(FigureEvent figure)? startFigure,
    TResult? Function(MiniGame game)? startMiniGame,
    TResult? Function()? finishMiniGame,
    TResult? Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult? Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult? Function()? finishFigure,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult Function(FigureEvent figure)? startFigure,
    TResult Function(MiniGame game)? startMiniGame,
    TResult Function()? finishMiniGame,
    TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult Function()? finishFigure,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_ChangeLevel value) changeLevel,
    required TResult Function(_StartFigure value) startFigure,
    required TResult Function(_StartMiniGame value) startMiniGame,
    required TResult Function(_FinishMiniGame value) finishMiniGame,
    required TResult Function(_StartRandomFigure value) startRandomFigure,
    required TResult Function(_ChangeSpeed value) changeSpeed,
    required TResult Function(_FinishFigure value) finishFigure,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_ChangeLevel value)? changeLevel,
    TResult? Function(_StartFigure value)? startFigure,
    TResult? Function(_StartMiniGame value)? startMiniGame,
    TResult? Function(_FinishMiniGame value)? finishMiniGame,
    TResult? Function(_StartRandomFigure value)? startRandomFigure,
    TResult? Function(_ChangeSpeed value)? changeSpeed,
    TResult? Function(_FinishFigure value)? finishFigure,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_ChangeLevel value)? changeLevel,
    TResult Function(_StartFigure value)? startFigure,
    TResult Function(_StartMiniGame value)? startMiniGame,
    TResult Function(_FinishMiniGame value)? finishMiniGame,
    TResult Function(_StartRandomFigure value)? startRandomFigure,
    TResult Function(_ChangeSpeed value)? changeSpeed,
    TResult Function(_FinishFigure value)? finishFigure,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LevelEventCopyWith<$Res> {
  factory $LevelEventCopyWith(
          LevelEvent value, $Res Function(LevelEvent) then) =
      _$LevelEventCopyWithImpl<$Res, LevelEvent>;
}

/// @nodoc
class _$LevelEventCopyWithImpl<$Res, $Val extends LevelEvent>
    implements $LevelEventCopyWith<$Res> {
  _$LevelEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$ChangeLevelImplCopyWith<$Res> {
  factory _$$ChangeLevelImplCopyWith(
          _$ChangeLevelImpl value, $Res Function(_$ChangeLevelImpl) then) =
      __$$ChangeLevelImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int level, List<ItemEffect> effects});
}

/// @nodoc
class __$$ChangeLevelImplCopyWithImpl<$Res>
    extends _$LevelEventCopyWithImpl<$Res, _$ChangeLevelImpl>
    implements _$$ChangeLevelImplCopyWith<$Res> {
  __$$ChangeLevelImplCopyWithImpl(
      _$ChangeLevelImpl _value, $Res Function(_$ChangeLevelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? level = null,
    Object? effects = null,
  }) {
    return _then(_$ChangeLevelImpl(
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      effects: null == effects
          ? _value._effects
          : effects // ignore: cast_nullable_to_non_nullable
              as List<ItemEffect>,
    ));
  }
}

/// @nodoc

class _$ChangeLevelImpl implements _ChangeLevel {
  const _$ChangeLevelImpl(
      {required this.level, required final List<ItemEffect> effects})
      : _effects = effects;

  @override
  final int level;
  final List<ItemEffect> _effects;
  @override
  List<ItemEffect> get effects {
    if (_effects is EqualUnmodifiableListView) return _effects;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_effects);
  }

  @override
  String toString() {
    return 'LevelEvent.changeLevel(level: $level, effects: $effects)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChangeLevelImpl &&
            (identical(other.level, level) || other.level == level) &&
            const DeepCollectionEquality().equals(other._effects, _effects));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, level, const DeepCollectionEquality().hash(_effects));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChangeLevelImplCopyWith<_$ChangeLevelImpl> get copyWith =>
      __$$ChangeLevelImplCopyWithImpl<_$ChangeLevelImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int level, List<ItemEffect> effects) changeLevel,
    required TResult Function(FigureEvent figure) startFigure,
    required TResult Function(MiniGame game) startMiniGame,
    required TResult Function() finishMiniGame,
    required TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)
        startRandomFigure,
    required TResult Function(double speed, List<ItemEffect> effects)
        changeSpeed,
    required TResult Function() finishFigure,
  }) {
    return changeLevel(level, effects);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult? Function(FigureEvent figure)? startFigure,
    TResult? Function(MiniGame game)? startMiniGame,
    TResult? Function()? finishMiniGame,
    TResult? Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult? Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult? Function()? finishFigure,
  }) {
    return changeLevel?.call(level, effects);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult Function(FigureEvent figure)? startFigure,
    TResult Function(MiniGame game)? startMiniGame,
    TResult Function()? finishMiniGame,
    TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult Function()? finishFigure,
    required TResult orElse(),
  }) {
    if (changeLevel != null) {
      return changeLevel(level, effects);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_ChangeLevel value) changeLevel,
    required TResult Function(_StartFigure value) startFigure,
    required TResult Function(_StartMiniGame value) startMiniGame,
    required TResult Function(_FinishMiniGame value) finishMiniGame,
    required TResult Function(_StartRandomFigure value) startRandomFigure,
    required TResult Function(_ChangeSpeed value) changeSpeed,
    required TResult Function(_FinishFigure value) finishFigure,
  }) {
    return changeLevel(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_ChangeLevel value)? changeLevel,
    TResult? Function(_StartFigure value)? startFigure,
    TResult? Function(_StartMiniGame value)? startMiniGame,
    TResult? Function(_FinishMiniGame value)? finishMiniGame,
    TResult? Function(_StartRandomFigure value)? startRandomFigure,
    TResult? Function(_ChangeSpeed value)? changeSpeed,
    TResult? Function(_FinishFigure value)? finishFigure,
  }) {
    return changeLevel?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_ChangeLevel value)? changeLevel,
    TResult Function(_StartFigure value)? startFigure,
    TResult Function(_StartMiniGame value)? startMiniGame,
    TResult Function(_FinishMiniGame value)? finishMiniGame,
    TResult Function(_StartRandomFigure value)? startRandomFigure,
    TResult Function(_ChangeSpeed value)? changeSpeed,
    TResult Function(_FinishFigure value)? finishFigure,
    required TResult orElse(),
  }) {
    if (changeLevel != null) {
      return changeLevel(this);
    }
    return orElse();
  }
}

abstract class _ChangeLevel implements LevelEvent {
  const factory _ChangeLevel(
      {required final int level,
      required final List<ItemEffect> effects}) = _$ChangeLevelImpl;

  int get level;
  List<ItemEffect> get effects;
  @JsonKey(ignore: true)
  _$$ChangeLevelImplCopyWith<_$ChangeLevelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$StartFigureImplCopyWith<$Res> {
  factory _$$StartFigureImplCopyWith(
          _$StartFigureImpl value, $Res Function(_$StartFigureImpl) then) =
      __$$StartFigureImplCopyWithImpl<$Res>;
  @useResult
  $Res call({FigureEvent figure});

  $FigureEventCopyWith<$Res> get figure;
}

/// @nodoc
class __$$StartFigureImplCopyWithImpl<$Res>
    extends _$LevelEventCopyWithImpl<$Res, _$StartFigureImpl>
    implements _$$StartFigureImplCopyWith<$Res> {
  __$$StartFigureImplCopyWithImpl(
      _$StartFigureImpl _value, $Res Function(_$StartFigureImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? figure = null,
  }) {
    return _then(_$StartFigureImpl(
      figure: null == figure
          ? _value.figure
          : figure // ignore: cast_nullable_to_non_nullable
              as FigureEvent,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $FigureEventCopyWith<$Res> get figure {
    return $FigureEventCopyWith<$Res>(_value.figure, (value) {
      return _then(_value.copyWith(figure: value));
    });
  }
}

/// @nodoc

class _$StartFigureImpl implements _StartFigure {
  const _$StartFigureImpl({required this.figure});

  @override
  final FigureEvent figure;

  @override
  String toString() {
    return 'LevelEvent.startFigure(figure: $figure)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StartFigureImpl &&
            (identical(other.figure, figure) || other.figure == figure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, figure);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$StartFigureImplCopyWith<_$StartFigureImpl> get copyWith =>
      __$$StartFigureImplCopyWithImpl<_$StartFigureImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int level, List<ItemEffect> effects) changeLevel,
    required TResult Function(FigureEvent figure) startFigure,
    required TResult Function(MiniGame game) startMiniGame,
    required TResult Function() finishMiniGame,
    required TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)
        startRandomFigure,
    required TResult Function(double speed, List<ItemEffect> effects)
        changeSpeed,
    required TResult Function() finishFigure,
  }) {
    return startFigure(figure);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult? Function(FigureEvent figure)? startFigure,
    TResult? Function(MiniGame game)? startMiniGame,
    TResult? Function()? finishMiniGame,
    TResult? Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult? Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult? Function()? finishFigure,
  }) {
    return startFigure?.call(figure);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult Function(FigureEvent figure)? startFigure,
    TResult Function(MiniGame game)? startMiniGame,
    TResult Function()? finishMiniGame,
    TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult Function()? finishFigure,
    required TResult orElse(),
  }) {
    if (startFigure != null) {
      return startFigure(figure);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_ChangeLevel value) changeLevel,
    required TResult Function(_StartFigure value) startFigure,
    required TResult Function(_StartMiniGame value) startMiniGame,
    required TResult Function(_FinishMiniGame value) finishMiniGame,
    required TResult Function(_StartRandomFigure value) startRandomFigure,
    required TResult Function(_ChangeSpeed value) changeSpeed,
    required TResult Function(_FinishFigure value) finishFigure,
  }) {
    return startFigure(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_ChangeLevel value)? changeLevel,
    TResult? Function(_StartFigure value)? startFigure,
    TResult? Function(_StartMiniGame value)? startMiniGame,
    TResult? Function(_FinishMiniGame value)? finishMiniGame,
    TResult? Function(_StartRandomFigure value)? startRandomFigure,
    TResult? Function(_ChangeSpeed value)? changeSpeed,
    TResult? Function(_FinishFigure value)? finishFigure,
  }) {
    return startFigure?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_ChangeLevel value)? changeLevel,
    TResult Function(_StartFigure value)? startFigure,
    TResult Function(_StartMiniGame value)? startMiniGame,
    TResult Function(_FinishMiniGame value)? finishMiniGame,
    TResult Function(_StartRandomFigure value)? startRandomFigure,
    TResult Function(_ChangeSpeed value)? changeSpeed,
    TResult Function(_FinishFigure value)? finishFigure,
    required TResult orElse(),
  }) {
    if (startFigure != null) {
      return startFigure(this);
    }
    return orElse();
  }
}

abstract class _StartFigure implements LevelEvent {
  const factory _StartFigure({required final FigureEvent figure}) =
      _$StartFigureImpl;

  FigureEvent get figure;
  @JsonKey(ignore: true)
  _$$StartFigureImplCopyWith<_$StartFigureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$StartMiniGameImplCopyWith<$Res> {
  factory _$$StartMiniGameImplCopyWith(
          _$StartMiniGameImpl value, $Res Function(_$StartMiniGameImpl) then) =
      __$$StartMiniGameImplCopyWithImpl<$Res>;
  @useResult
  $Res call({MiniGame game});

  $MiniGameCopyWith<$Res> get game;
}

/// @nodoc
class __$$StartMiniGameImplCopyWithImpl<$Res>
    extends _$LevelEventCopyWithImpl<$Res, _$StartMiniGameImpl>
    implements _$$StartMiniGameImplCopyWith<$Res> {
  __$$StartMiniGameImplCopyWithImpl(
      _$StartMiniGameImpl _value, $Res Function(_$StartMiniGameImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? game = null,
  }) {
    return _then(_$StartMiniGameImpl(
      game: null == game
          ? _value.game
          : game // ignore: cast_nullable_to_non_nullable
              as MiniGame,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $MiniGameCopyWith<$Res> get game {
    return $MiniGameCopyWith<$Res>(_value.game, (value) {
      return _then(_value.copyWith(game: value));
    });
  }
}

/// @nodoc

class _$StartMiniGameImpl implements _StartMiniGame {
  const _$StartMiniGameImpl({required this.game});

  @override
  final MiniGame game;

  @override
  String toString() {
    return 'LevelEvent.startMiniGame(game: $game)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StartMiniGameImpl &&
            (identical(other.game, game) || other.game == game));
  }

  @override
  int get hashCode => Object.hash(runtimeType, game);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$StartMiniGameImplCopyWith<_$StartMiniGameImpl> get copyWith =>
      __$$StartMiniGameImplCopyWithImpl<_$StartMiniGameImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int level, List<ItemEffect> effects) changeLevel,
    required TResult Function(FigureEvent figure) startFigure,
    required TResult Function(MiniGame game) startMiniGame,
    required TResult Function() finishMiniGame,
    required TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)
        startRandomFigure,
    required TResult Function(double speed, List<ItemEffect> effects)
        changeSpeed,
    required TResult Function() finishFigure,
  }) {
    return startMiniGame(game);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult? Function(FigureEvent figure)? startFigure,
    TResult? Function(MiniGame game)? startMiniGame,
    TResult? Function()? finishMiniGame,
    TResult? Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult? Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult? Function()? finishFigure,
  }) {
    return startMiniGame?.call(game);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult Function(FigureEvent figure)? startFigure,
    TResult Function(MiniGame game)? startMiniGame,
    TResult Function()? finishMiniGame,
    TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult Function()? finishFigure,
    required TResult orElse(),
  }) {
    if (startMiniGame != null) {
      return startMiniGame(game);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_ChangeLevel value) changeLevel,
    required TResult Function(_StartFigure value) startFigure,
    required TResult Function(_StartMiniGame value) startMiniGame,
    required TResult Function(_FinishMiniGame value) finishMiniGame,
    required TResult Function(_StartRandomFigure value) startRandomFigure,
    required TResult Function(_ChangeSpeed value) changeSpeed,
    required TResult Function(_FinishFigure value) finishFigure,
  }) {
    return startMiniGame(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_ChangeLevel value)? changeLevel,
    TResult? Function(_StartFigure value)? startFigure,
    TResult? Function(_StartMiniGame value)? startMiniGame,
    TResult? Function(_FinishMiniGame value)? finishMiniGame,
    TResult? Function(_StartRandomFigure value)? startRandomFigure,
    TResult? Function(_ChangeSpeed value)? changeSpeed,
    TResult? Function(_FinishFigure value)? finishFigure,
  }) {
    return startMiniGame?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_ChangeLevel value)? changeLevel,
    TResult Function(_StartFigure value)? startFigure,
    TResult Function(_StartMiniGame value)? startMiniGame,
    TResult Function(_FinishMiniGame value)? finishMiniGame,
    TResult Function(_StartRandomFigure value)? startRandomFigure,
    TResult Function(_ChangeSpeed value)? changeSpeed,
    TResult Function(_FinishFigure value)? finishFigure,
    required TResult orElse(),
  }) {
    if (startMiniGame != null) {
      return startMiniGame(this);
    }
    return orElse();
  }
}

abstract class _StartMiniGame implements LevelEvent {
  const factory _StartMiniGame({required final MiniGame game}) =
      _$StartMiniGameImpl;

  MiniGame get game;
  @JsonKey(ignore: true)
  _$$StartMiniGameImplCopyWith<_$StartMiniGameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FinishMiniGameImplCopyWith<$Res> {
  factory _$$FinishMiniGameImplCopyWith(_$FinishMiniGameImpl value,
          $Res Function(_$FinishMiniGameImpl) then) =
      __$$FinishMiniGameImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$FinishMiniGameImplCopyWithImpl<$Res>
    extends _$LevelEventCopyWithImpl<$Res, _$FinishMiniGameImpl>
    implements _$$FinishMiniGameImplCopyWith<$Res> {
  __$$FinishMiniGameImplCopyWithImpl(
      _$FinishMiniGameImpl _value, $Res Function(_$FinishMiniGameImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$FinishMiniGameImpl implements _FinishMiniGame {
  const _$FinishMiniGameImpl();

  @override
  String toString() {
    return 'LevelEvent.finishMiniGame()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$FinishMiniGameImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int level, List<ItemEffect> effects) changeLevel,
    required TResult Function(FigureEvent figure) startFigure,
    required TResult Function(MiniGame game) startMiniGame,
    required TResult Function() finishMiniGame,
    required TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)
        startRandomFigure,
    required TResult Function(double speed, List<ItemEffect> effects)
        changeSpeed,
    required TResult Function() finishFigure,
  }) {
    return finishMiniGame();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult? Function(FigureEvent figure)? startFigure,
    TResult? Function(MiniGame game)? startMiniGame,
    TResult? Function()? finishMiniGame,
    TResult? Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult? Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult? Function()? finishFigure,
  }) {
    return finishMiniGame?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult Function(FigureEvent figure)? startFigure,
    TResult Function(MiniGame game)? startMiniGame,
    TResult Function()? finishMiniGame,
    TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult Function()? finishFigure,
    required TResult orElse(),
  }) {
    if (finishMiniGame != null) {
      return finishMiniGame();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_ChangeLevel value) changeLevel,
    required TResult Function(_StartFigure value) startFigure,
    required TResult Function(_StartMiniGame value) startMiniGame,
    required TResult Function(_FinishMiniGame value) finishMiniGame,
    required TResult Function(_StartRandomFigure value) startRandomFigure,
    required TResult Function(_ChangeSpeed value) changeSpeed,
    required TResult Function(_FinishFigure value) finishFigure,
  }) {
    return finishMiniGame(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_ChangeLevel value)? changeLevel,
    TResult? Function(_StartFigure value)? startFigure,
    TResult? Function(_StartMiniGame value)? startMiniGame,
    TResult? Function(_FinishMiniGame value)? finishMiniGame,
    TResult? Function(_StartRandomFigure value)? startRandomFigure,
    TResult? Function(_ChangeSpeed value)? changeSpeed,
    TResult? Function(_FinishFigure value)? finishFigure,
  }) {
    return finishMiniGame?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_ChangeLevel value)? changeLevel,
    TResult Function(_StartFigure value)? startFigure,
    TResult Function(_StartMiniGame value)? startMiniGame,
    TResult Function(_FinishMiniGame value)? finishMiniGame,
    TResult Function(_StartRandomFigure value)? startRandomFigure,
    TResult Function(_ChangeSpeed value)? changeSpeed,
    TResult Function(_FinishFigure value)? finishFigure,
    required TResult orElse(),
  }) {
    if (finishMiniGame != null) {
      return finishMiniGame(this);
    }
    return orElse();
  }
}

abstract class _FinishMiniGame implements LevelEvent {
  const factory _FinishMiniGame() = _$FinishMiniGameImpl;
}

/// @nodoc
abstract class _$$StartRandomFigureImplCopyWith<$Res> {
  factory _$$StartRandomFigureImplCopyWith(_$StartRandomFigureImpl value,
          $Res Function(_$StartRandomFigureImpl) then) =
      __$$StartRandomFigureImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {List<FigureEvent>? figures,
      Items? slowMoItem,
      Items? punch,
      Items? guard});
}

/// @nodoc
class __$$StartRandomFigureImplCopyWithImpl<$Res>
    extends _$LevelEventCopyWithImpl<$Res, _$StartRandomFigureImpl>
    implements _$$StartRandomFigureImplCopyWith<$Res> {
  __$$StartRandomFigureImplCopyWithImpl(_$StartRandomFigureImpl _value,
      $Res Function(_$StartRandomFigureImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? figures = freezed,
    Object? slowMoItem = freezed,
    Object? punch = freezed,
    Object? guard = freezed,
  }) {
    return _then(_$StartRandomFigureImpl(
      figures: freezed == figures
          ? _value._figures
          : figures // ignore: cast_nullable_to_non_nullable
              as List<FigureEvent>?,
      slowMoItem: freezed == slowMoItem
          ? _value.slowMoItem
          : slowMoItem // ignore: cast_nullable_to_non_nullable
              as Items?,
      punch: freezed == punch
          ? _value.punch
          : punch // ignore: cast_nullable_to_non_nullable
              as Items?,
      guard: freezed == guard
          ? _value.guard
          : guard // ignore: cast_nullable_to_non_nullable
              as Items?,
    ));
  }
}

/// @nodoc

class _$StartRandomFigureImpl implements _StartRandomFigure {
  const _$StartRandomFigureImpl(
      {final List<FigureEvent>? figures,
      required this.slowMoItem,
      required this.punch,
      required this.guard})
      : _figures = figures;

  final List<FigureEvent>? _figures;
  @override
  List<FigureEvent>? get figures {
    final value = _figures;
    if (value == null) return null;
    if (_figures is EqualUnmodifiableListView) return _figures;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final Items? slowMoItem;
  @override
  final Items? punch;
  @override
  final Items? guard;

  @override
  String toString() {
    return 'LevelEvent.startRandomFigure(figures: $figures, slowMoItem: $slowMoItem, punch: $punch, guard: $guard)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StartRandomFigureImpl &&
            const DeepCollectionEquality().equals(other._figures, _figures) &&
            (identical(other.slowMoItem, slowMoItem) ||
                other.slowMoItem == slowMoItem) &&
            (identical(other.punch, punch) || other.punch == punch) &&
            (identical(other.guard, guard) || other.guard == guard));
  }

  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_figures), slowMoItem, punch, guard);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$StartRandomFigureImplCopyWith<_$StartRandomFigureImpl> get copyWith =>
      __$$StartRandomFigureImplCopyWithImpl<_$StartRandomFigureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int level, List<ItemEffect> effects) changeLevel,
    required TResult Function(FigureEvent figure) startFigure,
    required TResult Function(MiniGame game) startMiniGame,
    required TResult Function() finishMiniGame,
    required TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)
        startRandomFigure,
    required TResult Function(double speed, List<ItemEffect> effects)
        changeSpeed,
    required TResult Function() finishFigure,
  }) {
    return startRandomFigure(figures, slowMoItem, punch, guard);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult? Function(FigureEvent figure)? startFigure,
    TResult? Function(MiniGame game)? startMiniGame,
    TResult? Function()? finishMiniGame,
    TResult? Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult? Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult? Function()? finishFigure,
  }) {
    return startRandomFigure?.call(figures, slowMoItem, punch, guard);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult Function(FigureEvent figure)? startFigure,
    TResult Function(MiniGame game)? startMiniGame,
    TResult Function()? finishMiniGame,
    TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult Function()? finishFigure,
    required TResult orElse(),
  }) {
    if (startRandomFigure != null) {
      return startRandomFigure(figures, slowMoItem, punch, guard);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_ChangeLevel value) changeLevel,
    required TResult Function(_StartFigure value) startFigure,
    required TResult Function(_StartMiniGame value) startMiniGame,
    required TResult Function(_FinishMiniGame value) finishMiniGame,
    required TResult Function(_StartRandomFigure value) startRandomFigure,
    required TResult Function(_ChangeSpeed value) changeSpeed,
    required TResult Function(_FinishFigure value) finishFigure,
  }) {
    return startRandomFigure(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_ChangeLevel value)? changeLevel,
    TResult? Function(_StartFigure value)? startFigure,
    TResult? Function(_StartMiniGame value)? startMiniGame,
    TResult? Function(_FinishMiniGame value)? finishMiniGame,
    TResult? Function(_StartRandomFigure value)? startRandomFigure,
    TResult? Function(_ChangeSpeed value)? changeSpeed,
    TResult? Function(_FinishFigure value)? finishFigure,
  }) {
    return startRandomFigure?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_ChangeLevel value)? changeLevel,
    TResult Function(_StartFigure value)? startFigure,
    TResult Function(_StartMiniGame value)? startMiniGame,
    TResult Function(_FinishMiniGame value)? finishMiniGame,
    TResult Function(_StartRandomFigure value)? startRandomFigure,
    TResult Function(_ChangeSpeed value)? changeSpeed,
    TResult Function(_FinishFigure value)? finishFigure,
    required TResult orElse(),
  }) {
    if (startRandomFigure != null) {
      return startRandomFigure(this);
    }
    return orElse();
  }
}

abstract class _StartRandomFigure implements LevelEvent {
  const factory _StartRandomFigure(
      {final List<FigureEvent>? figures,
      required final Items? slowMoItem,
      required final Items? punch,
      required final Items? guard}) = _$StartRandomFigureImpl;

  List<FigureEvent>? get figures;
  Items? get slowMoItem;
  Items? get punch;
  Items? get guard;
  @JsonKey(ignore: true)
  _$$StartRandomFigureImplCopyWith<_$StartRandomFigureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ChangeSpeedImplCopyWith<$Res> {
  factory _$$ChangeSpeedImplCopyWith(
          _$ChangeSpeedImpl value, $Res Function(_$ChangeSpeedImpl) then) =
      __$$ChangeSpeedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({double speed, List<ItemEffect> effects});
}

/// @nodoc
class __$$ChangeSpeedImplCopyWithImpl<$Res>
    extends _$LevelEventCopyWithImpl<$Res, _$ChangeSpeedImpl>
    implements _$$ChangeSpeedImplCopyWith<$Res> {
  __$$ChangeSpeedImplCopyWithImpl(
      _$ChangeSpeedImpl _value, $Res Function(_$ChangeSpeedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? speed = null,
    Object? effects = null,
  }) {
    return _then(_$ChangeSpeedImpl(
      speed: null == speed
          ? _value.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double,
      effects: null == effects
          ? _value._effects
          : effects // ignore: cast_nullable_to_non_nullable
              as List<ItemEffect>,
    ));
  }
}

/// @nodoc

class _$ChangeSpeedImpl implements _ChangeSpeed {
  const _$ChangeSpeedImpl(
      {required this.speed, required final List<ItemEffect> effects})
      : _effects = effects;

  @override
  final double speed;
  final List<ItemEffect> _effects;
  @override
  List<ItemEffect> get effects {
    if (_effects is EqualUnmodifiableListView) return _effects;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_effects);
  }

  @override
  String toString() {
    return 'LevelEvent.changeSpeed(speed: $speed, effects: $effects)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChangeSpeedImpl &&
            (identical(other.speed, speed) || other.speed == speed) &&
            const DeepCollectionEquality().equals(other._effects, _effects));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, speed, const DeepCollectionEquality().hash(_effects));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChangeSpeedImplCopyWith<_$ChangeSpeedImpl> get copyWith =>
      __$$ChangeSpeedImplCopyWithImpl<_$ChangeSpeedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int level, List<ItemEffect> effects) changeLevel,
    required TResult Function(FigureEvent figure) startFigure,
    required TResult Function(MiniGame game) startMiniGame,
    required TResult Function() finishMiniGame,
    required TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)
        startRandomFigure,
    required TResult Function(double speed, List<ItemEffect> effects)
        changeSpeed,
    required TResult Function() finishFigure,
  }) {
    return changeSpeed(speed, effects);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult? Function(FigureEvent figure)? startFigure,
    TResult? Function(MiniGame game)? startMiniGame,
    TResult? Function()? finishMiniGame,
    TResult? Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult? Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult? Function()? finishFigure,
  }) {
    return changeSpeed?.call(speed, effects);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult Function(FigureEvent figure)? startFigure,
    TResult Function(MiniGame game)? startMiniGame,
    TResult Function()? finishMiniGame,
    TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult Function()? finishFigure,
    required TResult orElse(),
  }) {
    if (changeSpeed != null) {
      return changeSpeed(speed, effects);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_ChangeLevel value) changeLevel,
    required TResult Function(_StartFigure value) startFigure,
    required TResult Function(_StartMiniGame value) startMiniGame,
    required TResult Function(_FinishMiniGame value) finishMiniGame,
    required TResult Function(_StartRandomFigure value) startRandomFigure,
    required TResult Function(_ChangeSpeed value) changeSpeed,
    required TResult Function(_FinishFigure value) finishFigure,
  }) {
    return changeSpeed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_ChangeLevel value)? changeLevel,
    TResult? Function(_StartFigure value)? startFigure,
    TResult? Function(_StartMiniGame value)? startMiniGame,
    TResult? Function(_FinishMiniGame value)? finishMiniGame,
    TResult? Function(_StartRandomFigure value)? startRandomFigure,
    TResult? Function(_ChangeSpeed value)? changeSpeed,
    TResult? Function(_FinishFigure value)? finishFigure,
  }) {
    return changeSpeed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_ChangeLevel value)? changeLevel,
    TResult Function(_StartFigure value)? startFigure,
    TResult Function(_StartMiniGame value)? startMiniGame,
    TResult Function(_FinishMiniGame value)? finishMiniGame,
    TResult Function(_StartRandomFigure value)? startRandomFigure,
    TResult Function(_ChangeSpeed value)? changeSpeed,
    TResult Function(_FinishFigure value)? finishFigure,
    required TResult orElse(),
  }) {
    if (changeSpeed != null) {
      return changeSpeed(this);
    }
    return orElse();
  }
}

abstract class _ChangeSpeed implements LevelEvent {
  const factory _ChangeSpeed(
      {required final double speed,
      required final List<ItemEffect> effects}) = _$ChangeSpeedImpl;

  double get speed;
  List<ItemEffect> get effects;
  @JsonKey(ignore: true)
  _$$ChangeSpeedImplCopyWith<_$ChangeSpeedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FinishFigureImplCopyWith<$Res> {
  factory _$$FinishFigureImplCopyWith(
          _$FinishFigureImpl value, $Res Function(_$FinishFigureImpl) then) =
      __$$FinishFigureImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$FinishFigureImplCopyWithImpl<$Res>
    extends _$LevelEventCopyWithImpl<$Res, _$FinishFigureImpl>
    implements _$$FinishFigureImplCopyWith<$Res> {
  __$$FinishFigureImplCopyWithImpl(
      _$FinishFigureImpl _value, $Res Function(_$FinishFigureImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$FinishFigureImpl implements _FinishFigure {
  const _$FinishFigureImpl();

  @override
  String toString() {
    return 'LevelEvent.finishFigure()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$FinishFigureImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int level, List<ItemEffect> effects) changeLevel,
    required TResult Function(FigureEvent figure) startFigure,
    required TResult Function(MiniGame game) startMiniGame,
    required TResult Function() finishMiniGame,
    required TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)
        startRandomFigure,
    required TResult Function(double speed, List<ItemEffect> effects)
        changeSpeed,
    required TResult Function() finishFigure,
  }) {
    return finishFigure();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult? Function(FigureEvent figure)? startFigure,
    TResult? Function(MiniGame game)? startMiniGame,
    TResult? Function()? finishMiniGame,
    TResult? Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult? Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult? Function()? finishFigure,
  }) {
    return finishFigure?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int level, List<ItemEffect> effects)? changeLevel,
    TResult Function(FigureEvent figure)? startFigure,
    TResult Function(MiniGame game)? startMiniGame,
    TResult Function()? finishMiniGame,
    TResult Function(List<FigureEvent>? figures, Items? slowMoItem,
            Items? punch, Items? guard)?
        startRandomFigure,
    TResult Function(double speed, List<ItemEffect> effects)? changeSpeed,
    TResult Function()? finishFigure,
    required TResult orElse(),
  }) {
    if (finishFigure != null) {
      return finishFigure();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_ChangeLevel value) changeLevel,
    required TResult Function(_StartFigure value) startFigure,
    required TResult Function(_StartMiniGame value) startMiniGame,
    required TResult Function(_FinishMiniGame value) finishMiniGame,
    required TResult Function(_StartRandomFigure value) startRandomFigure,
    required TResult Function(_ChangeSpeed value) changeSpeed,
    required TResult Function(_FinishFigure value) finishFigure,
  }) {
    return finishFigure(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_ChangeLevel value)? changeLevel,
    TResult? Function(_StartFigure value)? startFigure,
    TResult? Function(_StartMiniGame value)? startMiniGame,
    TResult? Function(_FinishMiniGame value)? finishMiniGame,
    TResult? Function(_StartRandomFigure value)? startRandomFigure,
    TResult? Function(_ChangeSpeed value)? changeSpeed,
    TResult? Function(_FinishFigure value)? finishFigure,
  }) {
    return finishFigure?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_ChangeLevel value)? changeLevel,
    TResult Function(_StartFigure value)? startFigure,
    TResult Function(_StartMiniGame value)? startMiniGame,
    TResult Function(_FinishMiniGame value)? finishMiniGame,
    TResult Function(_StartRandomFigure value)? startRandomFigure,
    TResult Function(_ChangeSpeed value)? changeSpeed,
    TResult Function(_FinishFigure value)? finishFigure,
    required TResult orElse(),
  }) {
    if (finishFigure != null) {
      return finishFigure(this);
    }
    return orElse();
  }
}

abstract class _FinishFigure implements LevelEvent {
  const factory _FinishFigure() = _$FinishFigureImpl;
}

/// @nodoc
mixin _$FigureEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() trashWall,
    required TResult Function(Items guard) guardedPizza,
    required TResult Function(Items guard) cursedPath,
    required TResult Function(Items punchItem) punchWave,
    required TResult Function() bigBuddyBin,
    required TResult Function() unreachablePizza,
    required TResult Function(Items guard) only2Lines,
    required TResult Function(Items slowMoItem) slowMo,
    required TResult Function(Items item) winLabel,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? trashWall,
    TResult? Function(Items guard)? guardedPizza,
    TResult? Function(Items guard)? cursedPath,
    TResult? Function(Items punchItem)? punchWave,
    TResult? Function()? bigBuddyBin,
    TResult? Function()? unreachablePizza,
    TResult? Function(Items guard)? only2Lines,
    TResult? Function(Items slowMoItem)? slowMo,
    TResult? Function(Items item)? winLabel,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? trashWall,
    TResult Function(Items guard)? guardedPizza,
    TResult Function(Items guard)? cursedPath,
    TResult Function(Items punchItem)? punchWave,
    TResult Function()? bigBuddyBin,
    TResult Function()? unreachablePizza,
    TResult Function(Items guard)? only2Lines,
    TResult Function(Items slowMoItem)? slowMo,
    TResult Function(Items item)? winLabel,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TrashWall value) trashWall,
    required TResult Function(_GuardedPizza value) guardedPizza,
    required TResult Function(_CursedPath value) cursedPath,
    required TResult Function(_PunchWave value) punchWave,
    required TResult Function(_BigBuddyBin value) bigBuddyBin,
    required TResult Function(_UnreachablePizza value) unreachablePizza,
    required TResult Function(_Only2Times value) only2Lines,
    required TResult Function(_SlowMo value) slowMo,
    required TResult Function(_WinLabel value) winLabel,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TrashWall value)? trashWall,
    TResult? Function(_GuardedPizza value)? guardedPizza,
    TResult? Function(_CursedPath value)? cursedPath,
    TResult? Function(_PunchWave value)? punchWave,
    TResult? Function(_BigBuddyBin value)? bigBuddyBin,
    TResult? Function(_UnreachablePizza value)? unreachablePizza,
    TResult? Function(_Only2Times value)? only2Lines,
    TResult? Function(_SlowMo value)? slowMo,
    TResult? Function(_WinLabel value)? winLabel,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TrashWall value)? trashWall,
    TResult Function(_GuardedPizza value)? guardedPizza,
    TResult Function(_CursedPath value)? cursedPath,
    TResult Function(_PunchWave value)? punchWave,
    TResult Function(_BigBuddyBin value)? bigBuddyBin,
    TResult Function(_UnreachablePizza value)? unreachablePizza,
    TResult Function(_Only2Times value)? only2Lines,
    TResult Function(_SlowMo value)? slowMo,
    TResult Function(_WinLabel value)? winLabel,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FigureEventCopyWith<$Res> {
  factory $FigureEventCopyWith(
          FigureEvent value, $Res Function(FigureEvent) then) =
      _$FigureEventCopyWithImpl<$Res, FigureEvent>;
}

/// @nodoc
class _$FigureEventCopyWithImpl<$Res, $Val extends FigureEvent>
    implements $FigureEventCopyWith<$Res> {
  _$FigureEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$TrashWallImplCopyWith<$Res> {
  factory _$$TrashWallImplCopyWith(
          _$TrashWallImpl value, $Res Function(_$TrashWallImpl) then) =
      __$$TrashWallImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$TrashWallImplCopyWithImpl<$Res>
    extends _$FigureEventCopyWithImpl<$Res, _$TrashWallImpl>
    implements _$$TrashWallImplCopyWith<$Res> {
  __$$TrashWallImplCopyWithImpl(
      _$TrashWallImpl _value, $Res Function(_$TrashWallImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$TrashWallImpl implements _TrashWall {
  const _$TrashWallImpl();

  @override
  String toString() {
    return 'FigureEvent.trashWall()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$TrashWallImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() trashWall,
    required TResult Function(Items guard) guardedPizza,
    required TResult Function(Items guard) cursedPath,
    required TResult Function(Items punchItem) punchWave,
    required TResult Function() bigBuddyBin,
    required TResult Function() unreachablePizza,
    required TResult Function(Items guard) only2Lines,
    required TResult Function(Items slowMoItem) slowMo,
    required TResult Function(Items item) winLabel,
  }) {
    return trashWall();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? trashWall,
    TResult? Function(Items guard)? guardedPizza,
    TResult? Function(Items guard)? cursedPath,
    TResult? Function(Items punchItem)? punchWave,
    TResult? Function()? bigBuddyBin,
    TResult? Function()? unreachablePizza,
    TResult? Function(Items guard)? only2Lines,
    TResult? Function(Items slowMoItem)? slowMo,
    TResult? Function(Items item)? winLabel,
  }) {
    return trashWall?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? trashWall,
    TResult Function(Items guard)? guardedPizza,
    TResult Function(Items guard)? cursedPath,
    TResult Function(Items punchItem)? punchWave,
    TResult Function()? bigBuddyBin,
    TResult Function()? unreachablePizza,
    TResult Function(Items guard)? only2Lines,
    TResult Function(Items slowMoItem)? slowMo,
    TResult Function(Items item)? winLabel,
    required TResult orElse(),
  }) {
    if (trashWall != null) {
      return trashWall();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TrashWall value) trashWall,
    required TResult Function(_GuardedPizza value) guardedPizza,
    required TResult Function(_CursedPath value) cursedPath,
    required TResult Function(_PunchWave value) punchWave,
    required TResult Function(_BigBuddyBin value) bigBuddyBin,
    required TResult Function(_UnreachablePizza value) unreachablePizza,
    required TResult Function(_Only2Times value) only2Lines,
    required TResult Function(_SlowMo value) slowMo,
    required TResult Function(_WinLabel value) winLabel,
  }) {
    return trashWall(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TrashWall value)? trashWall,
    TResult? Function(_GuardedPizza value)? guardedPizza,
    TResult? Function(_CursedPath value)? cursedPath,
    TResult? Function(_PunchWave value)? punchWave,
    TResult? Function(_BigBuddyBin value)? bigBuddyBin,
    TResult? Function(_UnreachablePizza value)? unreachablePizza,
    TResult? Function(_Only2Times value)? only2Lines,
    TResult? Function(_SlowMo value)? slowMo,
    TResult? Function(_WinLabel value)? winLabel,
  }) {
    return trashWall?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TrashWall value)? trashWall,
    TResult Function(_GuardedPizza value)? guardedPizza,
    TResult Function(_CursedPath value)? cursedPath,
    TResult Function(_PunchWave value)? punchWave,
    TResult Function(_BigBuddyBin value)? bigBuddyBin,
    TResult Function(_UnreachablePizza value)? unreachablePizza,
    TResult Function(_Only2Times value)? only2Lines,
    TResult Function(_SlowMo value)? slowMo,
    TResult Function(_WinLabel value)? winLabel,
    required TResult orElse(),
  }) {
    if (trashWall != null) {
      return trashWall(this);
    }
    return orElse();
  }
}

abstract class _TrashWall implements FigureEvent {
  const factory _TrashWall() = _$TrashWallImpl;
}

/// @nodoc
abstract class _$$GuardedPizzaImplCopyWith<$Res> {
  factory _$$GuardedPizzaImplCopyWith(
          _$GuardedPizzaImpl value, $Res Function(_$GuardedPizzaImpl) then) =
      __$$GuardedPizzaImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Items guard});
}

/// @nodoc
class __$$GuardedPizzaImplCopyWithImpl<$Res>
    extends _$FigureEventCopyWithImpl<$Res, _$GuardedPizzaImpl>
    implements _$$GuardedPizzaImplCopyWith<$Res> {
  __$$GuardedPizzaImplCopyWithImpl(
      _$GuardedPizzaImpl _value, $Res Function(_$GuardedPizzaImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? guard = null,
  }) {
    return _then(_$GuardedPizzaImpl(
      guard: null == guard
          ? _value.guard
          : guard // ignore: cast_nullable_to_non_nullable
              as Items,
    ));
  }
}

/// @nodoc

class _$GuardedPizzaImpl implements _GuardedPizza {
  const _$GuardedPizzaImpl({required this.guard});

  @override
  final Items guard;

  @override
  String toString() {
    return 'FigureEvent.guardedPizza(guard: $guard)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GuardedPizzaImpl &&
            (identical(other.guard, guard) || other.guard == guard));
  }

  @override
  int get hashCode => Object.hash(runtimeType, guard);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GuardedPizzaImplCopyWith<_$GuardedPizzaImpl> get copyWith =>
      __$$GuardedPizzaImplCopyWithImpl<_$GuardedPizzaImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() trashWall,
    required TResult Function(Items guard) guardedPizza,
    required TResult Function(Items guard) cursedPath,
    required TResult Function(Items punchItem) punchWave,
    required TResult Function() bigBuddyBin,
    required TResult Function() unreachablePizza,
    required TResult Function(Items guard) only2Lines,
    required TResult Function(Items slowMoItem) slowMo,
    required TResult Function(Items item) winLabel,
  }) {
    return guardedPizza(guard);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? trashWall,
    TResult? Function(Items guard)? guardedPizza,
    TResult? Function(Items guard)? cursedPath,
    TResult? Function(Items punchItem)? punchWave,
    TResult? Function()? bigBuddyBin,
    TResult? Function()? unreachablePizza,
    TResult? Function(Items guard)? only2Lines,
    TResult? Function(Items slowMoItem)? slowMo,
    TResult? Function(Items item)? winLabel,
  }) {
    return guardedPizza?.call(guard);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? trashWall,
    TResult Function(Items guard)? guardedPizza,
    TResult Function(Items guard)? cursedPath,
    TResult Function(Items punchItem)? punchWave,
    TResult Function()? bigBuddyBin,
    TResult Function()? unreachablePizza,
    TResult Function(Items guard)? only2Lines,
    TResult Function(Items slowMoItem)? slowMo,
    TResult Function(Items item)? winLabel,
    required TResult orElse(),
  }) {
    if (guardedPizza != null) {
      return guardedPizza(guard);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TrashWall value) trashWall,
    required TResult Function(_GuardedPizza value) guardedPizza,
    required TResult Function(_CursedPath value) cursedPath,
    required TResult Function(_PunchWave value) punchWave,
    required TResult Function(_BigBuddyBin value) bigBuddyBin,
    required TResult Function(_UnreachablePizza value) unreachablePizza,
    required TResult Function(_Only2Times value) only2Lines,
    required TResult Function(_SlowMo value) slowMo,
    required TResult Function(_WinLabel value) winLabel,
  }) {
    return guardedPizza(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TrashWall value)? trashWall,
    TResult? Function(_GuardedPizza value)? guardedPizza,
    TResult? Function(_CursedPath value)? cursedPath,
    TResult? Function(_PunchWave value)? punchWave,
    TResult? Function(_BigBuddyBin value)? bigBuddyBin,
    TResult? Function(_UnreachablePizza value)? unreachablePizza,
    TResult? Function(_Only2Times value)? only2Lines,
    TResult? Function(_SlowMo value)? slowMo,
    TResult? Function(_WinLabel value)? winLabel,
  }) {
    return guardedPizza?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TrashWall value)? trashWall,
    TResult Function(_GuardedPizza value)? guardedPizza,
    TResult Function(_CursedPath value)? cursedPath,
    TResult Function(_PunchWave value)? punchWave,
    TResult Function(_BigBuddyBin value)? bigBuddyBin,
    TResult Function(_UnreachablePizza value)? unreachablePizza,
    TResult Function(_Only2Times value)? only2Lines,
    TResult Function(_SlowMo value)? slowMo,
    TResult Function(_WinLabel value)? winLabel,
    required TResult orElse(),
  }) {
    if (guardedPizza != null) {
      return guardedPizza(this);
    }
    return orElse();
  }
}

abstract class _GuardedPizza implements FigureEvent {
  const factory _GuardedPizza({required final Items guard}) =
      _$GuardedPizzaImpl;

  Items get guard;
  @JsonKey(ignore: true)
  _$$GuardedPizzaImplCopyWith<_$GuardedPizzaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$CursedPathImplCopyWith<$Res> {
  factory _$$CursedPathImplCopyWith(
          _$CursedPathImpl value, $Res Function(_$CursedPathImpl) then) =
      __$$CursedPathImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Items guard});
}

/// @nodoc
class __$$CursedPathImplCopyWithImpl<$Res>
    extends _$FigureEventCopyWithImpl<$Res, _$CursedPathImpl>
    implements _$$CursedPathImplCopyWith<$Res> {
  __$$CursedPathImplCopyWithImpl(
      _$CursedPathImpl _value, $Res Function(_$CursedPathImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? guard = null,
  }) {
    return _then(_$CursedPathImpl(
      guard: null == guard
          ? _value.guard
          : guard // ignore: cast_nullable_to_non_nullable
              as Items,
    ));
  }
}

/// @nodoc

class _$CursedPathImpl implements _CursedPath {
  const _$CursedPathImpl({required this.guard});

  @override
  final Items guard;

  @override
  String toString() {
    return 'FigureEvent.cursedPath(guard: $guard)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CursedPathImpl &&
            (identical(other.guard, guard) || other.guard == guard));
  }

  @override
  int get hashCode => Object.hash(runtimeType, guard);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CursedPathImplCopyWith<_$CursedPathImpl> get copyWith =>
      __$$CursedPathImplCopyWithImpl<_$CursedPathImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() trashWall,
    required TResult Function(Items guard) guardedPizza,
    required TResult Function(Items guard) cursedPath,
    required TResult Function(Items punchItem) punchWave,
    required TResult Function() bigBuddyBin,
    required TResult Function() unreachablePizza,
    required TResult Function(Items guard) only2Lines,
    required TResult Function(Items slowMoItem) slowMo,
    required TResult Function(Items item) winLabel,
  }) {
    return cursedPath(guard);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? trashWall,
    TResult? Function(Items guard)? guardedPizza,
    TResult? Function(Items guard)? cursedPath,
    TResult? Function(Items punchItem)? punchWave,
    TResult? Function()? bigBuddyBin,
    TResult? Function()? unreachablePizza,
    TResult? Function(Items guard)? only2Lines,
    TResult? Function(Items slowMoItem)? slowMo,
    TResult? Function(Items item)? winLabel,
  }) {
    return cursedPath?.call(guard);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? trashWall,
    TResult Function(Items guard)? guardedPizza,
    TResult Function(Items guard)? cursedPath,
    TResult Function(Items punchItem)? punchWave,
    TResult Function()? bigBuddyBin,
    TResult Function()? unreachablePizza,
    TResult Function(Items guard)? only2Lines,
    TResult Function(Items slowMoItem)? slowMo,
    TResult Function(Items item)? winLabel,
    required TResult orElse(),
  }) {
    if (cursedPath != null) {
      return cursedPath(guard);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TrashWall value) trashWall,
    required TResult Function(_GuardedPizza value) guardedPizza,
    required TResult Function(_CursedPath value) cursedPath,
    required TResult Function(_PunchWave value) punchWave,
    required TResult Function(_BigBuddyBin value) bigBuddyBin,
    required TResult Function(_UnreachablePizza value) unreachablePizza,
    required TResult Function(_Only2Times value) only2Lines,
    required TResult Function(_SlowMo value) slowMo,
    required TResult Function(_WinLabel value) winLabel,
  }) {
    return cursedPath(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TrashWall value)? trashWall,
    TResult? Function(_GuardedPizza value)? guardedPizza,
    TResult? Function(_CursedPath value)? cursedPath,
    TResult? Function(_PunchWave value)? punchWave,
    TResult? Function(_BigBuddyBin value)? bigBuddyBin,
    TResult? Function(_UnreachablePizza value)? unreachablePizza,
    TResult? Function(_Only2Times value)? only2Lines,
    TResult? Function(_SlowMo value)? slowMo,
    TResult? Function(_WinLabel value)? winLabel,
  }) {
    return cursedPath?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TrashWall value)? trashWall,
    TResult Function(_GuardedPizza value)? guardedPizza,
    TResult Function(_CursedPath value)? cursedPath,
    TResult Function(_PunchWave value)? punchWave,
    TResult Function(_BigBuddyBin value)? bigBuddyBin,
    TResult Function(_UnreachablePizza value)? unreachablePizza,
    TResult Function(_Only2Times value)? only2Lines,
    TResult Function(_SlowMo value)? slowMo,
    TResult Function(_WinLabel value)? winLabel,
    required TResult orElse(),
  }) {
    if (cursedPath != null) {
      return cursedPath(this);
    }
    return orElse();
  }
}

abstract class _CursedPath implements FigureEvent {
  const factory _CursedPath({required final Items guard}) = _$CursedPathImpl;

  Items get guard;
  @JsonKey(ignore: true)
  _$$CursedPathImplCopyWith<_$CursedPathImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PunchWaveImplCopyWith<$Res> {
  factory _$$PunchWaveImplCopyWith(
          _$PunchWaveImpl value, $Res Function(_$PunchWaveImpl) then) =
      __$$PunchWaveImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Items punchItem});
}

/// @nodoc
class __$$PunchWaveImplCopyWithImpl<$Res>
    extends _$FigureEventCopyWithImpl<$Res, _$PunchWaveImpl>
    implements _$$PunchWaveImplCopyWith<$Res> {
  __$$PunchWaveImplCopyWithImpl(
      _$PunchWaveImpl _value, $Res Function(_$PunchWaveImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? punchItem = null,
  }) {
    return _then(_$PunchWaveImpl(
      punchItem: null == punchItem
          ? _value.punchItem
          : punchItem // ignore: cast_nullable_to_non_nullable
              as Items,
    ));
  }
}

/// @nodoc

class _$PunchWaveImpl implements _PunchWave {
  const _$PunchWaveImpl({required this.punchItem});

  @override
  final Items punchItem;

  @override
  String toString() {
    return 'FigureEvent.punchWave(punchItem: $punchItem)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PunchWaveImpl &&
            (identical(other.punchItem, punchItem) ||
                other.punchItem == punchItem));
  }

  @override
  int get hashCode => Object.hash(runtimeType, punchItem);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PunchWaveImplCopyWith<_$PunchWaveImpl> get copyWith =>
      __$$PunchWaveImplCopyWithImpl<_$PunchWaveImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() trashWall,
    required TResult Function(Items guard) guardedPizza,
    required TResult Function(Items guard) cursedPath,
    required TResult Function(Items punchItem) punchWave,
    required TResult Function() bigBuddyBin,
    required TResult Function() unreachablePizza,
    required TResult Function(Items guard) only2Lines,
    required TResult Function(Items slowMoItem) slowMo,
    required TResult Function(Items item) winLabel,
  }) {
    return punchWave(punchItem);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? trashWall,
    TResult? Function(Items guard)? guardedPizza,
    TResult? Function(Items guard)? cursedPath,
    TResult? Function(Items punchItem)? punchWave,
    TResult? Function()? bigBuddyBin,
    TResult? Function()? unreachablePizza,
    TResult? Function(Items guard)? only2Lines,
    TResult? Function(Items slowMoItem)? slowMo,
    TResult? Function(Items item)? winLabel,
  }) {
    return punchWave?.call(punchItem);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? trashWall,
    TResult Function(Items guard)? guardedPizza,
    TResult Function(Items guard)? cursedPath,
    TResult Function(Items punchItem)? punchWave,
    TResult Function()? bigBuddyBin,
    TResult Function()? unreachablePizza,
    TResult Function(Items guard)? only2Lines,
    TResult Function(Items slowMoItem)? slowMo,
    TResult Function(Items item)? winLabel,
    required TResult orElse(),
  }) {
    if (punchWave != null) {
      return punchWave(punchItem);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TrashWall value) trashWall,
    required TResult Function(_GuardedPizza value) guardedPizza,
    required TResult Function(_CursedPath value) cursedPath,
    required TResult Function(_PunchWave value) punchWave,
    required TResult Function(_BigBuddyBin value) bigBuddyBin,
    required TResult Function(_UnreachablePizza value) unreachablePizza,
    required TResult Function(_Only2Times value) only2Lines,
    required TResult Function(_SlowMo value) slowMo,
    required TResult Function(_WinLabel value) winLabel,
  }) {
    return punchWave(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TrashWall value)? trashWall,
    TResult? Function(_GuardedPizza value)? guardedPizza,
    TResult? Function(_CursedPath value)? cursedPath,
    TResult? Function(_PunchWave value)? punchWave,
    TResult? Function(_BigBuddyBin value)? bigBuddyBin,
    TResult? Function(_UnreachablePizza value)? unreachablePizza,
    TResult? Function(_Only2Times value)? only2Lines,
    TResult? Function(_SlowMo value)? slowMo,
    TResult? Function(_WinLabel value)? winLabel,
  }) {
    return punchWave?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TrashWall value)? trashWall,
    TResult Function(_GuardedPizza value)? guardedPizza,
    TResult Function(_CursedPath value)? cursedPath,
    TResult Function(_PunchWave value)? punchWave,
    TResult Function(_BigBuddyBin value)? bigBuddyBin,
    TResult Function(_UnreachablePizza value)? unreachablePizza,
    TResult Function(_Only2Times value)? only2Lines,
    TResult Function(_SlowMo value)? slowMo,
    TResult Function(_WinLabel value)? winLabel,
    required TResult orElse(),
  }) {
    if (punchWave != null) {
      return punchWave(this);
    }
    return orElse();
  }
}

abstract class _PunchWave implements FigureEvent {
  const factory _PunchWave({required final Items punchItem}) = _$PunchWaveImpl;

  Items get punchItem;
  @JsonKey(ignore: true)
  _$$PunchWaveImplCopyWith<_$PunchWaveImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$BigBuddyBinImplCopyWith<$Res> {
  factory _$$BigBuddyBinImplCopyWith(
          _$BigBuddyBinImpl value, $Res Function(_$BigBuddyBinImpl) then) =
      __$$BigBuddyBinImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$BigBuddyBinImplCopyWithImpl<$Res>
    extends _$FigureEventCopyWithImpl<$Res, _$BigBuddyBinImpl>
    implements _$$BigBuddyBinImplCopyWith<$Res> {
  __$$BigBuddyBinImplCopyWithImpl(
      _$BigBuddyBinImpl _value, $Res Function(_$BigBuddyBinImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$BigBuddyBinImpl implements _BigBuddyBin {
  const _$BigBuddyBinImpl();

  @override
  String toString() {
    return 'FigureEvent.bigBuddyBin()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$BigBuddyBinImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() trashWall,
    required TResult Function(Items guard) guardedPizza,
    required TResult Function(Items guard) cursedPath,
    required TResult Function(Items punchItem) punchWave,
    required TResult Function() bigBuddyBin,
    required TResult Function() unreachablePizza,
    required TResult Function(Items guard) only2Lines,
    required TResult Function(Items slowMoItem) slowMo,
    required TResult Function(Items item) winLabel,
  }) {
    return bigBuddyBin();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? trashWall,
    TResult? Function(Items guard)? guardedPizza,
    TResult? Function(Items guard)? cursedPath,
    TResult? Function(Items punchItem)? punchWave,
    TResult? Function()? bigBuddyBin,
    TResult? Function()? unreachablePizza,
    TResult? Function(Items guard)? only2Lines,
    TResult? Function(Items slowMoItem)? slowMo,
    TResult? Function(Items item)? winLabel,
  }) {
    return bigBuddyBin?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? trashWall,
    TResult Function(Items guard)? guardedPizza,
    TResult Function(Items guard)? cursedPath,
    TResult Function(Items punchItem)? punchWave,
    TResult Function()? bigBuddyBin,
    TResult Function()? unreachablePizza,
    TResult Function(Items guard)? only2Lines,
    TResult Function(Items slowMoItem)? slowMo,
    TResult Function(Items item)? winLabel,
    required TResult orElse(),
  }) {
    if (bigBuddyBin != null) {
      return bigBuddyBin();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TrashWall value) trashWall,
    required TResult Function(_GuardedPizza value) guardedPizza,
    required TResult Function(_CursedPath value) cursedPath,
    required TResult Function(_PunchWave value) punchWave,
    required TResult Function(_BigBuddyBin value) bigBuddyBin,
    required TResult Function(_UnreachablePizza value) unreachablePizza,
    required TResult Function(_Only2Times value) only2Lines,
    required TResult Function(_SlowMo value) slowMo,
    required TResult Function(_WinLabel value) winLabel,
  }) {
    return bigBuddyBin(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TrashWall value)? trashWall,
    TResult? Function(_GuardedPizza value)? guardedPizza,
    TResult? Function(_CursedPath value)? cursedPath,
    TResult? Function(_PunchWave value)? punchWave,
    TResult? Function(_BigBuddyBin value)? bigBuddyBin,
    TResult? Function(_UnreachablePizza value)? unreachablePizza,
    TResult? Function(_Only2Times value)? only2Lines,
    TResult? Function(_SlowMo value)? slowMo,
    TResult? Function(_WinLabel value)? winLabel,
  }) {
    return bigBuddyBin?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TrashWall value)? trashWall,
    TResult Function(_GuardedPizza value)? guardedPizza,
    TResult Function(_CursedPath value)? cursedPath,
    TResult Function(_PunchWave value)? punchWave,
    TResult Function(_BigBuddyBin value)? bigBuddyBin,
    TResult Function(_UnreachablePizza value)? unreachablePizza,
    TResult Function(_Only2Times value)? only2Lines,
    TResult Function(_SlowMo value)? slowMo,
    TResult Function(_WinLabel value)? winLabel,
    required TResult orElse(),
  }) {
    if (bigBuddyBin != null) {
      return bigBuddyBin(this);
    }
    return orElse();
  }
}

abstract class _BigBuddyBin implements FigureEvent {
  const factory _BigBuddyBin() = _$BigBuddyBinImpl;
}

/// @nodoc
abstract class _$$UnreachablePizzaImplCopyWith<$Res> {
  factory _$$UnreachablePizzaImplCopyWith(_$UnreachablePizzaImpl value,
          $Res Function(_$UnreachablePizzaImpl) then) =
      __$$UnreachablePizzaImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$UnreachablePizzaImplCopyWithImpl<$Res>
    extends _$FigureEventCopyWithImpl<$Res, _$UnreachablePizzaImpl>
    implements _$$UnreachablePizzaImplCopyWith<$Res> {
  __$$UnreachablePizzaImplCopyWithImpl(_$UnreachablePizzaImpl _value,
      $Res Function(_$UnreachablePizzaImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$UnreachablePizzaImpl implements _UnreachablePizza {
  const _$UnreachablePizzaImpl();

  @override
  String toString() {
    return 'FigureEvent.unreachablePizza()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$UnreachablePizzaImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() trashWall,
    required TResult Function(Items guard) guardedPizza,
    required TResult Function(Items guard) cursedPath,
    required TResult Function(Items punchItem) punchWave,
    required TResult Function() bigBuddyBin,
    required TResult Function() unreachablePizza,
    required TResult Function(Items guard) only2Lines,
    required TResult Function(Items slowMoItem) slowMo,
    required TResult Function(Items item) winLabel,
  }) {
    return unreachablePizza();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? trashWall,
    TResult? Function(Items guard)? guardedPizza,
    TResult? Function(Items guard)? cursedPath,
    TResult? Function(Items punchItem)? punchWave,
    TResult? Function()? bigBuddyBin,
    TResult? Function()? unreachablePizza,
    TResult? Function(Items guard)? only2Lines,
    TResult? Function(Items slowMoItem)? slowMo,
    TResult? Function(Items item)? winLabel,
  }) {
    return unreachablePizza?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? trashWall,
    TResult Function(Items guard)? guardedPizza,
    TResult Function(Items guard)? cursedPath,
    TResult Function(Items punchItem)? punchWave,
    TResult Function()? bigBuddyBin,
    TResult Function()? unreachablePizza,
    TResult Function(Items guard)? only2Lines,
    TResult Function(Items slowMoItem)? slowMo,
    TResult Function(Items item)? winLabel,
    required TResult orElse(),
  }) {
    if (unreachablePizza != null) {
      return unreachablePizza();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TrashWall value) trashWall,
    required TResult Function(_GuardedPizza value) guardedPizza,
    required TResult Function(_CursedPath value) cursedPath,
    required TResult Function(_PunchWave value) punchWave,
    required TResult Function(_BigBuddyBin value) bigBuddyBin,
    required TResult Function(_UnreachablePizza value) unreachablePizza,
    required TResult Function(_Only2Times value) only2Lines,
    required TResult Function(_SlowMo value) slowMo,
    required TResult Function(_WinLabel value) winLabel,
  }) {
    return unreachablePizza(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TrashWall value)? trashWall,
    TResult? Function(_GuardedPizza value)? guardedPizza,
    TResult? Function(_CursedPath value)? cursedPath,
    TResult? Function(_PunchWave value)? punchWave,
    TResult? Function(_BigBuddyBin value)? bigBuddyBin,
    TResult? Function(_UnreachablePizza value)? unreachablePizza,
    TResult? Function(_Only2Times value)? only2Lines,
    TResult? Function(_SlowMo value)? slowMo,
    TResult? Function(_WinLabel value)? winLabel,
  }) {
    return unreachablePizza?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TrashWall value)? trashWall,
    TResult Function(_GuardedPizza value)? guardedPizza,
    TResult Function(_CursedPath value)? cursedPath,
    TResult Function(_PunchWave value)? punchWave,
    TResult Function(_BigBuddyBin value)? bigBuddyBin,
    TResult Function(_UnreachablePizza value)? unreachablePizza,
    TResult Function(_Only2Times value)? only2Lines,
    TResult Function(_SlowMo value)? slowMo,
    TResult Function(_WinLabel value)? winLabel,
    required TResult orElse(),
  }) {
    if (unreachablePizza != null) {
      return unreachablePizza(this);
    }
    return orElse();
  }
}

abstract class _UnreachablePizza implements FigureEvent {
  const factory _UnreachablePizza() = _$UnreachablePizzaImpl;
}

/// @nodoc
abstract class _$$Only2TimesImplCopyWith<$Res> {
  factory _$$Only2TimesImplCopyWith(
          _$Only2TimesImpl value, $Res Function(_$Only2TimesImpl) then) =
      __$$Only2TimesImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Items guard});
}

/// @nodoc
class __$$Only2TimesImplCopyWithImpl<$Res>
    extends _$FigureEventCopyWithImpl<$Res, _$Only2TimesImpl>
    implements _$$Only2TimesImplCopyWith<$Res> {
  __$$Only2TimesImplCopyWithImpl(
      _$Only2TimesImpl _value, $Res Function(_$Only2TimesImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? guard = null,
  }) {
    return _then(_$Only2TimesImpl(
      guard: null == guard
          ? _value.guard
          : guard // ignore: cast_nullable_to_non_nullable
              as Items,
    ));
  }
}

/// @nodoc

class _$Only2TimesImpl implements _Only2Times {
  const _$Only2TimesImpl({required this.guard});

  @override
  final Items guard;

  @override
  String toString() {
    return 'FigureEvent.only2Lines(guard: $guard)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Only2TimesImpl &&
            (identical(other.guard, guard) || other.guard == guard));
  }

  @override
  int get hashCode => Object.hash(runtimeType, guard);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$Only2TimesImplCopyWith<_$Only2TimesImpl> get copyWith =>
      __$$Only2TimesImplCopyWithImpl<_$Only2TimesImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() trashWall,
    required TResult Function(Items guard) guardedPizza,
    required TResult Function(Items guard) cursedPath,
    required TResult Function(Items punchItem) punchWave,
    required TResult Function() bigBuddyBin,
    required TResult Function() unreachablePizza,
    required TResult Function(Items guard) only2Lines,
    required TResult Function(Items slowMoItem) slowMo,
    required TResult Function(Items item) winLabel,
  }) {
    return only2Lines(guard);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? trashWall,
    TResult? Function(Items guard)? guardedPizza,
    TResult? Function(Items guard)? cursedPath,
    TResult? Function(Items punchItem)? punchWave,
    TResult? Function()? bigBuddyBin,
    TResult? Function()? unreachablePizza,
    TResult? Function(Items guard)? only2Lines,
    TResult? Function(Items slowMoItem)? slowMo,
    TResult? Function(Items item)? winLabel,
  }) {
    return only2Lines?.call(guard);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? trashWall,
    TResult Function(Items guard)? guardedPizza,
    TResult Function(Items guard)? cursedPath,
    TResult Function(Items punchItem)? punchWave,
    TResult Function()? bigBuddyBin,
    TResult Function()? unreachablePizza,
    TResult Function(Items guard)? only2Lines,
    TResult Function(Items slowMoItem)? slowMo,
    TResult Function(Items item)? winLabel,
    required TResult orElse(),
  }) {
    if (only2Lines != null) {
      return only2Lines(guard);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TrashWall value) trashWall,
    required TResult Function(_GuardedPizza value) guardedPizza,
    required TResult Function(_CursedPath value) cursedPath,
    required TResult Function(_PunchWave value) punchWave,
    required TResult Function(_BigBuddyBin value) bigBuddyBin,
    required TResult Function(_UnreachablePizza value) unreachablePizza,
    required TResult Function(_Only2Times value) only2Lines,
    required TResult Function(_SlowMo value) slowMo,
    required TResult Function(_WinLabel value) winLabel,
  }) {
    return only2Lines(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TrashWall value)? trashWall,
    TResult? Function(_GuardedPizza value)? guardedPizza,
    TResult? Function(_CursedPath value)? cursedPath,
    TResult? Function(_PunchWave value)? punchWave,
    TResult? Function(_BigBuddyBin value)? bigBuddyBin,
    TResult? Function(_UnreachablePizza value)? unreachablePizza,
    TResult? Function(_Only2Times value)? only2Lines,
    TResult? Function(_SlowMo value)? slowMo,
    TResult? Function(_WinLabel value)? winLabel,
  }) {
    return only2Lines?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TrashWall value)? trashWall,
    TResult Function(_GuardedPizza value)? guardedPizza,
    TResult Function(_CursedPath value)? cursedPath,
    TResult Function(_PunchWave value)? punchWave,
    TResult Function(_BigBuddyBin value)? bigBuddyBin,
    TResult Function(_UnreachablePizza value)? unreachablePizza,
    TResult Function(_Only2Times value)? only2Lines,
    TResult Function(_SlowMo value)? slowMo,
    TResult Function(_WinLabel value)? winLabel,
    required TResult orElse(),
  }) {
    if (only2Lines != null) {
      return only2Lines(this);
    }
    return orElse();
  }
}

abstract class _Only2Times implements FigureEvent {
  const factory _Only2Times({required final Items guard}) = _$Only2TimesImpl;

  Items get guard;
  @JsonKey(ignore: true)
  _$$Only2TimesImplCopyWith<_$Only2TimesImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SlowMoImplCopyWith<$Res> {
  factory _$$SlowMoImplCopyWith(
          _$SlowMoImpl value, $Res Function(_$SlowMoImpl) then) =
      __$$SlowMoImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Items slowMoItem});
}

/// @nodoc
class __$$SlowMoImplCopyWithImpl<$Res>
    extends _$FigureEventCopyWithImpl<$Res, _$SlowMoImpl>
    implements _$$SlowMoImplCopyWith<$Res> {
  __$$SlowMoImplCopyWithImpl(
      _$SlowMoImpl _value, $Res Function(_$SlowMoImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? slowMoItem = null,
  }) {
    return _then(_$SlowMoImpl(
      slowMoItem: null == slowMoItem
          ? _value.slowMoItem
          : slowMoItem // ignore: cast_nullable_to_non_nullable
              as Items,
    ));
  }
}

/// @nodoc

class _$SlowMoImpl implements _SlowMo {
  const _$SlowMoImpl({required this.slowMoItem});

  @override
  final Items slowMoItem;

  @override
  String toString() {
    return 'FigureEvent.slowMo(slowMoItem: $slowMoItem)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SlowMoImpl &&
            (identical(other.slowMoItem, slowMoItem) ||
                other.slowMoItem == slowMoItem));
  }

  @override
  int get hashCode => Object.hash(runtimeType, slowMoItem);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SlowMoImplCopyWith<_$SlowMoImpl> get copyWith =>
      __$$SlowMoImplCopyWithImpl<_$SlowMoImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() trashWall,
    required TResult Function(Items guard) guardedPizza,
    required TResult Function(Items guard) cursedPath,
    required TResult Function(Items punchItem) punchWave,
    required TResult Function() bigBuddyBin,
    required TResult Function() unreachablePizza,
    required TResult Function(Items guard) only2Lines,
    required TResult Function(Items slowMoItem) slowMo,
    required TResult Function(Items item) winLabel,
  }) {
    return slowMo(slowMoItem);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? trashWall,
    TResult? Function(Items guard)? guardedPizza,
    TResult? Function(Items guard)? cursedPath,
    TResult? Function(Items punchItem)? punchWave,
    TResult? Function()? bigBuddyBin,
    TResult? Function()? unreachablePizza,
    TResult? Function(Items guard)? only2Lines,
    TResult? Function(Items slowMoItem)? slowMo,
    TResult? Function(Items item)? winLabel,
  }) {
    return slowMo?.call(slowMoItem);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? trashWall,
    TResult Function(Items guard)? guardedPizza,
    TResult Function(Items guard)? cursedPath,
    TResult Function(Items punchItem)? punchWave,
    TResult Function()? bigBuddyBin,
    TResult Function()? unreachablePizza,
    TResult Function(Items guard)? only2Lines,
    TResult Function(Items slowMoItem)? slowMo,
    TResult Function(Items item)? winLabel,
    required TResult orElse(),
  }) {
    if (slowMo != null) {
      return slowMo(slowMoItem);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TrashWall value) trashWall,
    required TResult Function(_GuardedPizza value) guardedPizza,
    required TResult Function(_CursedPath value) cursedPath,
    required TResult Function(_PunchWave value) punchWave,
    required TResult Function(_BigBuddyBin value) bigBuddyBin,
    required TResult Function(_UnreachablePizza value) unreachablePizza,
    required TResult Function(_Only2Times value) only2Lines,
    required TResult Function(_SlowMo value) slowMo,
    required TResult Function(_WinLabel value) winLabel,
  }) {
    return slowMo(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TrashWall value)? trashWall,
    TResult? Function(_GuardedPizza value)? guardedPizza,
    TResult? Function(_CursedPath value)? cursedPath,
    TResult? Function(_PunchWave value)? punchWave,
    TResult? Function(_BigBuddyBin value)? bigBuddyBin,
    TResult? Function(_UnreachablePizza value)? unreachablePizza,
    TResult? Function(_Only2Times value)? only2Lines,
    TResult? Function(_SlowMo value)? slowMo,
    TResult? Function(_WinLabel value)? winLabel,
  }) {
    return slowMo?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TrashWall value)? trashWall,
    TResult Function(_GuardedPizza value)? guardedPizza,
    TResult Function(_CursedPath value)? cursedPath,
    TResult Function(_PunchWave value)? punchWave,
    TResult Function(_BigBuddyBin value)? bigBuddyBin,
    TResult Function(_UnreachablePizza value)? unreachablePizza,
    TResult Function(_Only2Times value)? only2Lines,
    TResult Function(_SlowMo value)? slowMo,
    TResult Function(_WinLabel value)? winLabel,
    required TResult orElse(),
  }) {
    if (slowMo != null) {
      return slowMo(this);
    }
    return orElse();
  }
}

abstract class _SlowMo implements FigureEvent {
  const factory _SlowMo({required final Items slowMoItem}) = _$SlowMoImpl;

  Items get slowMoItem;
  @JsonKey(ignore: true)
  _$$SlowMoImplCopyWith<_$SlowMoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$WinLabelImplCopyWith<$Res> {
  factory _$$WinLabelImplCopyWith(
          _$WinLabelImpl value, $Res Function(_$WinLabelImpl) then) =
      __$$WinLabelImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Items item});
}

/// @nodoc
class __$$WinLabelImplCopyWithImpl<$Res>
    extends _$FigureEventCopyWithImpl<$Res, _$WinLabelImpl>
    implements _$$WinLabelImplCopyWith<$Res> {
  __$$WinLabelImplCopyWithImpl(
      _$WinLabelImpl _value, $Res Function(_$WinLabelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? item = null,
  }) {
    return _then(_$WinLabelImpl(
      item: null == item
          ? _value.item
          : item // ignore: cast_nullable_to_non_nullable
              as Items,
    ));
  }
}

/// @nodoc

class _$WinLabelImpl implements _WinLabel {
  const _$WinLabelImpl({required this.item});

  @override
  final Items item;

  @override
  String toString() {
    return 'FigureEvent.winLabel(item: $item)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WinLabelImpl &&
            (identical(other.item, item) || other.item == item));
  }

  @override
  int get hashCode => Object.hash(runtimeType, item);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WinLabelImplCopyWith<_$WinLabelImpl> get copyWith =>
      __$$WinLabelImplCopyWithImpl<_$WinLabelImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() trashWall,
    required TResult Function(Items guard) guardedPizza,
    required TResult Function(Items guard) cursedPath,
    required TResult Function(Items punchItem) punchWave,
    required TResult Function() bigBuddyBin,
    required TResult Function() unreachablePizza,
    required TResult Function(Items guard) only2Lines,
    required TResult Function(Items slowMoItem) slowMo,
    required TResult Function(Items item) winLabel,
  }) {
    return winLabel(item);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? trashWall,
    TResult? Function(Items guard)? guardedPizza,
    TResult? Function(Items guard)? cursedPath,
    TResult? Function(Items punchItem)? punchWave,
    TResult? Function()? bigBuddyBin,
    TResult? Function()? unreachablePizza,
    TResult? Function(Items guard)? only2Lines,
    TResult? Function(Items slowMoItem)? slowMo,
    TResult? Function(Items item)? winLabel,
  }) {
    return winLabel?.call(item);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? trashWall,
    TResult Function(Items guard)? guardedPizza,
    TResult Function(Items guard)? cursedPath,
    TResult Function(Items punchItem)? punchWave,
    TResult Function()? bigBuddyBin,
    TResult Function()? unreachablePizza,
    TResult Function(Items guard)? only2Lines,
    TResult Function(Items slowMoItem)? slowMo,
    TResult Function(Items item)? winLabel,
    required TResult orElse(),
  }) {
    if (winLabel != null) {
      return winLabel(item);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TrashWall value) trashWall,
    required TResult Function(_GuardedPizza value) guardedPizza,
    required TResult Function(_CursedPath value) cursedPath,
    required TResult Function(_PunchWave value) punchWave,
    required TResult Function(_BigBuddyBin value) bigBuddyBin,
    required TResult Function(_UnreachablePizza value) unreachablePizza,
    required TResult Function(_Only2Times value) only2Lines,
    required TResult Function(_SlowMo value) slowMo,
    required TResult Function(_WinLabel value) winLabel,
  }) {
    return winLabel(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TrashWall value)? trashWall,
    TResult? Function(_GuardedPizza value)? guardedPizza,
    TResult? Function(_CursedPath value)? cursedPath,
    TResult? Function(_PunchWave value)? punchWave,
    TResult? Function(_BigBuddyBin value)? bigBuddyBin,
    TResult? Function(_UnreachablePizza value)? unreachablePizza,
    TResult? Function(_Only2Times value)? only2Lines,
    TResult? Function(_SlowMo value)? slowMo,
    TResult? Function(_WinLabel value)? winLabel,
  }) {
    return winLabel?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TrashWall value)? trashWall,
    TResult Function(_GuardedPizza value)? guardedPizza,
    TResult Function(_CursedPath value)? cursedPath,
    TResult Function(_PunchWave value)? punchWave,
    TResult Function(_BigBuddyBin value)? bigBuddyBin,
    TResult Function(_UnreachablePizza value)? unreachablePizza,
    TResult Function(_Only2Times value)? only2Lines,
    TResult Function(_SlowMo value)? slowMo,
    TResult Function(_WinLabel value)? winLabel,
    required TResult orElse(),
  }) {
    if (winLabel != null) {
      return winLabel(this);
    }
    return orElse();
  }
}

abstract class _WinLabel implements FigureEvent {
  const factory _WinLabel({required final Items item}) = _$WinLabelImpl;

  Items get item;
  @JsonKey(ignore: true)
  _$$WinLabelImplCopyWith<_$WinLabelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$LevelState {
  LinearLevel get level => throw _privateConstructorUsedError;
  FigureEvent? get figure => throw _privateConstructorUsedError;
  MiniGame? get miniGame => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $LevelStateCopyWith<LevelState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LevelStateCopyWith<$Res> {
  factory $LevelStateCopyWith(
          LevelState value, $Res Function(LevelState) then) =
      _$LevelStateCopyWithImpl<$Res, LevelState>;
  @useResult
  $Res call({LinearLevel level, FigureEvent? figure, MiniGame? miniGame});

  $FigureEventCopyWith<$Res>? get figure;
  $MiniGameCopyWith<$Res>? get miniGame;
}

/// @nodoc
class _$LevelStateCopyWithImpl<$Res, $Val extends LevelState>
    implements $LevelStateCopyWith<$Res> {
  _$LevelStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? level = null,
    Object? figure = freezed,
    Object? miniGame = freezed,
  }) {
    return _then(_value.copyWith(
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as LinearLevel,
      figure: freezed == figure
          ? _value.figure
          : figure // ignore: cast_nullable_to_non_nullable
              as FigureEvent?,
      miniGame: freezed == miniGame
          ? _value.miniGame
          : miniGame // ignore: cast_nullable_to_non_nullable
              as MiniGame?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $FigureEventCopyWith<$Res>? get figure {
    if (_value.figure == null) {
      return null;
    }

    return $FigureEventCopyWith<$Res>(_value.figure!, (value) {
      return _then(_value.copyWith(figure: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $MiniGameCopyWith<$Res>? get miniGame {
    if (_value.miniGame == null) {
      return null;
    }

    return $MiniGameCopyWith<$Res>(_value.miniGame!, (value) {
      return _then(_value.copyWith(miniGame: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$LevelStateImplCopyWith<$Res>
    implements $LevelStateCopyWith<$Res> {
  factory _$$LevelStateImplCopyWith(
          _$LevelStateImpl value, $Res Function(_$LevelStateImpl) then) =
      __$$LevelStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({LinearLevel level, FigureEvent? figure, MiniGame? miniGame});

  @override
  $FigureEventCopyWith<$Res>? get figure;
  @override
  $MiniGameCopyWith<$Res>? get miniGame;
}

/// @nodoc
class __$$LevelStateImplCopyWithImpl<$Res>
    extends _$LevelStateCopyWithImpl<$Res, _$LevelStateImpl>
    implements _$$LevelStateImplCopyWith<$Res> {
  __$$LevelStateImplCopyWithImpl(
      _$LevelStateImpl _value, $Res Function(_$LevelStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? level = null,
    Object? figure = freezed,
    Object? miniGame = freezed,
  }) {
    return _then(_$LevelStateImpl(
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as LinearLevel,
      figure: freezed == figure
          ? _value.figure
          : figure // ignore: cast_nullable_to_non_nullable
              as FigureEvent?,
      miniGame: freezed == miniGame
          ? _value.miniGame
          : miniGame // ignore: cast_nullable_to_non_nullable
              as MiniGame?,
    ));
  }
}

/// @nodoc

class _$LevelStateImpl implements _LevelState {
  const _$LevelStateImpl({required this.level, this.figure, this.miniGame});

  @override
  final LinearLevel level;
  @override
  final FigureEvent? figure;
  @override
  final MiniGame? miniGame;

  @override
  String toString() {
    return 'LevelState(level: $level, figure: $figure, miniGame: $miniGame)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LevelStateImpl &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.figure, figure) || other.figure == figure) &&
            (identical(other.miniGame, miniGame) ||
                other.miniGame == miniGame));
  }

  @override
  int get hashCode => Object.hash(runtimeType, level, figure, miniGame);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$LevelStateImplCopyWith<_$LevelStateImpl> get copyWith =>
      __$$LevelStateImplCopyWithImpl<_$LevelStateImpl>(this, _$identity);
}

abstract class _LevelState implements LevelState {
  const factory _LevelState(
      {required final LinearLevel level,
      final FigureEvent? figure,
      final MiniGame? miniGame}) = _$LevelStateImpl;

  @override
  LinearLevel get level;
  @override
  FigureEvent? get figure;
  @override
  MiniGame? get miniGame;
  @override
  @JsonKey(ignore: true)
  _$$LevelStateImplCopyWith<_$LevelStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
