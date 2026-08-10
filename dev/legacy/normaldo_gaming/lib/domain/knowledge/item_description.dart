import 'package:normaldo_gaming/domain/pull_up_game/items.dart';

final class ItemDescription {
  final Items item;
  final String description;
  final bool isGood;
  final int damage;
  final List<String> locations;
  final List<String> skills;
  final List<String> gives;

  ItemDescription({
    required this.item,
    required this.description,
    required this.isGood,
    required this.damage,
    required this.locations,
    required this.skills,
    required this.gives,
  });
}
