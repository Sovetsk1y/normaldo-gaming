// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CollectPizzaMissionImpl _$$CollectPizzaMissionImplFromJson(
        Map<String, dynamic> json) =>
    _$CollectPizzaMissionImpl(
      exp: json['exp'] as int,
      completeValue: json['completeValue'] as int,
      isOneGame: json['isOneGame'] as bool,
      description: json['description'] as String,
      adsViewed: json['adsViewed'] as int,
      type: $enumDecodeNullable(_$MissionTypeEnumMap, json['type']) ??
          MissionType.collectPizza,
      currentValue: json['currentValue'] as int? ?? 0,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$CollectPizzaMissionImplToJson(
        _$CollectPizzaMissionImpl instance) =>
    <String, dynamic>{
      'exp': instance.exp,
      'completeValue': instance.completeValue,
      'isOneGame': instance.isOneGame,
      'description': instance.description,
      'adsViewed': instance.adsViewed,
      'type': _$MissionTypeEnumMap[instance.type]!,
      'currentValue': instance.currentValue,
      'runtimeType': instance.$type,
    };

const _$MissionTypeEnumMap = {
  MissionType.collectPizza: 'collectPizza',
  MissionType.crashItem: 'crashItem',
  MissionType.passItem: 'passItem',
  MissionType.reachLocation: 'reachLocation',
  MissionType.finishGame: 'finishGame',
};

_$CrashItemMissionImpl _$$CrashItemMissionImplFromJson(
        Map<String, dynamic> json) =>
    _$CrashItemMissionImpl(
      exp: json['exp'] as int,
      completeValue: json['completeValue'] as int,
      isOneGame: json['isOneGame'] as bool,
      description: json['description'] as String,
      adsViewed: json['adsViewed'] as int,
      item: $enumDecode(_$ItemsEnumMap, json['item']),
      type: $enumDecodeNullable(_$MissionTypeEnumMap, json['type']) ??
          MissionType.crashItem,
      currentValue: json['currentValue'] as int? ?? 0,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$CrashItemMissionImplToJson(
        _$CrashItemMissionImpl instance) =>
    <String, dynamic>{
      'exp': instance.exp,
      'completeValue': instance.completeValue,
      'isOneGame': instance.isOneGame,
      'description': instance.description,
      'adsViewed': instance.adsViewed,
      'item': _$ItemsEnumMap[instance.item]!,
      'type': _$MissionTypeEnumMap[instance.type]!,
      'currentValue': instance.currentValue,
      'runtimeType': instance.$type,
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

_$PassItemMissionImpl _$$PassItemMissionImplFromJson(
        Map<String, dynamic> json) =>
    _$PassItemMissionImpl(
      exp: json['exp'] as int,
      completeValue: json['completeValue'] as int,
      isOneGame: json['isOneGame'] as bool,
      description: json['description'] as String,
      adsViewed: json['adsViewed'] as int,
      item: $enumDecode(_$ItemsEnumMap, json['item']),
      type: $enumDecodeNullable(_$MissionTypeEnumMap, json['type']) ??
          MissionType.passItem,
      currentValue: json['currentValue'] as int? ?? 0,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$PassItemMissionImplToJson(
        _$PassItemMissionImpl instance) =>
    <String, dynamic>{
      'exp': instance.exp,
      'completeValue': instance.completeValue,
      'isOneGame': instance.isOneGame,
      'description': instance.description,
      'adsViewed': instance.adsViewed,
      'item': _$ItemsEnumMap[instance.item]!,
      'type': _$MissionTypeEnumMap[instance.type]!,
      'currentValue': instance.currentValue,
      'runtimeType': instance.$type,
    };

_$ReachLocationMissionImpl _$$ReachLocationMissionImplFromJson(
        Map<String, dynamic> json) =>
    _$ReachLocationMissionImpl(
      exp: json['exp'] as int,
      description: json['description'] as String,
      adsViewed: json['adsViewed'] as int,
      completeValue: json['completeValue'] as int,
      isOneGame: json['isOneGame'] as bool? ?? true,
      type: $enumDecodeNullable(_$MissionTypeEnumMap, json['type']) ??
          MissionType.reachLocation,
      currentValue: json['currentValue'] as int? ?? 0,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ReachLocationMissionImplToJson(
        _$ReachLocationMissionImpl instance) =>
    <String, dynamic>{
      'exp': instance.exp,
      'description': instance.description,
      'adsViewed': instance.adsViewed,
      'completeValue': instance.completeValue,
      'isOneGame': instance.isOneGame,
      'type': _$MissionTypeEnumMap[instance.type]!,
      'currentValue': instance.currentValue,
      'runtimeType': instance.$type,
    };

_$FinishGameMissionImpl _$$FinishGameMissionImplFromJson(
        Map<String, dynamic> json) =>
    _$FinishGameMissionImpl(
      exp: json['exp'] as int,
      description: json['description'] as String,
      adsViewed: json['adsViewed'] as int,
      completeValue: json['completeValue'] as int,
      isOneGame: json['isOneGame'] as bool? ?? true,
      type: $enumDecodeNullable(_$MissionTypeEnumMap, json['type']) ??
          MissionType.finishGame,
      currentValue: json['currentValue'] as int? ?? 0,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$FinishGameMissionImplToJson(
        _$FinishGameMissionImpl instance) =>
    <String, dynamic>{
      'exp': instance.exp,
      'description': instance.description,
      'adsViewed': instance.adsViewed,
      'completeValue': instance.completeValue,
      'isOneGame': instance.isOneGame,
      'type': _$MissionTypeEnumMap[instance.type]!,
      'currentValue': instance.currentValue,
      'runtimeType': instance.$type,
    };
