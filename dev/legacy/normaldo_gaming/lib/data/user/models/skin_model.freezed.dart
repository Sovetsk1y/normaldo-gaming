// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'skin_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

SkinModel _$SkinModelFromJson(Map<String, dynamic> json) {
  return _SkinModel.fromJson(json);
}

/// @nodoc
mixin _$SkinModel {
  String get uniqueId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  SkinRarity get rarity => throw _privateConstructorUsedError;
  SkinAssetsModel get assetsModel => throw _privateConstructorUsedError;
  List<Items> get resistanceToItems => throw _privateConstructorUsedError;
  String? get uniqueSkill => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SkinModelCopyWith<SkinModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SkinModelCopyWith<$Res> {
  factory $SkinModelCopyWith(SkinModel value, $Res Function(SkinModel) then) =
      _$SkinModelCopyWithImpl<$Res, SkinModel>;
  @useResult
  $Res call(
      {String uniqueId,
      String name,
      SkinRarity rarity,
      SkinAssetsModel assetsModel,
      List<Items> resistanceToItems,
      String? uniqueSkill});

  $SkinAssetsModelCopyWith<$Res> get assetsModel;
}

/// @nodoc
class _$SkinModelCopyWithImpl<$Res, $Val extends SkinModel>
    implements $SkinModelCopyWith<$Res> {
  _$SkinModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uniqueId = null,
    Object? name = null,
    Object? rarity = null,
    Object? assetsModel = null,
    Object? resistanceToItems = null,
    Object? uniqueSkill = freezed,
  }) {
    return _then(_value.copyWith(
      uniqueId: null == uniqueId
          ? _value.uniqueId
          : uniqueId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      rarity: null == rarity
          ? _value.rarity
          : rarity // ignore: cast_nullable_to_non_nullable
              as SkinRarity,
      assetsModel: null == assetsModel
          ? _value.assetsModel
          : assetsModel // ignore: cast_nullable_to_non_nullable
              as SkinAssetsModel,
      resistanceToItems: null == resistanceToItems
          ? _value.resistanceToItems
          : resistanceToItems // ignore: cast_nullable_to_non_nullable
              as List<Items>,
      uniqueSkill: freezed == uniqueSkill
          ? _value.uniqueSkill
          : uniqueSkill // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $SkinAssetsModelCopyWith<$Res> get assetsModel {
    return $SkinAssetsModelCopyWith<$Res>(_value.assetsModel, (value) {
      return _then(_value.copyWith(assetsModel: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SkinModelImplCopyWith<$Res>
    implements $SkinModelCopyWith<$Res> {
  factory _$$SkinModelImplCopyWith(
          _$SkinModelImpl value, $Res Function(_$SkinModelImpl) then) =
      __$$SkinModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String uniqueId,
      String name,
      SkinRarity rarity,
      SkinAssetsModel assetsModel,
      List<Items> resistanceToItems,
      String? uniqueSkill});

  @override
  $SkinAssetsModelCopyWith<$Res> get assetsModel;
}

/// @nodoc
class __$$SkinModelImplCopyWithImpl<$Res>
    extends _$SkinModelCopyWithImpl<$Res, _$SkinModelImpl>
    implements _$$SkinModelImplCopyWith<$Res> {
  __$$SkinModelImplCopyWithImpl(
      _$SkinModelImpl _value, $Res Function(_$SkinModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uniqueId = null,
    Object? name = null,
    Object? rarity = null,
    Object? assetsModel = null,
    Object? resistanceToItems = null,
    Object? uniqueSkill = freezed,
  }) {
    return _then(_$SkinModelImpl(
      uniqueId: null == uniqueId
          ? _value.uniqueId
          : uniqueId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      rarity: null == rarity
          ? _value.rarity
          : rarity // ignore: cast_nullable_to_non_nullable
              as SkinRarity,
      assetsModel: null == assetsModel
          ? _value.assetsModel
          : assetsModel // ignore: cast_nullable_to_non_nullable
              as SkinAssetsModel,
      resistanceToItems: null == resistanceToItems
          ? _value._resistanceToItems
          : resistanceToItems // ignore: cast_nullable_to_non_nullable
              as List<Items>,
      uniqueSkill: freezed == uniqueSkill
          ? _value.uniqueSkill
          : uniqueSkill // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SkinModelImpl extends _SkinModel {
  const _$SkinModelImpl(
      {required this.uniqueId,
      required this.name,
      required this.rarity,
      required this.assetsModel,
      required final List<Items> resistanceToItems,
      this.uniqueSkill})
      : _resistanceToItems = resistanceToItems,
        super._();

  factory _$SkinModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$SkinModelImplFromJson(json);

  @override
  final String uniqueId;
  @override
  final String name;
  @override
  final SkinRarity rarity;
  @override
  final SkinAssetsModel assetsModel;
  final List<Items> _resistanceToItems;
  @override
  List<Items> get resistanceToItems {
    if (_resistanceToItems is EqualUnmodifiableListView)
      return _resistanceToItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_resistanceToItems);
  }

  @override
  final String? uniqueSkill;

  @override
  String toString() {
    return 'SkinModel(uniqueId: $uniqueId, name: $name, rarity: $rarity, assetsModel: $assetsModel, resistanceToItems: $resistanceToItems, uniqueSkill: $uniqueSkill)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SkinModelImpl &&
            (identical(other.uniqueId, uniqueId) ||
                other.uniqueId == uniqueId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.rarity, rarity) || other.rarity == rarity) &&
            (identical(other.assetsModel, assetsModel) ||
                other.assetsModel == assetsModel) &&
            const DeepCollectionEquality()
                .equals(other._resistanceToItems, _resistanceToItems) &&
            (identical(other.uniqueSkill, uniqueSkill) ||
                other.uniqueSkill == uniqueSkill));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      uniqueId,
      name,
      rarity,
      assetsModel,
      const DeepCollectionEquality().hash(_resistanceToItems),
      uniqueSkill);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SkinModelImplCopyWith<_$SkinModelImpl> get copyWith =>
      __$$SkinModelImplCopyWithImpl<_$SkinModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SkinModelImplToJson(
      this,
    );
  }
}

abstract class _SkinModel extends SkinModel {
  const factory _SkinModel(
      {required final String uniqueId,
      required final String name,
      required final SkinRarity rarity,
      required final SkinAssetsModel assetsModel,
      required final List<Items> resistanceToItems,
      final String? uniqueSkill}) = _$SkinModelImpl;
  const _SkinModel._() : super._();

  factory _SkinModel.fromJson(Map<String, dynamic> json) =
      _$SkinModelImpl.fromJson;

  @override
  String get uniqueId;
  @override
  String get name;
  @override
  SkinRarity get rarity;
  @override
  SkinAssetsModel get assetsModel;
  @override
  List<Items> get resistanceToItems;
  @override
  String? get uniqueSkill;
  @override
  @JsonKey(ignore: true)
  _$$SkinModelImplCopyWith<_$SkinModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SkinAssetsModel _$SkinAssetsModelFromJson(Map<String, dynamic> json) {
  return _SkinAssetsModel.fromJson(json);
}

/// @nodoc
mixin _$SkinAssetsModel {
  bool get url => throw _privateConstructorUsedError;
  String get skinny => throw _privateConstructorUsedError;
  String get slim => throw _privateConstructorUsedError;
  String get fat => throw _privateConstructorUsedError;
  String get superFat => throw _privateConstructorUsedError;
  String get skinnyBite => throw _privateConstructorUsedError;
  String get slimBite => throw _privateConstructorUsedError;
  String get fatBite => throw _privateConstructorUsedError;
  String get superFatBite => throw _privateConstructorUsedError;
  String get dead => throw _privateConstructorUsedError;
  String get mask => throw _privateConstructorUsedError;
  Map<String, List<String>> get sfx => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SkinAssetsModelCopyWith<SkinAssetsModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SkinAssetsModelCopyWith<$Res> {
  factory $SkinAssetsModelCopyWith(
          SkinAssetsModel value, $Res Function(SkinAssetsModel) then) =
      _$SkinAssetsModelCopyWithImpl<$Res, SkinAssetsModel>;
  @useResult
  $Res call(
      {bool url,
      String skinny,
      String slim,
      String fat,
      String superFat,
      String skinnyBite,
      String slimBite,
      String fatBite,
      String superFatBite,
      String dead,
      String mask,
      Map<String, List<String>> sfx});
}

/// @nodoc
class _$SkinAssetsModelCopyWithImpl<$Res, $Val extends SkinAssetsModel>
    implements $SkinAssetsModelCopyWith<$Res> {
  _$SkinAssetsModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? skinny = null,
    Object? slim = null,
    Object? fat = null,
    Object? superFat = null,
    Object? skinnyBite = null,
    Object? slimBite = null,
    Object? fatBite = null,
    Object? superFatBite = null,
    Object? dead = null,
    Object? mask = null,
    Object? sfx = null,
  }) {
    return _then(_value.copyWith(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as bool,
      skinny: null == skinny
          ? _value.skinny
          : skinny // ignore: cast_nullable_to_non_nullable
              as String,
      slim: null == slim
          ? _value.slim
          : slim // ignore: cast_nullable_to_non_nullable
              as String,
      fat: null == fat
          ? _value.fat
          : fat // ignore: cast_nullable_to_non_nullable
              as String,
      superFat: null == superFat
          ? _value.superFat
          : superFat // ignore: cast_nullable_to_non_nullable
              as String,
      skinnyBite: null == skinnyBite
          ? _value.skinnyBite
          : skinnyBite // ignore: cast_nullable_to_non_nullable
              as String,
      slimBite: null == slimBite
          ? _value.slimBite
          : slimBite // ignore: cast_nullable_to_non_nullable
              as String,
      fatBite: null == fatBite
          ? _value.fatBite
          : fatBite // ignore: cast_nullable_to_non_nullable
              as String,
      superFatBite: null == superFatBite
          ? _value.superFatBite
          : superFatBite // ignore: cast_nullable_to_non_nullable
              as String,
      dead: null == dead
          ? _value.dead
          : dead // ignore: cast_nullable_to_non_nullable
              as String,
      mask: null == mask
          ? _value.mask
          : mask // ignore: cast_nullable_to_non_nullable
              as String,
      sfx: null == sfx
          ? _value.sfx
          : sfx // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SkinAssetsModelImplCopyWith<$Res>
    implements $SkinAssetsModelCopyWith<$Res> {
  factory _$$SkinAssetsModelImplCopyWith(_$SkinAssetsModelImpl value,
          $Res Function(_$SkinAssetsModelImpl) then) =
      __$$SkinAssetsModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool url,
      String skinny,
      String slim,
      String fat,
      String superFat,
      String skinnyBite,
      String slimBite,
      String fatBite,
      String superFatBite,
      String dead,
      String mask,
      Map<String, List<String>> sfx});
}

/// @nodoc
class __$$SkinAssetsModelImplCopyWithImpl<$Res>
    extends _$SkinAssetsModelCopyWithImpl<$Res, _$SkinAssetsModelImpl>
    implements _$$SkinAssetsModelImplCopyWith<$Res> {
  __$$SkinAssetsModelImplCopyWithImpl(
      _$SkinAssetsModelImpl _value, $Res Function(_$SkinAssetsModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? skinny = null,
    Object? slim = null,
    Object? fat = null,
    Object? superFat = null,
    Object? skinnyBite = null,
    Object? slimBite = null,
    Object? fatBite = null,
    Object? superFatBite = null,
    Object? dead = null,
    Object? mask = null,
    Object? sfx = null,
  }) {
    return _then(_$SkinAssetsModelImpl(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as bool,
      skinny: null == skinny
          ? _value.skinny
          : skinny // ignore: cast_nullable_to_non_nullable
              as String,
      slim: null == slim
          ? _value.slim
          : slim // ignore: cast_nullable_to_non_nullable
              as String,
      fat: null == fat
          ? _value.fat
          : fat // ignore: cast_nullable_to_non_nullable
              as String,
      superFat: null == superFat
          ? _value.superFat
          : superFat // ignore: cast_nullable_to_non_nullable
              as String,
      skinnyBite: null == skinnyBite
          ? _value.skinnyBite
          : skinnyBite // ignore: cast_nullable_to_non_nullable
              as String,
      slimBite: null == slimBite
          ? _value.slimBite
          : slimBite // ignore: cast_nullable_to_non_nullable
              as String,
      fatBite: null == fatBite
          ? _value.fatBite
          : fatBite // ignore: cast_nullable_to_non_nullable
              as String,
      superFatBite: null == superFatBite
          ? _value.superFatBite
          : superFatBite // ignore: cast_nullable_to_non_nullable
              as String,
      dead: null == dead
          ? _value.dead
          : dead // ignore: cast_nullable_to_non_nullable
              as String,
      mask: null == mask
          ? _value.mask
          : mask // ignore: cast_nullable_to_non_nullable
              as String,
      sfx: null == sfx
          ? _value._sfx
          : sfx // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SkinAssetsModelImpl extends _SkinAssetsModel {
  const _$SkinAssetsModelImpl(
      {required this.url,
      required this.skinny,
      required this.slim,
      required this.fat,
      required this.superFat,
      required this.skinnyBite,
      required this.slimBite,
      required this.fatBite,
      required this.superFatBite,
      required this.dead,
      required this.mask,
      required final Map<String, List<String>> sfx})
      : _sfx = sfx,
        super._();

  factory _$SkinAssetsModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$SkinAssetsModelImplFromJson(json);

  @override
  final bool url;
  @override
  final String skinny;
  @override
  final String slim;
  @override
  final String fat;
  @override
  final String superFat;
  @override
  final String skinnyBite;
  @override
  final String slimBite;
  @override
  final String fatBite;
  @override
  final String superFatBite;
  @override
  final String dead;
  @override
  final String mask;
  final Map<String, List<String>> _sfx;
  @override
  Map<String, List<String>> get sfx {
    if (_sfx is EqualUnmodifiableMapView) return _sfx;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_sfx);
  }

  @override
  String toString() {
    return 'SkinAssetsModel(url: $url, skinny: $skinny, slim: $slim, fat: $fat, superFat: $superFat, skinnyBite: $skinnyBite, slimBite: $slimBite, fatBite: $fatBite, superFatBite: $superFatBite, dead: $dead, mask: $mask, sfx: $sfx)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SkinAssetsModelImpl &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.skinny, skinny) || other.skinny == skinny) &&
            (identical(other.slim, slim) || other.slim == slim) &&
            (identical(other.fat, fat) || other.fat == fat) &&
            (identical(other.superFat, superFat) ||
                other.superFat == superFat) &&
            (identical(other.skinnyBite, skinnyBite) ||
                other.skinnyBite == skinnyBite) &&
            (identical(other.slimBite, slimBite) ||
                other.slimBite == slimBite) &&
            (identical(other.fatBite, fatBite) || other.fatBite == fatBite) &&
            (identical(other.superFatBite, superFatBite) ||
                other.superFatBite == superFatBite) &&
            (identical(other.dead, dead) || other.dead == dead) &&
            (identical(other.mask, mask) || other.mask == mask) &&
            const DeepCollectionEquality().equals(other._sfx, _sfx));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      url,
      skinny,
      slim,
      fat,
      superFat,
      skinnyBite,
      slimBite,
      fatBite,
      superFatBite,
      dead,
      mask,
      const DeepCollectionEquality().hash(_sfx));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SkinAssetsModelImplCopyWith<_$SkinAssetsModelImpl> get copyWith =>
      __$$SkinAssetsModelImplCopyWithImpl<_$SkinAssetsModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SkinAssetsModelImplToJson(
      this,
    );
  }
}

abstract class _SkinAssetsModel extends SkinAssetsModel {
  const factory _SkinAssetsModel(
      {required final bool url,
      required final String skinny,
      required final String slim,
      required final String fat,
      required final String superFat,
      required final String skinnyBite,
      required final String slimBite,
      required final String fatBite,
      required final String superFatBite,
      required final String dead,
      required final String mask,
      required final Map<String, List<String>> sfx}) = _$SkinAssetsModelImpl;
  const _SkinAssetsModel._() : super._();

  factory _SkinAssetsModel.fromJson(Map<String, dynamic> json) =
      _$SkinAssetsModelImpl.fromJson;

  @override
  bool get url;
  @override
  String get skinny;
  @override
  String get slim;
  @override
  String get fat;
  @override
  String get superFat;
  @override
  String get skinnyBite;
  @override
  String get slimBite;
  @override
  String get fatBite;
  @override
  String get superFatBite;
  @override
  String get dead;
  @override
  String get mask;
  @override
  Map<String, List<String>> get sfx;
  @override
  @JsonKey(ignore: true)
  _$$SkinAssetsModelImplCopyWith<_$SkinAssetsModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
