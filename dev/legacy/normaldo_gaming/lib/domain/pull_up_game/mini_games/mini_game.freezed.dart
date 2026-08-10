// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mini_game.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$MiniGame {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() shredder,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? shredder,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? shredder,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Shredder value) shredder,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Shredder value)? shredder,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Shredder value)? shredder,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MiniGameCopyWith<$Res> {
  factory $MiniGameCopyWith(MiniGame value, $Res Function(MiniGame) then) =
      _$MiniGameCopyWithImpl<$Res, MiniGame>;
}

/// @nodoc
class _$MiniGameCopyWithImpl<$Res, $Val extends MiniGame>
    implements $MiniGameCopyWith<$Res> {
  _$MiniGameCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$ShredderImplCopyWith<$Res> {
  factory _$$ShredderImplCopyWith(
          _$ShredderImpl value, $Res Function(_$ShredderImpl) then) =
      __$$ShredderImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ShredderImplCopyWithImpl<$Res>
    extends _$MiniGameCopyWithImpl<$Res, _$ShredderImpl>
    implements _$$ShredderImplCopyWith<$Res> {
  __$$ShredderImplCopyWithImpl(
      _$ShredderImpl _value, $Res Function(_$ShredderImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$ShredderImpl implements _Shredder {
  const _$ShredderImpl();

  @override
  String toString() {
    return 'MiniGame.shredder()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$ShredderImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() shredder,
  }) {
    return shredder();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? shredder,
  }) {
    return shredder?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? shredder,
    required TResult orElse(),
  }) {
    if (shredder != null) {
      return shredder();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Shredder value) shredder,
  }) {
    return shredder(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Shredder value)? shredder,
  }) {
    return shredder?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Shredder value)? shredder,
    required TResult orElse(),
  }) {
    if (shredder != null) {
      return shredder(this);
    }
    return orElse();
  }
}

abstract class _Shredder implements MiniGame {
  const factory _Shredder() = _$ShredderImpl;
}
