import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';

part 'skin_model.freezed.dart';
part 'skin_model.g.dart';

@freezed
class SkinModel with _$SkinModel {
  const SkinModel._();

  const factory SkinModel({
    required String uniqueId,
    required String name,
    required SkinRarity rarity,
    required SkinAssetsModel assetsModel,
    required List<Items> resistanceToItems,
    String? uniqueSkill,
  }) = _SkinModel;

  Skin toEntity() => Skin(
        uniqueId: uniqueId,
        name: name,
        rarity: rarity,
        assets: assetsModel.toEntity(),
        resistanceToItems: resistanceToItems,
        uniqueSkill: uniqueSkill,
      );

  factory SkinModel.fromEntity(Skin skin) => SkinModel(
        uniqueId: skin.uniqueId,
        name: skin.name,
        rarity: skin.rarity,
        assetsModel: SkinAssetsModel.fromEntity(skin.assets),
        resistanceToItems: skin.resistanceToItems,
        uniqueSkill: skin.uniqueSkill,
      );

  factory SkinModel.fromJson(Map<String, dynamic> json) =>
      _$SkinModelFromJson(json);
}

@freezed
class SkinAssetsModel with _$SkinAssetsModel {
  const SkinAssetsModel._();

  const factory SkinAssetsModel({
    required bool url,
    required String skinny,
    required String slim,
    required String fat,
    required String superFat,
    required String skinnyBite,
    required String slimBite,
    required String fatBite,
    required String superFatBite,
    required String dead,
    required String mask,
    required Map<String, List<String>> sfx,
  }) = _SkinAssetsModel;

  SkinAssets toEntity() => SkinAssets(
        skinny: skinny,
        slim: slim,
        fat: fat,
        superFat: superFat,
        skinnyBite: skinnyBite,
        slimBite: slimBite,
        fatBite: fatBite,
        superFatBite: superFatBite,
        dead: dead,
        mask: mask,
        sfx: sfx,
      );

  factory SkinAssetsModel.fromEntity(SkinAssets assets) => SkinAssetsModel(
        url: assets.url,
        skinny: assets.skinny,
        slim: assets.slim,
        fat: assets.fat,
        superFat: assets.superFat,
        skinnyBite: assets.skinnyBite,
        slimBite: assets.slimBite,
        fatBite: assets.fatBite,
        superFatBite: assets.superFatBite,
        dead: assets.dead,
        mask: assets.mask,
        sfx: assets.sfx,
      );

  factory SkinAssetsModel.fromJson(Map<String, dynamic> json) =>
      _$SkinAssetsModelFromJson(json);
}
