// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'slot_machine_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$SlotMachineState {
  bool get spinning => throw _privateConstructorUsedError;
  int get bid => throw _privateConstructorUsedError;
  Rolls? get winRoll => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $SlotMachineStateCopyWith<SlotMachineState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SlotMachineStateCopyWith<$Res> {
  factory $SlotMachineStateCopyWith(
          SlotMachineState value, $Res Function(SlotMachineState) then) =
      _$SlotMachineStateCopyWithImpl<$Res, SlotMachineState>;
  @useResult
  $Res call({bool spinning, int bid, Rolls? winRoll});
}

/// @nodoc
class _$SlotMachineStateCopyWithImpl<$Res, $Val extends SlotMachineState>
    implements $SlotMachineStateCopyWith<$Res> {
  _$SlotMachineStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spinning = null,
    Object? bid = null,
    Object? winRoll = freezed,
  }) {
    return _then(_value.copyWith(
      spinning: null == spinning
          ? _value.spinning
          : spinning // ignore: cast_nullable_to_non_nullable
              as bool,
      bid: null == bid
          ? _value.bid
          : bid // ignore: cast_nullable_to_non_nullable
              as int,
      winRoll: freezed == winRoll
          ? _value.winRoll
          : winRoll // ignore: cast_nullable_to_non_nullable
              as Rolls?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SlotMachineStateImplCopyWith<$Res>
    implements $SlotMachineStateCopyWith<$Res> {
  factory _$$SlotMachineStateImplCopyWith(_$SlotMachineStateImpl value,
          $Res Function(_$SlotMachineStateImpl) then) =
      __$$SlotMachineStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool spinning, int bid, Rolls? winRoll});
}

/// @nodoc
class __$$SlotMachineStateImplCopyWithImpl<$Res>
    extends _$SlotMachineStateCopyWithImpl<$Res, _$SlotMachineStateImpl>
    implements _$$SlotMachineStateImplCopyWith<$Res> {
  __$$SlotMachineStateImplCopyWithImpl(_$SlotMachineStateImpl _value,
      $Res Function(_$SlotMachineStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spinning = null,
    Object? bid = null,
    Object? winRoll = freezed,
  }) {
    return _then(_$SlotMachineStateImpl(
      spinning: null == spinning
          ? _value.spinning
          : spinning // ignore: cast_nullable_to_non_nullable
              as bool,
      bid: null == bid
          ? _value.bid
          : bid // ignore: cast_nullable_to_non_nullable
              as int,
      winRoll: freezed == winRoll
          ? _value.winRoll
          : winRoll // ignore: cast_nullable_to_non_nullable
              as Rolls?,
    ));
  }
}

/// @nodoc

class _$SlotMachineStateImpl implements _SlotMachineState {
  const _$SlotMachineStateImpl(
      {required this.spinning, required this.bid, this.winRoll});

  @override
  final bool spinning;
  @override
  final int bid;
  @override
  final Rolls? winRoll;

  @override
  String toString() {
    return 'SlotMachineState(spinning: $spinning, bid: $bid, winRoll: $winRoll)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SlotMachineStateImpl &&
            (identical(other.spinning, spinning) ||
                other.spinning == spinning) &&
            (identical(other.bid, bid) || other.bid == bid) &&
            (identical(other.winRoll, winRoll) || other.winRoll == winRoll));
  }

  @override
  int get hashCode => Object.hash(runtimeType, spinning, bid, winRoll);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SlotMachineStateImplCopyWith<_$SlotMachineStateImpl> get copyWith =>
      __$$SlotMachineStateImplCopyWithImpl<_$SlotMachineStateImpl>(
          this, _$identity);
}

abstract class _SlotMachineState implements SlotMachineState {
  const factory _SlotMachineState(
      {required final bool spinning,
      required final int bid,
      final Rolls? winRoll}) = _$SlotMachineStateImpl;

  @override
  bool get spinning;
  @override
  int get bid;
  @override
  Rolls? get winRoll;
  @override
  @JsonKey(ignore: true)
  _$$SlotMachineStateImplCopyWith<_$SlotMachineStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
