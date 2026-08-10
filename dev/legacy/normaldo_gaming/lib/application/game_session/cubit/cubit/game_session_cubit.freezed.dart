// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_session_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$GameSessionState {
  int get score => throw _privateConstructorUsedError;
  bool get isDead => throw _privateConstructorUsedError;
  int get dollars => throw _privateConstructorUsedError;
  bool get paused => throw _privateConstructorUsedError;
  bool get hit => throw _privateConstructorUsedError;
  bool get revived => throw _privateConstructorUsedError;
  bool get revivedWithAd => throw _privateConstructorUsedError;
  int get level => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $GameSessionStateCopyWith<GameSessionState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameSessionStateCopyWith<$Res> {
  factory $GameSessionStateCopyWith(
          GameSessionState value, $Res Function(GameSessionState) then) =
      _$GameSessionStateCopyWithImpl<$Res, GameSessionState>;
  @useResult
  $Res call(
      {int score,
      bool isDead,
      int dollars,
      bool paused,
      bool hit,
      bool revived,
      bool revivedWithAd,
      int level});
}

/// @nodoc
class _$GameSessionStateCopyWithImpl<$Res, $Val extends GameSessionState>
    implements $GameSessionStateCopyWith<$Res> {
  _$GameSessionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? score = null,
    Object? isDead = null,
    Object? dollars = null,
    Object? paused = null,
    Object? hit = null,
    Object? revived = null,
    Object? revivedWithAd = null,
    Object? level = null,
  }) {
    return _then(_value.copyWith(
      score: null == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as int,
      isDead: null == isDead
          ? _value.isDead
          : isDead // ignore: cast_nullable_to_non_nullable
              as bool,
      dollars: null == dollars
          ? _value.dollars
          : dollars // ignore: cast_nullable_to_non_nullable
              as int,
      paused: null == paused
          ? _value.paused
          : paused // ignore: cast_nullable_to_non_nullable
              as bool,
      hit: null == hit
          ? _value.hit
          : hit // ignore: cast_nullable_to_non_nullable
              as bool,
      revived: null == revived
          ? _value.revived
          : revived // ignore: cast_nullable_to_non_nullable
              as bool,
      revivedWithAd: null == revivedWithAd
          ? _value.revivedWithAd
          : revivedWithAd // ignore: cast_nullable_to_non_nullable
              as bool,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GameSessionStateImplCopyWith<$Res>
    implements $GameSessionStateCopyWith<$Res> {
  factory _$$GameSessionStateImplCopyWith(_$GameSessionStateImpl value,
          $Res Function(_$GameSessionStateImpl) then) =
      __$$GameSessionStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int score,
      bool isDead,
      int dollars,
      bool paused,
      bool hit,
      bool revived,
      bool revivedWithAd,
      int level});
}

/// @nodoc
class __$$GameSessionStateImplCopyWithImpl<$Res>
    extends _$GameSessionStateCopyWithImpl<$Res, _$GameSessionStateImpl>
    implements _$$GameSessionStateImplCopyWith<$Res> {
  __$$GameSessionStateImplCopyWithImpl(_$GameSessionStateImpl _value,
      $Res Function(_$GameSessionStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? score = null,
    Object? isDead = null,
    Object? dollars = null,
    Object? paused = null,
    Object? hit = null,
    Object? revived = null,
    Object? revivedWithAd = null,
    Object? level = null,
  }) {
    return _then(_$GameSessionStateImpl(
      score: null == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as int,
      isDead: null == isDead
          ? _value.isDead
          : isDead // ignore: cast_nullable_to_non_nullable
              as bool,
      dollars: null == dollars
          ? _value.dollars
          : dollars // ignore: cast_nullable_to_non_nullable
              as int,
      paused: null == paused
          ? _value.paused
          : paused // ignore: cast_nullable_to_non_nullable
              as bool,
      hit: null == hit
          ? _value.hit
          : hit // ignore: cast_nullable_to_non_nullable
              as bool,
      revived: null == revived
          ? _value.revived
          : revived // ignore: cast_nullable_to_non_nullable
              as bool,
      revivedWithAd: null == revivedWithAd
          ? _value.revivedWithAd
          : revivedWithAd // ignore: cast_nullable_to_non_nullable
              as bool,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$GameSessionStateImpl implements _GameSessionState {
  const _$GameSessionStateImpl(
      {required this.score,
      required this.isDead,
      required this.dollars,
      required this.paused,
      required this.hit,
      required this.revived,
      required this.revivedWithAd,
      required this.level});

  @override
  final int score;
  @override
  final bool isDead;
  @override
  final int dollars;
  @override
  final bool paused;
  @override
  final bool hit;
  @override
  final bool revived;
  @override
  final bool revivedWithAd;
  @override
  final int level;

  @override
  String toString() {
    return 'GameSessionState(score: $score, isDead: $isDead, dollars: $dollars, paused: $paused, hit: $hit, revived: $revived, revivedWithAd: $revivedWithAd, level: $level)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameSessionStateImpl &&
            (identical(other.score, score) || other.score == score) &&
            (identical(other.isDead, isDead) || other.isDead == isDead) &&
            (identical(other.dollars, dollars) || other.dollars == dollars) &&
            (identical(other.paused, paused) || other.paused == paused) &&
            (identical(other.hit, hit) || other.hit == hit) &&
            (identical(other.revived, revived) || other.revived == revived) &&
            (identical(other.revivedWithAd, revivedWithAd) ||
                other.revivedWithAd == revivedWithAd) &&
            (identical(other.level, level) || other.level == level));
  }

  @override
  int get hashCode => Object.hash(runtimeType, score, isDead, dollars, paused,
      hit, revived, revivedWithAd, level);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GameSessionStateImplCopyWith<_$GameSessionStateImpl> get copyWith =>
      __$$GameSessionStateImplCopyWithImpl<_$GameSessionStateImpl>(
          this, _$identity);
}

abstract class _GameSessionState implements GameSessionState {
  const factory _GameSessionState(
      {required final int score,
      required final bool isDead,
      required final int dollars,
      required final bool paused,
      required final bool hit,
      required final bool revived,
      required final bool revivedWithAd,
      required final int level}) = _$GameSessionStateImpl;

  @override
  int get score;
  @override
  bool get isDead;
  @override
  int get dollars;
  @override
  bool get paused;
  @override
  bool get hit;
  @override
  bool get revived;
  @override
  bool get revivedWithAd;
  @override
  int get level;
  @override
  @JsonKey(ignore: true)
  _$$GameSessionStateImplCopyWith<_$GameSessionStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
