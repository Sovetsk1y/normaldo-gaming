// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mission.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

Mission _$MissionFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'collectPizza':
      return _CollectPizzaMission.fromJson(json);
    case 'crashItem':
      return _CrashItemMission.fromJson(json);
    case 'passItem':
      return _PassItemMission.fromJson(json);
    case 'reachLocation':
      return _ReachLocationMission.fromJson(json);
    case 'finishGame':
      return _FinishGameMission.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'Mission',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$Mission {
  int get exp => throw _privateConstructorUsedError;
  int get completeValue => throw _privateConstructorUsedError;
  bool get isOneGame => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  int get adsViewed => throw _privateConstructorUsedError;
  MissionType get type => throw _privateConstructorUsedError;
  int get currentValue => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)
        collectPizza,
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)
        crashItem,
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)
        passItem,
    required TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)
        reachLocation,
    required TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)
        finishGame,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)?
        collectPizza,
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        crashItem,
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        passItem,
    TResult? Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        reachLocation,
    TResult? Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        finishGame,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)?
        collectPizza,
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        crashItem,
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        passItem,
    TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        reachLocation,
    TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        finishGame,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_CollectPizzaMission value) collectPizza,
    required TResult Function(_CrashItemMission value) crashItem,
    required TResult Function(_PassItemMission value) passItem,
    required TResult Function(_ReachLocationMission value) reachLocation,
    required TResult Function(_FinishGameMission value) finishGame,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_CollectPizzaMission value)? collectPizza,
    TResult? Function(_CrashItemMission value)? crashItem,
    TResult? Function(_PassItemMission value)? passItem,
    TResult? Function(_ReachLocationMission value)? reachLocation,
    TResult? Function(_FinishGameMission value)? finishGame,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_CollectPizzaMission value)? collectPizza,
    TResult Function(_CrashItemMission value)? crashItem,
    TResult Function(_PassItemMission value)? passItem,
    TResult Function(_ReachLocationMission value)? reachLocation,
    TResult Function(_FinishGameMission value)? finishGame,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MissionCopyWith<Mission> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MissionCopyWith<$Res> {
  factory $MissionCopyWith(Mission value, $Res Function(Mission) then) =
      _$MissionCopyWithImpl<$Res, Mission>;
  @useResult
  $Res call(
      {int exp,
      int completeValue,
      bool isOneGame,
      String description,
      int adsViewed,
      MissionType type,
      int currentValue});
}

/// @nodoc
class _$MissionCopyWithImpl<$Res, $Val extends Mission>
    implements $MissionCopyWith<$Res> {
  _$MissionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exp = null,
    Object? completeValue = null,
    Object? isOneGame = null,
    Object? description = null,
    Object? adsViewed = null,
    Object? type = null,
    Object? currentValue = null,
  }) {
    return _then(_value.copyWith(
      exp: null == exp
          ? _value.exp
          : exp // ignore: cast_nullable_to_non_nullable
              as int,
      completeValue: null == completeValue
          ? _value.completeValue
          : completeValue // ignore: cast_nullable_to_non_nullable
              as int,
      isOneGame: null == isOneGame
          ? _value.isOneGame
          : isOneGame // ignore: cast_nullable_to_non_nullable
              as bool,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      adsViewed: null == adsViewed
          ? _value.adsViewed
          : adsViewed // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MissionType,
      currentValue: null == currentValue
          ? _value.currentValue
          : currentValue // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CollectPizzaMissionImplCopyWith<$Res>
    implements $MissionCopyWith<$Res> {
  factory _$$CollectPizzaMissionImplCopyWith(_$CollectPizzaMissionImpl value,
          $Res Function(_$CollectPizzaMissionImpl) then) =
      __$$CollectPizzaMissionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int exp,
      int completeValue,
      bool isOneGame,
      String description,
      int adsViewed,
      MissionType type,
      int currentValue});
}

/// @nodoc
class __$$CollectPizzaMissionImplCopyWithImpl<$Res>
    extends _$MissionCopyWithImpl<$Res, _$CollectPizzaMissionImpl>
    implements _$$CollectPizzaMissionImplCopyWith<$Res> {
  __$$CollectPizzaMissionImplCopyWithImpl(_$CollectPizzaMissionImpl _value,
      $Res Function(_$CollectPizzaMissionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exp = null,
    Object? completeValue = null,
    Object? isOneGame = null,
    Object? description = null,
    Object? adsViewed = null,
    Object? type = null,
    Object? currentValue = null,
  }) {
    return _then(_$CollectPizzaMissionImpl(
      exp: null == exp
          ? _value.exp
          : exp // ignore: cast_nullable_to_non_nullable
              as int,
      completeValue: null == completeValue
          ? _value.completeValue
          : completeValue // ignore: cast_nullable_to_non_nullable
              as int,
      isOneGame: null == isOneGame
          ? _value.isOneGame
          : isOneGame // ignore: cast_nullable_to_non_nullable
              as bool,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      adsViewed: null == adsViewed
          ? _value.adsViewed
          : adsViewed // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MissionType,
      currentValue: null == currentValue
          ? _value.currentValue
          : currentValue // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CollectPizzaMissionImpl extends _CollectPizzaMission {
  _$CollectPizzaMissionImpl(
      {required this.exp,
      required this.completeValue,
      required this.isOneGame,
      required this.description,
      required this.adsViewed,
      this.type = MissionType.collectPizza,
      this.currentValue = 0,
      final String? $type})
      : assert(type == MissionType.collectPizza,
            'type must be MissionType.collectPizza'),
        assert(currentValue >= 0, 'currentValue must be greater or equal to 0'),
        $type = $type ?? 'collectPizza',
        super._();

  factory _$CollectPizzaMissionImpl.fromJson(Map<String, dynamic> json) =>
      _$$CollectPizzaMissionImplFromJson(json);

  @override
  final int exp;
  @override
  final int completeValue;
  @override
  final bool isOneGame;
  @override
  final String description;
  @override
  final int adsViewed;
  @override
  @JsonKey()
  final MissionType type;
  @override
  @JsonKey()
  final int currentValue;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Mission.collectPizza(exp: $exp, completeValue: $completeValue, isOneGame: $isOneGame, description: $description, adsViewed: $adsViewed, type: $type, currentValue: $currentValue)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CollectPizzaMissionImpl &&
            (identical(other.exp, exp) || other.exp == exp) &&
            (identical(other.completeValue, completeValue) ||
                other.completeValue == completeValue) &&
            (identical(other.isOneGame, isOneGame) ||
                other.isOneGame == isOneGame) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.adsViewed, adsViewed) ||
                other.adsViewed == adsViewed) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.currentValue, currentValue) ||
                other.currentValue == currentValue));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, exp, completeValue, isOneGame,
      description, adsViewed, type, currentValue);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CollectPizzaMissionImplCopyWith<_$CollectPizzaMissionImpl> get copyWith =>
      __$$CollectPizzaMissionImplCopyWithImpl<_$CollectPizzaMissionImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)
        collectPizza,
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)
        crashItem,
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)
        passItem,
    required TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)
        reachLocation,
    required TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)
        finishGame,
  }) {
    return collectPizza(exp, completeValue, isOneGame, description, adsViewed,
        type, currentValue);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)?
        collectPizza,
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        crashItem,
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        passItem,
    TResult? Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        reachLocation,
    TResult? Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        finishGame,
  }) {
    return collectPizza?.call(exp, completeValue, isOneGame, description,
        adsViewed, type, currentValue);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)?
        collectPizza,
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        crashItem,
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        passItem,
    TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        reachLocation,
    TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        finishGame,
    required TResult orElse(),
  }) {
    if (collectPizza != null) {
      return collectPizza(exp, completeValue, isOneGame, description, adsViewed,
          type, currentValue);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_CollectPizzaMission value) collectPizza,
    required TResult Function(_CrashItemMission value) crashItem,
    required TResult Function(_PassItemMission value) passItem,
    required TResult Function(_ReachLocationMission value) reachLocation,
    required TResult Function(_FinishGameMission value) finishGame,
  }) {
    return collectPizza(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_CollectPizzaMission value)? collectPizza,
    TResult? Function(_CrashItemMission value)? crashItem,
    TResult? Function(_PassItemMission value)? passItem,
    TResult? Function(_ReachLocationMission value)? reachLocation,
    TResult? Function(_FinishGameMission value)? finishGame,
  }) {
    return collectPizza?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_CollectPizzaMission value)? collectPizza,
    TResult Function(_CrashItemMission value)? crashItem,
    TResult Function(_PassItemMission value)? passItem,
    TResult Function(_ReachLocationMission value)? reachLocation,
    TResult Function(_FinishGameMission value)? finishGame,
    required TResult orElse(),
  }) {
    if (collectPizza != null) {
      return collectPizza(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$CollectPizzaMissionImplToJson(
      this,
    );
  }
}

abstract class _CollectPizzaMission extends Mission {
  factory _CollectPizzaMission(
      {required final int exp,
      required final int completeValue,
      required final bool isOneGame,
      required final String description,
      required final int adsViewed,
      final MissionType type,
      final int currentValue}) = _$CollectPizzaMissionImpl;
  _CollectPizzaMission._() : super._();

  factory _CollectPizzaMission.fromJson(Map<String, dynamic> json) =
      _$CollectPizzaMissionImpl.fromJson;

  @override
  int get exp;
  @override
  int get completeValue;
  @override
  bool get isOneGame;
  @override
  String get description;
  @override
  int get adsViewed;
  @override
  MissionType get type;
  @override
  int get currentValue;
  @override
  @JsonKey(ignore: true)
  _$$CollectPizzaMissionImplCopyWith<_$CollectPizzaMissionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$CrashItemMissionImplCopyWith<$Res>
    implements $MissionCopyWith<$Res> {
  factory _$$CrashItemMissionImplCopyWith(_$CrashItemMissionImpl value,
          $Res Function(_$CrashItemMissionImpl) then) =
      __$$CrashItemMissionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int exp,
      int completeValue,
      bool isOneGame,
      String description,
      int adsViewed,
      Items item,
      MissionType type,
      int currentValue});
}

/// @nodoc
class __$$CrashItemMissionImplCopyWithImpl<$Res>
    extends _$MissionCopyWithImpl<$Res, _$CrashItemMissionImpl>
    implements _$$CrashItemMissionImplCopyWith<$Res> {
  __$$CrashItemMissionImplCopyWithImpl(_$CrashItemMissionImpl _value,
      $Res Function(_$CrashItemMissionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exp = null,
    Object? completeValue = null,
    Object? isOneGame = null,
    Object? description = null,
    Object? adsViewed = null,
    Object? item = null,
    Object? type = null,
    Object? currentValue = null,
  }) {
    return _then(_$CrashItemMissionImpl(
      exp: null == exp
          ? _value.exp
          : exp // ignore: cast_nullable_to_non_nullable
              as int,
      completeValue: null == completeValue
          ? _value.completeValue
          : completeValue // ignore: cast_nullable_to_non_nullable
              as int,
      isOneGame: null == isOneGame
          ? _value.isOneGame
          : isOneGame // ignore: cast_nullable_to_non_nullable
              as bool,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      adsViewed: null == adsViewed
          ? _value.adsViewed
          : adsViewed // ignore: cast_nullable_to_non_nullable
              as int,
      item: null == item
          ? _value.item
          : item // ignore: cast_nullable_to_non_nullable
              as Items,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MissionType,
      currentValue: null == currentValue
          ? _value.currentValue
          : currentValue // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CrashItemMissionImpl extends _CrashItemMission {
  _$CrashItemMissionImpl(
      {required this.exp,
      required this.completeValue,
      required this.isOneGame,
      required this.description,
      required this.adsViewed,
      required this.item,
      this.type = MissionType.crashItem,
      this.currentValue = 0,
      final String? $type})
      : assert(type == MissionType.crashItem,
            'type must be MissionType.crashItem'),
        assert(currentValue >= 0, 'currentValue must be greater or equal to 0'),
        $type = $type ?? 'crashItem',
        super._();

  factory _$CrashItemMissionImpl.fromJson(Map<String, dynamic> json) =>
      _$$CrashItemMissionImplFromJson(json);

  @override
  final int exp;
  @override
  final int completeValue;
  @override
  final bool isOneGame;
  @override
  final String description;
  @override
  final int adsViewed;
  @override
  final Items item;
  @override
  @JsonKey()
  final MissionType type;
  @override
  @JsonKey()
  final int currentValue;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Mission.crashItem(exp: $exp, completeValue: $completeValue, isOneGame: $isOneGame, description: $description, adsViewed: $adsViewed, item: $item, type: $type, currentValue: $currentValue)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CrashItemMissionImpl &&
            (identical(other.exp, exp) || other.exp == exp) &&
            (identical(other.completeValue, completeValue) ||
                other.completeValue == completeValue) &&
            (identical(other.isOneGame, isOneGame) ||
                other.isOneGame == isOneGame) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.adsViewed, adsViewed) ||
                other.adsViewed == adsViewed) &&
            (identical(other.item, item) || other.item == item) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.currentValue, currentValue) ||
                other.currentValue == currentValue));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, exp, completeValue, isOneGame,
      description, adsViewed, item, type, currentValue);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CrashItemMissionImplCopyWith<_$CrashItemMissionImpl> get copyWith =>
      __$$CrashItemMissionImplCopyWithImpl<_$CrashItemMissionImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)
        collectPizza,
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)
        crashItem,
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)
        passItem,
    required TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)
        reachLocation,
    required TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)
        finishGame,
  }) {
    return crashItem(exp, completeValue, isOneGame, description, adsViewed,
        item, type, currentValue);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)?
        collectPizza,
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        crashItem,
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        passItem,
    TResult? Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        reachLocation,
    TResult? Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        finishGame,
  }) {
    return crashItem?.call(exp, completeValue, isOneGame, description,
        adsViewed, item, type, currentValue);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)?
        collectPizza,
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        crashItem,
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        passItem,
    TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        reachLocation,
    TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        finishGame,
    required TResult orElse(),
  }) {
    if (crashItem != null) {
      return crashItem(exp, completeValue, isOneGame, description, adsViewed,
          item, type, currentValue);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_CollectPizzaMission value) collectPizza,
    required TResult Function(_CrashItemMission value) crashItem,
    required TResult Function(_PassItemMission value) passItem,
    required TResult Function(_ReachLocationMission value) reachLocation,
    required TResult Function(_FinishGameMission value) finishGame,
  }) {
    return crashItem(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_CollectPizzaMission value)? collectPizza,
    TResult? Function(_CrashItemMission value)? crashItem,
    TResult? Function(_PassItemMission value)? passItem,
    TResult? Function(_ReachLocationMission value)? reachLocation,
    TResult? Function(_FinishGameMission value)? finishGame,
  }) {
    return crashItem?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_CollectPizzaMission value)? collectPizza,
    TResult Function(_CrashItemMission value)? crashItem,
    TResult Function(_PassItemMission value)? passItem,
    TResult Function(_ReachLocationMission value)? reachLocation,
    TResult Function(_FinishGameMission value)? finishGame,
    required TResult orElse(),
  }) {
    if (crashItem != null) {
      return crashItem(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$CrashItemMissionImplToJson(
      this,
    );
  }
}

abstract class _CrashItemMission extends Mission {
  factory _CrashItemMission(
      {required final int exp,
      required final int completeValue,
      required final bool isOneGame,
      required final String description,
      required final int adsViewed,
      required final Items item,
      final MissionType type,
      final int currentValue}) = _$CrashItemMissionImpl;
  _CrashItemMission._() : super._();

  factory _CrashItemMission.fromJson(Map<String, dynamic> json) =
      _$CrashItemMissionImpl.fromJson;

  @override
  int get exp;
  @override
  int get completeValue;
  @override
  bool get isOneGame;
  @override
  String get description;
  @override
  int get adsViewed;
  Items get item;
  @override
  MissionType get type;
  @override
  int get currentValue;
  @override
  @JsonKey(ignore: true)
  _$$CrashItemMissionImplCopyWith<_$CrashItemMissionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PassItemMissionImplCopyWith<$Res>
    implements $MissionCopyWith<$Res> {
  factory _$$PassItemMissionImplCopyWith(_$PassItemMissionImpl value,
          $Res Function(_$PassItemMissionImpl) then) =
      __$$PassItemMissionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int exp,
      int completeValue,
      bool isOneGame,
      String description,
      int adsViewed,
      Items item,
      MissionType type,
      int currentValue});
}

/// @nodoc
class __$$PassItemMissionImplCopyWithImpl<$Res>
    extends _$MissionCopyWithImpl<$Res, _$PassItemMissionImpl>
    implements _$$PassItemMissionImplCopyWith<$Res> {
  __$$PassItemMissionImplCopyWithImpl(
      _$PassItemMissionImpl _value, $Res Function(_$PassItemMissionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exp = null,
    Object? completeValue = null,
    Object? isOneGame = null,
    Object? description = null,
    Object? adsViewed = null,
    Object? item = null,
    Object? type = null,
    Object? currentValue = null,
  }) {
    return _then(_$PassItemMissionImpl(
      exp: null == exp
          ? _value.exp
          : exp // ignore: cast_nullable_to_non_nullable
              as int,
      completeValue: null == completeValue
          ? _value.completeValue
          : completeValue // ignore: cast_nullable_to_non_nullable
              as int,
      isOneGame: null == isOneGame
          ? _value.isOneGame
          : isOneGame // ignore: cast_nullable_to_non_nullable
              as bool,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      adsViewed: null == adsViewed
          ? _value.adsViewed
          : adsViewed // ignore: cast_nullable_to_non_nullable
              as int,
      item: null == item
          ? _value.item
          : item // ignore: cast_nullable_to_non_nullable
              as Items,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MissionType,
      currentValue: null == currentValue
          ? _value.currentValue
          : currentValue // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PassItemMissionImpl extends _PassItemMission {
  _$PassItemMissionImpl(
      {required this.exp,
      required this.completeValue,
      required this.isOneGame,
      required this.description,
      required this.adsViewed,
      required this.item,
      this.type = MissionType.passItem,
      this.currentValue = 0,
      final String? $type})
      : assert(
            type == MissionType.passItem, 'type must be MissionType.passItem'),
        assert(currentValue >= 0, 'currentValue must be greater or equal to 0'),
        $type = $type ?? 'passItem',
        super._();

  factory _$PassItemMissionImpl.fromJson(Map<String, dynamic> json) =>
      _$$PassItemMissionImplFromJson(json);

  @override
  final int exp;
  @override
  final int completeValue;
  @override
  final bool isOneGame;
  @override
  final String description;
  @override
  final int adsViewed;
  @override
  final Items item;
  @override
  @JsonKey()
  final MissionType type;
  @override
  @JsonKey()
  final int currentValue;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Mission.passItem(exp: $exp, completeValue: $completeValue, isOneGame: $isOneGame, description: $description, adsViewed: $adsViewed, item: $item, type: $type, currentValue: $currentValue)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PassItemMissionImpl &&
            (identical(other.exp, exp) || other.exp == exp) &&
            (identical(other.completeValue, completeValue) ||
                other.completeValue == completeValue) &&
            (identical(other.isOneGame, isOneGame) ||
                other.isOneGame == isOneGame) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.adsViewed, adsViewed) ||
                other.adsViewed == adsViewed) &&
            (identical(other.item, item) || other.item == item) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.currentValue, currentValue) ||
                other.currentValue == currentValue));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, exp, completeValue, isOneGame,
      description, adsViewed, item, type, currentValue);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PassItemMissionImplCopyWith<_$PassItemMissionImpl> get copyWith =>
      __$$PassItemMissionImplCopyWithImpl<_$PassItemMissionImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)
        collectPizza,
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)
        crashItem,
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)
        passItem,
    required TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)
        reachLocation,
    required TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)
        finishGame,
  }) {
    return passItem(exp, completeValue, isOneGame, description, adsViewed, item,
        type, currentValue);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)?
        collectPizza,
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        crashItem,
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        passItem,
    TResult? Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        reachLocation,
    TResult? Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        finishGame,
  }) {
    return passItem?.call(exp, completeValue, isOneGame, description, adsViewed,
        item, type, currentValue);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)?
        collectPizza,
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        crashItem,
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        passItem,
    TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        reachLocation,
    TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        finishGame,
    required TResult orElse(),
  }) {
    if (passItem != null) {
      return passItem(exp, completeValue, isOneGame, description, adsViewed,
          item, type, currentValue);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_CollectPizzaMission value) collectPizza,
    required TResult Function(_CrashItemMission value) crashItem,
    required TResult Function(_PassItemMission value) passItem,
    required TResult Function(_ReachLocationMission value) reachLocation,
    required TResult Function(_FinishGameMission value) finishGame,
  }) {
    return passItem(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_CollectPizzaMission value)? collectPizza,
    TResult? Function(_CrashItemMission value)? crashItem,
    TResult? Function(_PassItemMission value)? passItem,
    TResult? Function(_ReachLocationMission value)? reachLocation,
    TResult? Function(_FinishGameMission value)? finishGame,
  }) {
    return passItem?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_CollectPizzaMission value)? collectPizza,
    TResult Function(_CrashItemMission value)? crashItem,
    TResult Function(_PassItemMission value)? passItem,
    TResult Function(_ReachLocationMission value)? reachLocation,
    TResult Function(_FinishGameMission value)? finishGame,
    required TResult orElse(),
  }) {
    if (passItem != null) {
      return passItem(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$PassItemMissionImplToJson(
      this,
    );
  }
}

abstract class _PassItemMission extends Mission {
  factory _PassItemMission(
      {required final int exp,
      required final int completeValue,
      required final bool isOneGame,
      required final String description,
      required final int adsViewed,
      required final Items item,
      final MissionType type,
      final int currentValue}) = _$PassItemMissionImpl;
  _PassItemMission._() : super._();

  factory _PassItemMission.fromJson(Map<String, dynamic> json) =
      _$PassItemMissionImpl.fromJson;

  @override
  int get exp;
  @override
  int get completeValue;
  @override
  bool get isOneGame;
  @override
  String get description;
  @override
  int get adsViewed;
  Items get item;
  @override
  MissionType get type;
  @override
  int get currentValue;
  @override
  @JsonKey(ignore: true)
  _$$PassItemMissionImplCopyWith<_$PassItemMissionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ReachLocationMissionImplCopyWith<$Res>
    implements $MissionCopyWith<$Res> {
  factory _$$ReachLocationMissionImplCopyWith(_$ReachLocationMissionImpl value,
          $Res Function(_$ReachLocationMissionImpl) then) =
      __$$ReachLocationMissionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int exp,
      String description,
      int adsViewed,
      int completeValue,
      bool isOneGame,
      MissionType type,
      int currentValue});
}

/// @nodoc
class __$$ReachLocationMissionImplCopyWithImpl<$Res>
    extends _$MissionCopyWithImpl<$Res, _$ReachLocationMissionImpl>
    implements _$$ReachLocationMissionImplCopyWith<$Res> {
  __$$ReachLocationMissionImplCopyWithImpl(_$ReachLocationMissionImpl _value,
      $Res Function(_$ReachLocationMissionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exp = null,
    Object? description = null,
    Object? adsViewed = null,
    Object? completeValue = null,
    Object? isOneGame = null,
    Object? type = null,
    Object? currentValue = null,
  }) {
    return _then(_$ReachLocationMissionImpl(
      exp: null == exp
          ? _value.exp
          : exp // ignore: cast_nullable_to_non_nullable
              as int,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      adsViewed: null == adsViewed
          ? _value.adsViewed
          : adsViewed // ignore: cast_nullable_to_non_nullable
              as int,
      completeValue: null == completeValue
          ? _value.completeValue
          : completeValue // ignore: cast_nullable_to_non_nullable
              as int,
      isOneGame: null == isOneGame
          ? _value.isOneGame
          : isOneGame // ignore: cast_nullable_to_non_nullable
              as bool,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MissionType,
      currentValue: null == currentValue
          ? _value.currentValue
          : currentValue // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReachLocationMissionImpl extends _ReachLocationMission {
  _$ReachLocationMissionImpl(
      {required this.exp,
      required this.description,
      required this.adsViewed,
      required this.completeValue,
      this.isOneGame = true,
      this.type = MissionType.reachLocation,
      this.currentValue = 0,
      final String? $type})
      : assert(type == MissionType.reachLocation,
            'type must be MissionType.reachLocation'),
        assert(currentValue >= 0, 'currentValue must be greater or equal to 0'),
        assert(isOneGame, 'reachLocation is always a one game mission'),
        assert(completeValue > 0, 'completeValue must be greater than 0'),
        $type = $type ?? 'reachLocation',
        super._();

  factory _$ReachLocationMissionImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReachLocationMissionImplFromJson(json);

  @override
  final int exp;
  @override
  final String description;
  @override
  final int adsViewed;
  @override
  final int completeValue;
  @override
  @JsonKey()
  final bool isOneGame;
  @override
  @JsonKey()
  final MissionType type;
  @override
  @JsonKey()
  final int currentValue;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Mission.reachLocation(exp: $exp, description: $description, adsViewed: $adsViewed, completeValue: $completeValue, isOneGame: $isOneGame, type: $type, currentValue: $currentValue)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReachLocationMissionImpl &&
            (identical(other.exp, exp) || other.exp == exp) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.adsViewed, adsViewed) ||
                other.adsViewed == adsViewed) &&
            (identical(other.completeValue, completeValue) ||
                other.completeValue == completeValue) &&
            (identical(other.isOneGame, isOneGame) ||
                other.isOneGame == isOneGame) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.currentValue, currentValue) ||
                other.currentValue == currentValue));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, exp, description, adsViewed,
      completeValue, isOneGame, type, currentValue);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReachLocationMissionImplCopyWith<_$ReachLocationMissionImpl>
      get copyWith =>
          __$$ReachLocationMissionImplCopyWithImpl<_$ReachLocationMissionImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)
        collectPizza,
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)
        crashItem,
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)
        passItem,
    required TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)
        reachLocation,
    required TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)
        finishGame,
  }) {
    return reachLocation(exp, description, adsViewed, completeValue, isOneGame,
        type, currentValue);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)?
        collectPizza,
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        crashItem,
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        passItem,
    TResult? Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        reachLocation,
    TResult? Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        finishGame,
  }) {
    return reachLocation?.call(exp, description, adsViewed, completeValue,
        isOneGame, type, currentValue);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)?
        collectPizza,
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        crashItem,
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        passItem,
    TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        reachLocation,
    TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        finishGame,
    required TResult orElse(),
  }) {
    if (reachLocation != null) {
      return reachLocation(exp, description, adsViewed, completeValue,
          isOneGame, type, currentValue);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_CollectPizzaMission value) collectPizza,
    required TResult Function(_CrashItemMission value) crashItem,
    required TResult Function(_PassItemMission value) passItem,
    required TResult Function(_ReachLocationMission value) reachLocation,
    required TResult Function(_FinishGameMission value) finishGame,
  }) {
    return reachLocation(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_CollectPizzaMission value)? collectPizza,
    TResult? Function(_CrashItemMission value)? crashItem,
    TResult? Function(_PassItemMission value)? passItem,
    TResult? Function(_ReachLocationMission value)? reachLocation,
    TResult? Function(_FinishGameMission value)? finishGame,
  }) {
    return reachLocation?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_CollectPizzaMission value)? collectPizza,
    TResult Function(_CrashItemMission value)? crashItem,
    TResult Function(_PassItemMission value)? passItem,
    TResult Function(_ReachLocationMission value)? reachLocation,
    TResult Function(_FinishGameMission value)? finishGame,
    required TResult orElse(),
  }) {
    if (reachLocation != null) {
      return reachLocation(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ReachLocationMissionImplToJson(
      this,
    );
  }
}

abstract class _ReachLocationMission extends Mission {
  factory _ReachLocationMission(
      {required final int exp,
      required final String description,
      required final int adsViewed,
      required final int completeValue,
      final bool isOneGame,
      final MissionType type,
      final int currentValue}) = _$ReachLocationMissionImpl;
  _ReachLocationMission._() : super._();

  factory _ReachLocationMission.fromJson(Map<String, dynamic> json) =
      _$ReachLocationMissionImpl.fromJson;

  @override
  int get exp;
  @override
  String get description;
  @override
  int get adsViewed;
  @override
  int get completeValue;
  @override
  bool get isOneGame;
  @override
  MissionType get type;
  @override
  int get currentValue;
  @override
  @JsonKey(ignore: true)
  _$$ReachLocationMissionImplCopyWith<_$ReachLocationMissionImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FinishGameMissionImplCopyWith<$Res>
    implements $MissionCopyWith<$Res> {
  factory _$$FinishGameMissionImplCopyWith(_$FinishGameMissionImpl value,
          $Res Function(_$FinishGameMissionImpl) then) =
      __$$FinishGameMissionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int exp,
      String description,
      int adsViewed,
      int completeValue,
      bool isOneGame,
      MissionType type,
      int currentValue});
}

/// @nodoc
class __$$FinishGameMissionImplCopyWithImpl<$Res>
    extends _$MissionCopyWithImpl<$Res, _$FinishGameMissionImpl>
    implements _$$FinishGameMissionImplCopyWith<$Res> {
  __$$FinishGameMissionImplCopyWithImpl(_$FinishGameMissionImpl _value,
      $Res Function(_$FinishGameMissionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exp = null,
    Object? description = null,
    Object? adsViewed = null,
    Object? completeValue = null,
    Object? isOneGame = null,
    Object? type = null,
    Object? currentValue = null,
  }) {
    return _then(_$FinishGameMissionImpl(
      exp: null == exp
          ? _value.exp
          : exp // ignore: cast_nullable_to_non_nullable
              as int,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      adsViewed: null == adsViewed
          ? _value.adsViewed
          : adsViewed // ignore: cast_nullable_to_non_nullable
              as int,
      completeValue: null == completeValue
          ? _value.completeValue
          : completeValue // ignore: cast_nullable_to_non_nullable
              as int,
      isOneGame: null == isOneGame
          ? _value.isOneGame
          : isOneGame // ignore: cast_nullable_to_non_nullable
              as bool,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MissionType,
      currentValue: null == currentValue
          ? _value.currentValue
          : currentValue // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FinishGameMissionImpl extends _FinishGameMission {
  _$FinishGameMissionImpl(
      {required this.exp,
      required this.description,
      required this.adsViewed,
      required this.completeValue,
      this.isOneGame = true,
      this.type = MissionType.finishGame,
      this.currentValue = 0,
      final String? $type})
      : assert(type == MissionType.finishGame,
            'type must be MissionType.finishGame'),
        assert(currentValue >= 0, 'currentValue must be greater or equal to 0'),
        assert(isOneGame, 'reachLocation is always a one game mission'),
        assert(completeValue > 0, 'completeValue must be greater than 0'),
        $type = $type ?? 'finishGame',
        super._();

  factory _$FinishGameMissionImpl.fromJson(Map<String, dynamic> json) =>
      _$$FinishGameMissionImplFromJson(json);

  @override
  final int exp;
  @override
  final String description;
  @override
  final int adsViewed;
  @override
  final int completeValue;
  @override
  @JsonKey()
  final bool isOneGame;
  @override
  @JsonKey()
  final MissionType type;
  @override
  @JsonKey()
  final int currentValue;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Mission.finishGame(exp: $exp, description: $description, adsViewed: $adsViewed, completeValue: $completeValue, isOneGame: $isOneGame, type: $type, currentValue: $currentValue)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FinishGameMissionImpl &&
            (identical(other.exp, exp) || other.exp == exp) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.adsViewed, adsViewed) ||
                other.adsViewed == adsViewed) &&
            (identical(other.completeValue, completeValue) ||
                other.completeValue == completeValue) &&
            (identical(other.isOneGame, isOneGame) ||
                other.isOneGame == isOneGame) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.currentValue, currentValue) ||
                other.currentValue == currentValue));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, exp, description, adsViewed,
      completeValue, isOneGame, type, currentValue);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FinishGameMissionImplCopyWith<_$FinishGameMissionImpl> get copyWith =>
      __$$FinishGameMissionImplCopyWithImpl<_$FinishGameMissionImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)
        collectPizza,
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)
        crashItem,
    required TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)
        passItem,
    required TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)
        reachLocation,
    required TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)
        finishGame,
  }) {
    return finishGame(exp, description, adsViewed, completeValue, isOneGame,
        type, currentValue);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)?
        collectPizza,
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        crashItem,
    TResult? Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        passItem,
    TResult? Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        reachLocation,
    TResult? Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        finishGame,
  }) {
    return finishGame?.call(exp, description, adsViewed, completeValue,
        isOneGame, type, currentValue);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            MissionType type,
            int currentValue)?
        collectPizza,
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        crashItem,
    TResult Function(
            int exp,
            int completeValue,
            bool isOneGame,
            String description,
            int adsViewed,
            Items item,
            MissionType type,
            int currentValue)?
        passItem,
    TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        reachLocation,
    TResult Function(
            int exp,
            String description,
            int adsViewed,
            int completeValue,
            bool isOneGame,
            MissionType type,
            int currentValue)?
        finishGame,
    required TResult orElse(),
  }) {
    if (finishGame != null) {
      return finishGame(exp, description, adsViewed, completeValue, isOneGame,
          type, currentValue);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_CollectPizzaMission value) collectPizza,
    required TResult Function(_CrashItemMission value) crashItem,
    required TResult Function(_PassItemMission value) passItem,
    required TResult Function(_ReachLocationMission value) reachLocation,
    required TResult Function(_FinishGameMission value) finishGame,
  }) {
    return finishGame(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_CollectPizzaMission value)? collectPizza,
    TResult? Function(_CrashItemMission value)? crashItem,
    TResult? Function(_PassItemMission value)? passItem,
    TResult? Function(_ReachLocationMission value)? reachLocation,
    TResult? Function(_FinishGameMission value)? finishGame,
  }) {
    return finishGame?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_CollectPizzaMission value)? collectPizza,
    TResult Function(_CrashItemMission value)? crashItem,
    TResult Function(_PassItemMission value)? passItem,
    TResult Function(_ReachLocationMission value)? reachLocation,
    TResult Function(_FinishGameMission value)? finishGame,
    required TResult orElse(),
  }) {
    if (finishGame != null) {
      return finishGame(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$FinishGameMissionImplToJson(
      this,
    );
  }
}

abstract class _FinishGameMission extends Mission {
  factory _FinishGameMission(
      {required final int exp,
      required final String description,
      required final int adsViewed,
      required final int completeValue,
      final bool isOneGame,
      final MissionType type,
      final int currentValue}) = _$FinishGameMissionImpl;
  _FinishGameMission._() : super._();

  factory _FinishGameMission.fromJson(Map<String, dynamic> json) =
      _$FinishGameMissionImpl.fromJson;

  @override
  int get exp;
  @override
  String get description;
  @override
  int get adsViewed;
  @override
  int get completeValue;
  @override
  bool get isOneGame;
  @override
  MissionType get type;
  @override
  int get currentValue;
  @override
  @JsonKey(ignore: true)
  _$$FinishGameMissionImplCopyWith<_$FinishGameMissionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
