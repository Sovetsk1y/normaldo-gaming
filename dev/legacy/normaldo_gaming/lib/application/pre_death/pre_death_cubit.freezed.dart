// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pre_death_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$PreDeathState {
  bool get skipped => throw _privateConstructorUsedError;
  double get skipValue => throw _privateConstructorUsedError;
  AdState get adState => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PreDeathStateCopyWith<PreDeathState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PreDeathStateCopyWith<$Res> {
  factory $PreDeathStateCopyWith(
          PreDeathState value, $Res Function(PreDeathState) then) =
      _$PreDeathStateCopyWithImpl<$Res, PreDeathState>;
  @useResult
  $Res call({bool skipped, double skipValue, AdState adState});
}

/// @nodoc
class _$PreDeathStateCopyWithImpl<$Res, $Val extends PreDeathState>
    implements $PreDeathStateCopyWith<$Res> {
  _$PreDeathStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? skipped = null,
    Object? skipValue = null,
    Object? adState = null,
  }) {
    return _then(_value.copyWith(
      skipped: null == skipped
          ? _value.skipped
          : skipped // ignore: cast_nullable_to_non_nullable
              as bool,
      skipValue: null == skipValue
          ? _value.skipValue
          : skipValue // ignore: cast_nullable_to_non_nullable
              as double,
      adState: null == adState
          ? _value.adState
          : adState // ignore: cast_nullable_to_non_nullable
              as AdState,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PreDeathStateImplCopyWith<$Res>
    implements $PreDeathStateCopyWith<$Res> {
  factory _$$PreDeathStateImplCopyWith(
          _$PreDeathStateImpl value, $Res Function(_$PreDeathStateImpl) then) =
      __$$PreDeathStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool skipped, double skipValue, AdState adState});
}

/// @nodoc
class __$$PreDeathStateImplCopyWithImpl<$Res>
    extends _$PreDeathStateCopyWithImpl<$Res, _$PreDeathStateImpl>
    implements _$$PreDeathStateImplCopyWith<$Res> {
  __$$PreDeathStateImplCopyWithImpl(
      _$PreDeathStateImpl _value, $Res Function(_$PreDeathStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? skipped = null,
    Object? skipValue = null,
    Object? adState = null,
  }) {
    return _then(_$PreDeathStateImpl(
      skipped: null == skipped
          ? _value.skipped
          : skipped // ignore: cast_nullable_to_non_nullable
              as bool,
      skipValue: null == skipValue
          ? _value.skipValue
          : skipValue // ignore: cast_nullable_to_non_nullable
              as double,
      adState: null == adState
          ? _value.adState
          : adState // ignore: cast_nullable_to_non_nullable
              as AdState,
    ));
  }
}

/// @nodoc

class _$PreDeathStateImpl implements _PreDeathState {
  const _$PreDeathStateImpl(
      {required this.skipped, required this.skipValue, required this.adState});

  @override
  final bool skipped;
  @override
  final double skipValue;
  @override
  final AdState adState;

  @override
  String toString() {
    return 'PreDeathState(skipped: $skipped, skipValue: $skipValue, adState: $adState)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PreDeathStateImpl &&
            (identical(other.skipped, skipped) || other.skipped == skipped) &&
            (identical(other.skipValue, skipValue) ||
                other.skipValue == skipValue) &&
            (identical(other.adState, adState) || other.adState == adState));
  }

  @override
  int get hashCode => Object.hash(runtimeType, skipped, skipValue, adState);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PreDeathStateImplCopyWith<_$PreDeathStateImpl> get copyWith =>
      __$$PreDeathStateImplCopyWithImpl<_$PreDeathStateImpl>(this, _$identity);
}

abstract class _PreDeathState implements PreDeathState {
  const factory _PreDeathState(
      {required final bool skipped,
      required final double skipValue,
      required final AdState adState}) = _$PreDeathStateImpl;

  @override
  bool get skipped;
  @override
  double get skipValue;
  @override
  AdState get adState;
  @override
  @JsonKey(ignore: true)
  _$$PreDeathStateImplCopyWith<_$PreDeathStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
