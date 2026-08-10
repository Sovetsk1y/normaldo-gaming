// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_reward_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$DailyRewardState {
  Duration get delay => throw _privateConstructorUsedError;
  int get currentDay => throw _privateConstructorUsedError;
  DateTime? get lastApply => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DailyRewardStateCopyWith<DailyRewardState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyRewardStateCopyWith<$Res> {
  factory $DailyRewardStateCopyWith(
          DailyRewardState value, $Res Function(DailyRewardState) then) =
      _$DailyRewardStateCopyWithImpl<$Res, DailyRewardState>;
  @useResult
  $Res call({Duration delay, int currentDay, DateTime? lastApply});
}

/// @nodoc
class _$DailyRewardStateCopyWithImpl<$Res, $Val extends DailyRewardState>
    implements $DailyRewardStateCopyWith<$Res> {
  _$DailyRewardStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? delay = null,
    Object? currentDay = null,
    Object? lastApply = freezed,
  }) {
    return _then(_value.copyWith(
      delay: null == delay
          ? _value.delay
          : delay // ignore: cast_nullable_to_non_nullable
              as Duration,
      currentDay: null == currentDay
          ? _value.currentDay
          : currentDay // ignore: cast_nullable_to_non_nullable
              as int,
      lastApply: freezed == lastApply
          ? _value.lastApply
          : lastApply // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DailyRewardStateImplCopyWith<$Res>
    implements $DailyRewardStateCopyWith<$Res> {
  factory _$$DailyRewardStateImplCopyWith(_$DailyRewardStateImpl value,
          $Res Function(_$DailyRewardStateImpl) then) =
      __$$DailyRewardStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Duration delay, int currentDay, DateTime? lastApply});
}

/// @nodoc
class __$$DailyRewardStateImplCopyWithImpl<$Res>
    extends _$DailyRewardStateCopyWithImpl<$Res, _$DailyRewardStateImpl>
    implements _$$DailyRewardStateImplCopyWith<$Res> {
  __$$DailyRewardStateImplCopyWithImpl(_$DailyRewardStateImpl _value,
      $Res Function(_$DailyRewardStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? delay = null,
    Object? currentDay = null,
    Object? lastApply = freezed,
  }) {
    return _then(_$DailyRewardStateImpl(
      delay: null == delay
          ? _value.delay
          : delay // ignore: cast_nullable_to_non_nullable
              as Duration,
      currentDay: null == currentDay
          ? _value.currentDay
          : currentDay // ignore: cast_nullable_to_non_nullable
              as int,
      lastApply: freezed == lastApply
          ? _value.lastApply
          : lastApply // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$DailyRewardStateImpl extends _DailyRewardState {
  const _$DailyRewardStateImpl(
      {required this.delay, required this.currentDay, this.lastApply})
      : super._();

  @override
  final Duration delay;
  @override
  final int currentDay;
  @override
  final DateTime? lastApply;

  @override
  String toString() {
    return 'DailyRewardState(delay: $delay, currentDay: $currentDay, lastApply: $lastApply)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyRewardStateImpl &&
            (identical(other.delay, delay) || other.delay == delay) &&
            (identical(other.currentDay, currentDay) ||
                other.currentDay == currentDay) &&
            (identical(other.lastApply, lastApply) ||
                other.lastApply == lastApply));
  }

  @override
  int get hashCode => Object.hash(runtimeType, delay, currentDay, lastApply);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyRewardStateImplCopyWith<_$DailyRewardStateImpl> get copyWith =>
      __$$DailyRewardStateImplCopyWithImpl<_$DailyRewardStateImpl>(
          this, _$identity);
}

abstract class _DailyRewardState extends DailyRewardState {
  const factory _DailyRewardState(
      {required final Duration delay,
      required final int currentDay,
      final DateTime? lastApply}) = _$DailyRewardStateImpl;
  const _DailyRewardState._() : super._();

  @override
  Duration get delay;
  @override
  int get currentDay;
  @override
  DateTime? get lastApply;
  @override
  @JsonKey(ignore: true)
  _$$DailyRewardStateImplCopyWith<_$DailyRewardStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
