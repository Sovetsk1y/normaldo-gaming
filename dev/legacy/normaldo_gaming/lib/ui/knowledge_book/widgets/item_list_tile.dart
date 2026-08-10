import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';

extension on Items {
  String get fullPath => switch (this) {
        Items.trashBin => 'assets/images/trash_bin.png',
        Items.pizza => 'assets/images/pizza.png',
        Items.dollar => 'assets/images/dollar.png',
        Items.fatPizza => 'assets/images/pizza_pack1.png',
        Items.homeless => 'assets/images/homeless1.png',
        Items.moneyBag => 'assets/images/money_bag.png',
        Items.boombox => 'assets/images/boombox1.png',
        Items.cocktail => 'assets/images/cocktail.png',
        Items.molotov => 'assets/images/molotov1.png',
        Items.hourglass => 'assets/images/hourglass.png',
        Items.punch => 'assets/images/punch.png',
        Items.shredder => 'assets/images/shredder.png',
        Items.shuriken => 'assets/images/shuriken.png',
        _ => throw UnexpectedError(),
      };

  String get description => switch (this) {
        Items.trashBin =>
          '''a crumpled bin filled with a pile of garbage, perhaps the most negative item in this story, because you will encounter it until you reach the GAME OVER point. Masters of quick reactions, welcome aboard! And to those who are just starting their journey, don't worry, everything will be NORMALDO!''',
        Items.cocktail =>
          '''like any rooftop-hitting beverage, the cocktail complicates Normaldo's flight, making his movement more challenging. Be careful to avoid collisions with obstacles!''',
        Items.homeless =>
          '''individuals constantly try to distract NORMALDO from his main mission — eating all the pizza! Beware of these cunning characters and don't let them throw you off track at the most crucial moments.''',
        Items.molotov =>
          '''an item with unpredictable behavior. Dodge at high speed, otherwise, this tricky item can confuse even the most experienced NORMALDOSOs!''',
        Items.shuriken =>
          '''this cunning weapon is often used to distract attention for a more serious attack! Be careful! Only lightning-fast reactions will help you; the main thing is not to stand still, and then everything will be NORMALDO!''',
        Items.punch =>
          '''always stay on alert! Dangers lurk in the dark alleys of the city. But NORMALDO will always find a way to squeeze through with his chubby self! The glove shoots out at lightning speed - we advise not to relax.''',
        _ =>
          'Sed ut perspiciatis, unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam eaque ipsa, quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt, explicabo',
      };
}

class ItemListTile extends StatelessWidget {
  const ItemListTile({
    super.key,
    required this.item,
  });

  final Items item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      leading: Image.asset(
        item.fullPath,
        width: 80,
        height: 80,
      ),
      title: Text(item.name.tr(), style: textTheme.displayLarge),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          item.description.tr(),
          style: textTheme.displaySmall,
        ),
      ),
    );
  }
}
