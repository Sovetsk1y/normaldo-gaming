// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$UserState {
  User get user => throw _privateConstructorUsedError;
  bool get educated => throw _privateConstructorUsedError;

  /// passed intro + intro game
  bool get introduced => throw _privateConstructorUsedError;
  Skin get skin => throw _privateConstructorUsedError;
  List<String> get activatedPromoCodes => throw _privateConstructorUsedError;
  NetworkException? get failure => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $UserStateCopyWith<UserState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserStateCopyWith<$Res> {
  factory $UserStateCopyWith(UserState value, $Res Function(UserState) then) =
      _$UserStateCopyWithImpl<$Res, UserState>;
  @useResult
  $Res call(
      {User user,
      bool educated,
      bool introduced,
      Skin skin,
      List<String> activatedPromoCodes,
      NetworkException? failure});
}

/// @nodoc
class _$UserStateCopyWithImpl<$Res, $Val extends UserState>
    implements $UserStateCopyWith<$Res> {
  _$UserStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? user = null,
    Object? educated = null,
    Object? introduced = null,
    Object? skin = null,
    Object? activatedPromoCodes = null,
    Object? failure = freezed,
  }) {
    return _then(_value.copyWith(
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as User,
      educated: null == educated
          ? _value.educated
          : educated // ignore: cast_nullable_to_non_nullable
              as bool,
      introduced: null == introduced
          ? _value.introduced
          : introduced // ignore: cast_nullable_to_non_nullable
              as bool,
      skin: null == skin
          ? _value.skin
          : skin // ignore: cast_nullable_to_non_nullable
              as Skin,
      activatedPromoCodes: null == activatedPromoCodes
          ? _value.activatedPromoCodes
          : activatedPromoCodes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      failure: freezed == failure
          ? _value.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as NetworkException?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserStateImplCopyWith<$Res>
    implements $UserStateCopyWith<$Res> {
  factory _$$UserStateImplCopyWith(
          _$UserStateImpl value, $Res Function(_$UserStateImpl) then) =
      __$$UserStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {User user,
      bool educated,
      bool introduced,
      Skin skin,
      List<String> activatedPromoCodes,
      NetworkException? failure});
}

/// @nodoc
class __$$UserStateImplCopyWithImpl<$Res>
    extends _$UserStateCopyWithImpl<$Res, _$UserStateImpl>
    implements _$$UserStateImplCopyWith<$Res> {
  __$$UserStateImplCopyWithImpl(
      _$UserStateImpl _value, $Res Function(_$UserStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? user = null,
    Object? educated = null,
    Object? introduced = null,
    Object? skin = null,
    Object? activatedPromoCodes = null,
    Object? failure = freezed,
  }) {
    return _then(_$UserStateImpl(
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as User,
      educated: null == educated
          ? _value.educated
          : educated // ignore: cast_nullable_to_non_nullable
              as bool,
      introduced: null == introduced
          ? _value.introduced
          : introduced // ignore: cast_nullable_to_non_nullable
              as bool,
      skin: null == skin
          ? _value.skin
          : skin // ignore: cast_nullable_to_non_nullable
              as Skin,
      activatedPromoCodes: null == activatedPromoCodes
          ? _value._activatedPromoCodes
          : activatedPromoCodes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      failure: freezed == failure
          ? _value.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as NetworkException?,
    ));
  }
}

/// @nodoc

class _$UserStateImpl implements _UserState {
  const _$UserStateImpl(
      {required this.user,
      required this.educated,
      required this.introduced,
      required this.skin,
      required final List<String> activatedPromoCodes,
      this.failure})
      : _activatedPromoCodes = activatedPromoCodes;

  @override
  final User user;
  @override
  final bool educated;

  /// passed intro + intro game
  @override
  final bool introduced;
  @override
  final Skin skin;
  final List<String> _activatedPromoCodes;
  @override
  List<String> get activatedPromoCodes {
    if (_activatedPromoCodes is EqualUnmodifiableListView)
      return _activatedPromoCodes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activatedPromoCodes);
  }

  @override
  final NetworkException? failure;

  @override
  String toString() {
    return 'UserState(user: $user, educated: $educated, introduced: $introduced, skin: $skin, activatedPromoCodes: $activatedPromoCodes, failure: $failure)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserStateImpl &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.educated, educated) ||
                other.educated == educated) &&
            (identical(other.introduced, introduced) ||
                other.introduced == introduced) &&
            (identical(other.skin, skin) || other.skin == skin) &&
            const DeepCollectionEquality()
                .equals(other._activatedPromoCodes, _activatedPromoCodes) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, user, educated, introduced, skin,
      const DeepCollectionEquality().hash(_activatedPromoCodes), failure);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserStateImplCopyWith<_$UserStateImpl> get copyWith =>
      __$$UserStateImplCopyWithImpl<_$UserStateImpl>(this, _$identity);
}

abstract class _UserState implements UserState {
  const factory _UserState(
      {required final User user,
      required final bool educated,
      required final bool introduced,
      required final Skin skin,
      required final List<String> activatedPromoCodes,
      final NetworkException? failure}) = _$UserStateImpl;

  @override
  User get user;
  @override
  bool get educated;
  @override

  /// passed intro + intro game
  bool get introduced;
  @override
  Skin get skin;
  @override
  List<String> get activatedPromoCodes;
  @override
  NetworkException? get failure;
  @override
  @JsonKey(ignore: true)
  _$$UserStateImplCopyWith<_$UserStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
