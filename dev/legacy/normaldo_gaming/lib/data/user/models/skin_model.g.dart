// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skin_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SkinModelImpl _$$SkinModelImplFromJson(Map<String, dynamic> json) =>
    _$SkinModelImpl(
      uniqueId: json['uniqueId'] as String,
      name: json['name'] as String,
      rarity: $enumDecode(_$SkinRarityEnumMap, json['rarity']),
      assetsModel:
          SkinAssetsModel.fromJson(json['assetsModel'] as Map<String, dynamic>),
      resistanceToItems: (json['resistanceToItems'] as List<dynamic>)
          .map((e) => $enumDecode(_$ItemsEnumMap, e))
          .toList(),
      uniqueSkill: json['uniqueSkill'] as String?,
    );

Map<String, dynamic> _$$SkinModelImplToJson(_$SkinModelImpl instance) =>
    <String, dynamic>{
      'uniqueId': instance.uniqueId,
      'name': instance.name,
      'rarity': _$SkinRarityEnumMap[instance.rarity]!,
      'assetsModel': instance.assetsModel,
      'resistanceToItems':
          instance.resistanceToItems.map((e) => _$ItemsEnumMap[e]!).toList(),
      'uniqueSkill': instance.uniqueSkill,
    };

const _$SkinRarityEnumMap = {
  SkinRarity.classic: 'classic',
  SkinRarity.common: 'common',
  SkinRarity.rare: 'rare',
  SkinRarity.epic: 'epic',
  SkinRarity.legendary: 'legendary',
};

const _$ItemsEnumMap = {
  Items.trashBin: 'trashBin',
  Items.pizza: 'pizza',
  Items.dollar: 'dollar',
  Items.fatPizza: 'fatPizza',
  Items.homeless: 'homeless',
  Items.moneyBag: 'moneyBag',
  Items.boombox: 'boombox',
  Items.cocktail: 'cocktail',
  Items.molotov: 'molotov',
  Items.hourglass: 'hourglass',
  Items.punch: 'punch',
  Items.hugeItem: 'hugeItem',
  Items.allIn: 'allIn',
  Items.angryDog: 'angryDog',
  Items.bananaPeel: 'bananaPeel',
  Items.beer: 'beer',
  Items.cannibal: 'cannibal',
  Items.casinoChip: 'casinoChip',
  Items.greenPoison: 'greenPoison',
  Items.compass: 'compass',
  Items.energizer: 'energizer',
  Items.bird: 'bird',
  Items.snake: 'snake',
  Items.policeAlarm: 'policeAlarm',
  Items.gun: 'gun',
  Items.bubbles: 'bubbles',
  Items.girl: 'girl',
  Items.goldClocks: 'goldClocks',
  Items.handcuffs: 'handcuffs',
  Items.caseyMask: 'caseyMask',
  Items.loserTicket: 'loserTicket',
  Items.magicHat: 'magicHat',
  Items.magicBox: 'magicBox',
  Items.magnet: 'magnet',
  Items.note: 'note',
  Items.note2: 'note2',
  Items.phone: 'phone',
  Items.spadesCard: 'spadesCard',
  Items.policeman: 'policeman',
  Items.security: 'security',
  Items.shipPart: 'shipPart',
  Items.cone: 'cone',
  Items.stone: 'stone',
  Items.letterBottle: 'letterBottle',
  Items.roadSign: 'roadSign',
  Items.umbrella: 'umbrella',
  Items.mutagen: 'mutagen',
  Items.tv: 'tv',
  Items.tire: 'tire',
  Items.bullet: 'bullet',
  Items.policeCar: 'policeCar',
  Items.shredder: 'shredder',
  Items.shuriken: 'shuriken',
  Items.shredderSword: 'shredderSword',
  Items.smoke: 'smoke',
};

_$SkinAssetsModelImpl _$$SkinAssetsModelImplFromJson(
        Map<String, dynamic> json) =>
    _$SkinAssetsModelImpl(
      url: json['url'] as bool,
      skinny: json['skinny'] as String,
      slim: json['slim'] as String,
      fat: json['fat'] as String,
      superFat: json['superFat'] as String,
      skinnyBite: json['skinnyBite'] as String,
      slimBite: json['slimBite'] as String,
      fatBite: json['fatBite'] as String,
      superFatBite: json['superFatBite'] as String,
      dead: json['dead'] as String,
      mask: json['mask'] as String,
      sfx: (json['sfx'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
    );

Map<String, dynamic> _$$SkinAssetsModelImplToJson(
        _$SkinAssetsModelImpl instance) =>
    <String, dynamic>{
      'url': instance.url,
      'skinny': instance.skinny,
      'slim': instance.slim,
      'fat': instance.fat,
      'superFat': instance.superFat,
      'skinnyBite': instance.skinnyBite,
      'slimBite': instance.slimBite,
      'fatBite': instance.fatBite,
      'superFatBite': instance.superFatBite,
      'dead': instance.dead,
      'mask': instance.mask,
      'sfx': instance.sfx,
    };
