// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ads_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$AdsState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(String errorMessage, void Function()? onComplete)
        failed,
    required TResult Function(
            String placementId, AdReward reward, void Function()? onComplete)
        readyToShow,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(String errorMessage, void Function()? onComplete)? failed,
    TResult? Function(
            String placementId, AdReward reward, void Function()? onComplete)?
        readyToShow,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(String errorMessage, void Function()? onComplete)? failed,
    TResult Function(
            String placementId, AdReward reward, void Function()? onComplete)?
        readyToShow,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Failed value) failed,
    required TResult Function(_ReadyToShow value) readyToShow,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Failed value)? failed,
    TResult? Function(_ReadyToShow value)? readyToShow,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Failed value)? failed,
    TResult Function(_ReadyToShow value)? readyToShow,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdsStateCopyWith<$Res> {
  factory $AdsStateCopyWith(AdsState value, $Res Function(AdsState) then) =
      _$AdsStateCopyWithImpl<$Res, AdsState>;
}

/// @nodoc
class _$AdsStateCopyWithImpl<$Res, $Val extends AdsState>
    implements $AdsStateCopyWith<$Res> {
  _$AdsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$InitialImplCopyWith<$Res> {
  factory _$$InitialImplCopyWith(
          _$InitialImpl value, $Res Function(_$InitialImpl) then) =
      __$$InitialImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$InitialImplCopyWithImpl<$Res>
    extends _$AdsStateCopyWithImpl<$Res, _$InitialImpl>
    implements _$$InitialImplCopyWith<$Res> {
  __$$InitialImplCopyWithImpl(
      _$InitialImpl _value, $Res Function(_$InitialImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$InitialImpl implements _Initial {
  const _$InitialImpl();

  @override
  String toString() {
    return 'AdsState.initial()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$InitialImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(String errorMessage, void Function()? onComplete)
        failed,
    required TResult Function(
            String placementId, AdReward reward, void Function()? onComplete)
        readyToShow,
  }) {
    return initial();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(String errorMessage, void Function()? onComplete)? failed,
    TResult? Function(
            String placementId, AdReward reward, void Function()? onComplete)?
        readyToShow,
  }) {
    return initial?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(String errorMessage, void Function()? onComplete)? failed,
    TResult Function(
            String placementId, AdReward reward, void Function()? onComplete)?
        readyToShow,
    required TResult orElse(),
  }) {
    if (initial != null) {
      return initial();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Failed value) failed,
    required TResult Function(_ReadyToShow value) readyToShow,
  }) {
    return initial(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Failed value)? failed,
    TResult? Function(_ReadyToShow value)? readyToShow,
  }) {
    return initial?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Failed value)? failed,
    TResult Function(_ReadyToShow value)? readyToShow,
    required TResult orElse(),
  }) {
    if (initial != null) {
      return initial(this);
    }
    return orElse();
  }
}

abstract class _Initial implements AdsState {
  const factory _Initial() = _$InitialImpl;
}

/// @nodoc
abstract class _$$LoadingImplCopyWith<$Res> {
  factory _$$LoadingImplCopyWith(
          _$LoadingImpl value, $Res Function(_$LoadingImpl) then) =
      __$$LoadingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$LoadingImplCopyWithImpl<$Res>
    extends _$AdsStateCopyWithImpl<$Res, _$LoadingImpl>
    implements _$$LoadingImplCopyWith<$Res> {
  __$$LoadingImplCopyWithImpl(
      _$LoadingImpl _value, $Res Function(_$LoadingImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$LoadingImpl implements _Loading {
  const _$LoadingImpl();

  @override
  String toString() {
    return 'AdsState.loading()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$LoadingImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(String errorMessage, void Function()? onComplete)
        failed,
    required TResult Function(
            String placementId, AdReward reward, void Function()? onComplete)
        readyToShow,
  }) {
    return loading();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(String errorMessage, void Function()? onComplete)? failed,
    TResult? Function(
            String placementId, AdReward reward, void Function()? onComplete)?
        readyToShow,
  }) {
    return loading?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(String errorMessage, void Function()? onComplete)? failed,
    TResult Function(
            String placementId, AdReward reward, void Function()? onComplete)?
        readyToShow,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Failed value) failed,
    required TResult Function(_ReadyToShow value) readyToShow,
  }) {
    return loading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Failed value)? failed,
    TResult? Function(_ReadyToShow value)? readyToShow,
  }) {
    return loading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Failed value)? failed,
    TResult Function(_ReadyToShow value)? readyToShow,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(this);
    }
    return orElse();
  }
}

abstract class _Loading implements AdsState {
  const factory _Loading() = _$LoadingImpl;
}

/// @nodoc
abstract class _$$FailedImplCopyWith<$Res> {
  factory _$$FailedImplCopyWith(
          _$FailedImpl value, $Res Function(_$FailedImpl) then) =
      __$$FailedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String errorMessage, void Function()? onComplete});
}

/// @nodoc
class __$$FailedImplCopyWithImpl<$Res>
    extends _$AdsStateCopyWithImpl<$Res, _$FailedImpl>
    implements _$$FailedImplCopyWith<$Res> {
  __$$FailedImplCopyWithImpl(
      _$FailedImpl _value, $Res Function(_$FailedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? errorMessage = null,
    Object? onComplete = freezed,
  }) {
    return _then(_$FailedImpl(
      null == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String,
      onComplete: freezed == onComplete
          ? _value.onComplete
          : onComplete // ignore: cast_nullable_to_non_nullable
              as void Function()?,
    ));
  }
}

/// @nodoc

class _$FailedImpl implements _Failed {
  const _$FailedImpl(this.errorMessage, {this.onComplete});

  @override
  final String errorMessage;
  @override
  final void Function()? onComplete;

  @override
  String toString() {
    return 'AdsState.failed(errorMessage: $errorMessage, onComplete: $onComplete)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FailedImpl &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.onComplete, onComplete) ||
                other.onComplete == onComplete));
  }

  @override
  int get hashCode => Object.hash(runtimeType, errorMessage, onComplete);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FailedImplCopyWith<_$FailedImpl> get copyWith =>
      __$$FailedImplCopyWithImpl<_$FailedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(String errorMessage, void Function()? onComplete)
        failed,
    required TResult Function(
            String placementId, AdReward reward, void Function()? onComplete)
        readyToShow,
  }) {
    return failed(errorMessage, onComplete);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(String errorMessage, void Function()? onComplete)? failed,
    TResult? Function(
            String placementId, AdReward reward, void Function()? onComplete)?
        readyToShow,
  }) {
    return failed?.call(errorMessage, onComplete);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(String errorMessage, void Function()? onComplete)? failed,
    TResult Function(
            String placementId, AdReward reward, void Function()? onComplete)?
        readyToShow,
    required TResult orElse(),
  }) {
    if (failed != null) {
      return failed(errorMessage, onComplete);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Failed value) failed,
    required TResult Function(_ReadyToShow value) readyToShow,
  }) {
    return failed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Failed value)? failed,
    TResult? Function(_ReadyToShow value)? readyToShow,
  }) {
    return failed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Failed value)? failed,
    TResult Function(_ReadyToShow value)? readyToShow,
    required TResult orElse(),
  }) {
    if (failed != null) {
      return failed(this);
    }
    return orElse();
  }
}

abstract class _Failed implements AdsState {
  const factory _Failed(final String errorMessage,
      {final void Function()? onComplete}) = _$FailedImpl;

  String get errorMessage;
  void Function()? get onComplete;
  @JsonKey(ignore: true)
  _$$FailedImplCopyWith<_$FailedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ReadyToShowImplCopyWith<$Res> {
  factory _$$ReadyToShowImplCopyWith(
          _$ReadyToShowImpl value, $Res Function(_$ReadyToShowImpl) then) =
      __$$ReadyToShowImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String placementId, AdReward reward, void Function()? onComplete});

  $AdRewardCopyWith<$Res> get reward;
}

/// @nodoc
class __$$ReadyToShowImplCopyWithImpl<$Res>
    extends _$AdsStateCopyWithImpl<$Res, _$ReadyToShowImpl>
    implements _$$ReadyToShowImplCopyWith<$Res> {
  __$$ReadyToShowImplCopyWithImpl(
      _$ReadyToShowImpl _value, $Res Function(_$ReadyToShowImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? placementId = null,
    Object? reward = null,
    Object? onComplete = freezed,
  }) {
    return _then(_$ReadyToShowImpl(
      placementId: null == placementId
          ? _value.placementId
          : placementId // ignore: cast_nullable_to_non_nullable
              as String,
      reward: null == reward
          ? _value.reward
          : reward // ignore: cast_nullable_to_non_nullable
              as AdReward,
      onComplete: freezed == onComplete
          ? _value.onComplete
          : onComplete // ignore: cast_nullable_to_non_nullable
              as void Function()?,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $AdRewardCopyWith<$Res> get reward {
    return $AdRewardCopyWith<$Res>(_value.reward, (value) {
      return _then(_value.copyWith(reward: value));
    });
  }
}

/// @nodoc

class _$ReadyToShowImpl implements _ReadyToShow {
  const _$ReadyToShowImpl(
      {required this.placementId, required this.reward, this.onComplete});

  @override
  final String placementId;
  @override
  final AdReward reward;
  @override
  final void Function()? onComplete;

  @override
  String toString() {
    return 'AdsState.readyToShow(placementId: $placementId, reward: $reward, onComplete: $onComplete)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReadyToShowImpl &&
            (identical(other.placementId, placementId) ||
                other.placementId == placementId) &&
            (identical(other.reward, reward) || other.reward == reward) &&
            (identical(other.onComplete, onComplete) ||
                other.onComplete == onComplete));
  }

  @override
  int get hashCode => Object.hash(runtimeType, placementId, reward, onComplete);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReadyToShowImplCopyWith<_$ReadyToShowImpl> get copyWith =>
      __$$ReadyToShowImplCopyWithImpl<_$ReadyToShowImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(String errorMessage, void Function()? onComplete)
        failed,
    required TResult Function(
            String placementId, AdReward reward, void Function()? onComplete)
        readyToShow,
  }) {
    return readyToShow(placementId, reward, onComplete);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(String errorMessage, void Function()? onComplete)? failed,
    TResult? Function(
            String placementId, AdReward reward, void Function()? onComplete)?
        readyToShow,
  }) {
    return readyToShow?.call(placementId, reward, onComplete);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(String errorMessage, void Function()? onComplete)? failed,
    TResult Function(
            String placementId, AdReward reward, void Function()? onComplete)?
        readyToShow,
    required TResult orElse(),
  }) {
    if (readyToShow != null) {
      return readyToShow(placementId, reward, onComplete);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Failed value) failed,
    required TResult Function(_ReadyToShow value) readyToShow,
  }) {
    return readyToShow(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Failed value)? failed,
    TResult? Function(_ReadyToShow value)? readyToShow,
  }) {
    return readyToShow?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Failed value)? failed,
    TResult Function(_ReadyToShow value)? readyToShow,
    required TResult orElse(),
  }) {
    if (readyToShow != null) {
      return readyToShow(this);
    }
    return orElse();
  }
}

abstract class _ReadyToShow implements AdsState {
  const factory _ReadyToShow(
      {required final String placementId,
      required final AdReward reward,
      final void Function()? onComplete}) = _$ReadyToShowImpl;

  String get placementId;
  AdReward get reward;
  void Function()? get onComplete;
  @JsonKey(ignore: true)
  _$$ReadyToShowImplCopyWith<_$ReadyToShowImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AdReward {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noReward,
    required TResult Function(int amount) bucks,
    required TResult Function(int amount) bucksInGame,
    required TResult Function(void Function() applyReward) custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noReward,
    TResult? Function(int amount)? bucks,
    TResult? Function(int amount)? bucksInGame,
    TResult? Function(void Function() applyReward)? custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noReward,
    TResult Function(int amount)? bucks,
    TResult Function(int amount)? bucksInGame,
    TResult Function(void Function() applyReward)? custom,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_NoReward value) noReward,
    required TResult Function(_Bucks value) bucks,
    required TResult Function(_BucksInGame value) bucksInGame,
    required TResult Function(_Custom value) custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_NoReward value)? noReward,
    TResult? Function(_Bucks value)? bucks,
    TResult? Function(_BucksInGame value)? bucksInGame,
    TResult? Function(_Custom value)? custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_NoReward value)? noReward,
    TResult Function(_Bucks value)? bucks,
    TResult Function(_BucksInGame value)? bucksInGame,
    TResult Function(_Custom value)? custom,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdRewardCopyWith<$Res> {
  factory $AdRewardCopyWith(AdReward value, $Res Function(AdReward) then) =
      _$AdRewardCopyWithImpl<$Res, AdReward>;
}

/// @nodoc
class _$AdRewardCopyWithImpl<$Res, $Val extends AdReward>
    implements $AdRewardCopyWith<$Res> {
  _$AdRewardCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$NoRewardImplCopyWith<$Res> {
  factory _$$NoRewardImplCopyWith(
          _$NoRewardImpl value, $Res Function(_$NoRewardImpl) then) =
      __$$NoRewardImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$NoRewardImplCopyWithImpl<$Res>
    extends _$AdRewardCopyWithImpl<$Res, _$NoRewardImpl>
    implements _$$NoRewardImplCopyWith<$Res> {
  __$$NoRewardImplCopyWithImpl(
      _$NoRewardImpl _value, $Res Function(_$NoRewardImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$NoRewardImpl implements _NoReward {
  const _$NoRewardImpl();

  @override
  String toString() {
    return 'AdReward.noReward()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$NoRewardImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noReward,
    required TResult Function(int amount) bucks,
    required TResult Function(int amount) bucksInGame,
    required TResult Function(void Function() applyReward) custom,
  }) {
    return noReward();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noReward,
    TResult? Function(int amount)? bucks,
    TResult? Function(int amount)? bucksInGame,
    TResult? Function(void Function() applyReward)? custom,
  }) {
    return noReward?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noReward,
    TResult Function(int amount)? bucks,
    TResult Function(int amount)? bucksInGame,
    TResult Function(void Function() applyReward)? custom,
    required TResult orElse(),
  }) {
    if (noReward != null) {
      return noReward();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_NoReward value) noReward,
    required TResult Function(_Bucks value) bucks,
    required TResult Function(_BucksInGame value) bucksInGame,
    required TResult Function(_Custom value) custom,
  }) {
    return noReward(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_NoReward value)? noReward,
    TResult? Function(_Bucks value)? bucks,
    TResult? Function(_BucksInGame value)? bucksInGame,
    TResult? Function(_Custom value)? custom,
  }) {
    return noReward?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_NoReward value)? noReward,
    TResult Function(_Bucks value)? bucks,
    TResult Function(_BucksInGame value)? bucksInGame,
    TResult Function(_Custom value)? custom,
    required TResult orElse(),
  }) {
    if (noReward != null) {
      return noReward(this);
    }
    return orElse();
  }
}

abstract class _NoReward implements AdReward {
  const factory _NoReward() = _$NoRewardImpl;
}

/// @nodoc
abstract class _$$BucksImplCopyWith<$Res> {
  factory _$$BucksImplCopyWith(
          _$BucksImpl value, $Res Function(_$BucksImpl) then) =
      __$$BucksImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int amount});
}

/// @nodoc
class __$$BucksImplCopyWithImpl<$Res>
    extends _$AdRewardCopyWithImpl<$Res, _$BucksImpl>
    implements _$$BucksImplCopyWith<$Res> {
  __$$BucksImplCopyWithImpl(
      _$BucksImpl _value, $Res Function(_$BucksImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
  }) {
    return _then(_$BucksImpl(
      null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$BucksImpl implements _Bucks {
  const _$BucksImpl(this.amount);

  @override
  final int amount;

  @override
  String toString() {
    return 'AdReward.bucks(amount: $amount)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BucksImpl &&
            (identical(other.amount, amount) || other.amount == amount));
  }

  @override
  int get hashCode => Object.hash(runtimeType, amount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BucksImplCopyWith<_$BucksImpl> get copyWith =>
      __$$BucksImplCopyWithImpl<_$BucksImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noReward,
    required TResult Function(int amount) bucks,
    required TResult Function(int amount) bucksInGame,
    required TResult Function(void Function() applyReward) custom,
  }) {
    return bucks(amount);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noReward,
    TResult? Function(int amount)? bucks,
    TResult? Function(int amount)? bucksInGame,
    TResult? Function(void Function() applyReward)? custom,
  }) {
    return bucks?.call(amount);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noReward,
    TResult Function(int amount)? bucks,
    TResult Function(int amount)? bucksInGame,
    TResult Function(void Function() applyReward)? custom,
    required TResult orElse(),
  }) {
    if (bucks != null) {
      return bucks(amount);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_NoReward value) noReward,
    required TResult Function(_Bucks value) bucks,
    required TResult Function(_BucksInGame value) bucksInGame,
    required TResult Function(_Custom value) custom,
  }) {
    return bucks(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_NoReward value)? noReward,
    TResult? Function(_Bucks value)? bucks,
    TResult? Function(_BucksInGame value)? bucksInGame,
    TResult? Function(_Custom value)? custom,
  }) {
    return bucks?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_NoReward value)? noReward,
    TResult Function(_Bucks value)? bucks,
    TResult Function(_BucksInGame value)? bucksInGame,
    TResult Function(_Custom value)? custom,
    required TResult orElse(),
  }) {
    if (bucks != null) {
      return bucks(this);
    }
    return orElse();
  }
}

abstract class _Bucks implements AdReward {
  const factory _Bucks(final int amount) = _$BucksImpl;

  int get amount;
  @JsonKey(ignore: true)
  _$$BucksImplCopyWith<_$BucksImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$BucksInGameImplCopyWith<$Res> {
  factory _$$BucksInGameImplCopyWith(
          _$BucksInGameImpl value, $Res Function(_$BucksInGameImpl) then) =
      __$$BucksInGameImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int amount});
}

/// @nodoc
class __$$BucksInGameImplCopyWithImpl<$Res>
    extends _$AdRewardCopyWithImpl<$Res, _$BucksInGameImpl>
    implements _$$BucksInGameImplCopyWith<$Res> {
  __$$BucksInGameImplCopyWithImpl(
      _$BucksInGameImpl _value, $Res Function(_$BucksInGameImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
  }) {
    return _then(_$BucksInGameImpl(
      null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$BucksInGameImpl implements _BucksInGame {
  const _$BucksInGameImpl(this.amount);

  @override
  final int amount;

  @override
  String toString() {
    return 'AdReward.bucksInGame(amount: $amount)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BucksInGameImpl &&
            (identical(other.amount, amount) || other.amount == amount));
  }

  @override
  int get hashCode => Object.hash(runtimeType, amount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BucksInGameImplCopyWith<_$BucksInGameImpl> get copyWith =>
      __$$BucksInGameImplCopyWithImpl<_$BucksInGameImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noReward,
    required TResult Function(int amount) bucks,
    required TResult Function(int amount) bucksInGame,
    required TResult Function(void Function() applyReward) custom,
  }) {
    return bucksInGame(amount);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noReward,
    TResult? Function(int amount)? bucks,
    TResult? Function(int amount)? bucksInGame,
    TResult? Function(void Function() applyReward)? custom,
  }) {
    return bucksInGame?.call(amount);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noReward,
    TResult Function(int amount)? bucks,
    TResult Function(int amount)? bucksInGame,
    TResult Function(void Function() applyReward)? custom,
    required TResult orElse(),
  }) {
    if (bucksInGame != null) {
      return bucksInGame(amount);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_NoReward value) noReward,
    required TResult Function(_Bucks value) bucks,
    required TResult Function(_BucksInGame value) bucksInGame,
    required TResult Function(_Custom value) custom,
  }) {
    return bucksInGame(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_NoReward value)? noReward,
    TResult? Function(_Bucks value)? bucks,
    TResult? Function(_BucksInGame value)? bucksInGame,
    TResult? Function(_Custom value)? custom,
  }) {
    return bucksInGame?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_NoReward value)? noReward,
    TResult Function(_Bucks value)? bucks,
    TResult Function(_BucksInGame value)? bucksInGame,
    TResult Function(_Custom value)? custom,
    required TResult orElse(),
  }) {
    if (bucksInGame != null) {
      return bucksInGame(this);
    }
    return orElse();
  }
}

abstract class _BucksInGame implements AdReward {
  const factory _BucksInGame(final int amount) = _$BucksInGameImpl;

  int get amount;
  @JsonKey(ignore: true)
  _$$BucksInGameImplCopyWith<_$BucksInGameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$CustomImplCopyWith<$Res> {
  factory _$$CustomImplCopyWith(
          _$CustomImpl value, $Res Function(_$CustomImpl) then) =
      __$$CustomImplCopyWithImpl<$Res>;
  @useResult
  $Res call({void Function() applyReward});
}

/// @nodoc
class __$$CustomImplCopyWithImpl<$Res>
    extends _$AdRewardCopyWithImpl<$Res, _$CustomImpl>
    implements _$$CustomImplCopyWith<$Res> {
  __$$CustomImplCopyWithImpl(
      _$CustomImpl _value, $Res Function(_$CustomImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? applyReward = null,
  }) {
    return _then(_$CustomImpl(
      null == applyReward
          ? _value.applyReward
          : applyReward // ignore: cast_nullable_to_non_nullable
              as void Function(),
    ));
  }
}

/// @nodoc

class _$CustomImpl implements _Custom {
  const _$CustomImpl(this.applyReward);

  @override
  final void Function() applyReward;

  @override
  String toString() {
    return 'AdReward.custom(applyReward: $applyReward)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CustomImpl &&
            (identical(other.applyReward, applyReward) ||
                other.applyReward == applyReward));
  }

  @override
  int get hashCode => Object.hash(runtimeType, applyReward);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CustomImplCopyWith<_$CustomImpl> get copyWith =>
      __$$CustomImplCopyWithImpl<_$CustomImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noReward,
    required TResult Function(int amount) bucks,
    required TResult Function(int amount) bucksInGame,
    required TResult Function(void Function() applyReward) custom,
  }) {
    return custom(applyReward);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noReward,
    TResult? Function(int amount)? bucks,
    TResult? Function(int amount)? bucksInGame,
    TResult? Function(void Function() applyReward)? custom,
  }) {
    return custom?.call(applyReward);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noReward,
    TResult Function(int amount)? bucks,
    TResult Function(int amount)? bucksInGame,
    TResult Function(void Function() applyReward)? custom,
    required TResult orElse(),
  }) {
    if (custom != null) {
      return custom(applyReward);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_NoReward value) noReward,
    required TResult Function(_Bucks value) bucks,
    required TResult Function(_BucksInGame value) bucksInGame,
    required TResult Function(_Custom value) custom,
  }) {
    return custom(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_NoReward value)? noReward,
    TResult? Function(_Bucks value)? bucks,
    TResult? Function(_BucksInGame value)? bucksInGame,
    TResult? Function(_Custom value)? custom,
  }) {
    return custom?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_NoReward value)? noReward,
    TResult Function(_Bucks value)? bucks,
    TResult Function(_BucksInGame value)? bucksInGame,
    TResult Function(_Custom value)? custom,
    required TResult orElse(),
  }) {
    if (custom != null) {
      return custom(this);
    }
    return orElse();
  }
}

abstract class _Custom implements AdReward {
  const factory _Custom(final void Function() applyReward) = _$CustomImpl;

  void Function() get applyReward;
  @JsonKey(ignore: true)
  _$$CustomImplCopyWith<_$CustomImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
