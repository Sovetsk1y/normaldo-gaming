// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mission_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$MissionState {
  Set<Mission> get missions => throw _privateConstructorUsedError;
  bool get completing => throw _privateConstructorUsedError;
  List<int> get newIndexes => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MissionStateCopyWith<MissionState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MissionStateCopyWith<$Res> {
  factory $MissionStateCopyWith(
          MissionState value, $Res Function(MissionState) then) =
      _$MissionStateCopyWithImpl<$Res, MissionState>;
  @useResult
  $Res call({Set<Mission> missions, bool completing, List<int> newIndexes});
}

/// @nodoc
class _$MissionStateCopyWithImpl<$Res, $Val extends MissionState>
    implements $MissionStateCopyWith<$Res> {
  _$MissionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? missions = null,
    Object? completing = null,
    Object? newIndexes = null,
  }) {
    return _then(_value.copyWith(
      missions: null == missions
          ? _value.missions
          : missions // ignore: cast_nullable_to_non_nullable
              as Set<Mission>,
      completing: null == completing
          ? _value.completing
          : completing // ignore: cast_nullable_to_non_nullable
              as bool,
      newIndexes: null == newIndexes
          ? _value.newIndexes
          : newIndexes // ignore: cast_nullable_to_non_nullable
              as List<int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MissionStateImplCopyWith<$Res>
    implements $MissionStateCopyWith<$Res> {
  factory _$$MissionStateImplCopyWith(
          _$MissionStateImpl value, $Res Function(_$MissionStateImpl) then) =
      __$$MissionStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Set<Mission> missions, bool completing, List<int> newIndexes});
}

/// @nodoc
class __$$MissionStateImplCopyWithImpl<$Res>
    extends _$MissionStateCopyWithImpl<$Res, _$MissionStateImpl>
    implements _$$MissionStateImplCopyWith<$Res> {
  __$$MissionStateImplCopyWithImpl(
      _$MissionStateImpl _value, $Res Function(_$MissionStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? missions = null,
    Object? completing = null,
    Object? newIndexes = null,
  }) {
    return _then(_$MissionStateImpl(
      missions: null == missions
          ? _value._missions
          : missions // ignore: cast_nullable_to_non_nullable
              as Set<Mission>,
      completing: null == completing
          ? _value.completing
          : completing // ignore: cast_nullable_to_non_nullable
              as bool,
      newIndexes: null == newIndexes
          ? _value._newIndexes
          : newIndexes // ignore: cast_nullable_to_non_nullable
              as List<int>,
    ));
  }
}

/// @nodoc

class _$MissionStateImpl extends _MissionState {
  const _$MissionStateImpl(
      {required final Set<Mission> missions,
      required this.completing,
      required final List<int> newIndexes})
      : _missions = missions,
        _newIndexes = newIndexes,
        super._();

  final Set<Mission> _missions;
  @override
  Set<Mission> get missions {
    if (_missions is EqualUnmodifiableSetView) return _missions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_missions);
  }

  @override
  final bool completing;
  final List<int> _newIndexes;
  @override
  List<int> get newIndexes {
    if (_newIndexes is EqualUnmodifiableListView) return _newIndexes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_newIndexes);
  }

  @override
  String toString() {
    return 'MissionState(missions: $missions, completing: $completing, newIndexes: $newIndexes)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MissionStateImpl &&
            const DeepCollectionEquality().equals(other._missions, _missions) &&
            (identical(other.completing, completing) ||
                other.completing == completing) &&
            const DeepCollectionEquality()
                .equals(other._newIndexes, _newIndexes));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_missions),
      completing,
      const DeepCollectionEquality().hash(_newIndexes));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MissionStateImplCopyWith<_$MissionStateImpl> get copyWith =>
      __$$MissionStateImplCopyWithImpl<_$MissionStateImpl>(this, _$identity);
}

abstract class _MissionState extends MissionState {
  const factory _MissionState(
      {required final Set<Mission> missions,
      required final bool completing,
      required final List<int> newIndexes}) = _$MissionStateImpl;
  const _MissionState._() : super._();

  @override
  Set<Mission> get missions;
  @override
  bool get completing;
  @override
  List<int> get newIndexes;
  @override
  @JsonKey(ignore: true)
  _$$MissionStateImplCopyWith<_$MissionStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
