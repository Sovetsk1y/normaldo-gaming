import 'package:normaldo_gaming/data/user/models/skin_model.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';
import 'package:normaldo_gaming/domain/user/entities/user.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';

final class UserModel {
  final String id;
  final String name;
  final int dollars;
  final int highScore;
  final int level;
  final int exp;
  final int extraLives;
  final int totalPizzas;
  final List<Skin> mySkins;

  UserModel({
    required this.id,
    required this.name,
    required this.dollars,
    required this.highScore,
    required this.level,
    required this.exp,
    required this.extraLives,
    required this.totalPizzas,
    required this.mySkins,
  });

  UserModel.fromEntity(User user)
      : id = user.id,
        name = user.name,
        dollars = user.dollars,
        highScore = user.highScore,
        level = user.level,
        exp = user.exp,
        extraLives = user.extraLives,
        totalPizzas = user.totalPizzas,
        mySkins = user.mySkins;

  User toEntity() {
    return User(
      id: id,
      name: name,
      highScore: highScore,
      dollars: dollars,
      level: level,
      exp: exp,
      extraLives: extraLives,
      totalPizzas: totalPizzas,
      mySkins: mySkins..sort((a, b) => Utils.compareSkinByRarity(a, b)),
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        name: json['name'],
        dollars: json['dollars'],
        highScore: json['highScore'],
        level: json['level'],
        exp: json['exp'],
        extraLives: json['extraLives'],
        totalPizzas: json['totalPizzas'],
        mySkins: (json['mySkins'] as List)
            .map((e) => SkinModel.fromJson(e).toEntity())
            .toList(),
      );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dollars': dollars,
      'highScore': highScore,
      'level': level,
      'exp': exp,
      'extraLives': extraLives,
      'totalPizzas': totalPizzas,
      'mySkins':
          mySkins.map((skin) => SkinModel.fromEntity(skin).toJson()).toList(),
    };
  }

  UserModel copyWith({
    String? name,
    int? dollars,
    int? highScore,
    int? level,
    int? exp,
    int? extraLives,
    int? totalPizzas,
    List<Skin>? mySkins,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        dollars: dollars ?? this.dollars,
        highScore: highScore ?? this.highScore,
        level: level ?? this.level,
        exp: exp ?? this.exp,
        extraLives: extraLives ?? this.extraLives,
        totalPizzas: totalPizzas ?? this.totalPizzas,
        mySkins: mySkins ?? this.mySkins,
      );
}
