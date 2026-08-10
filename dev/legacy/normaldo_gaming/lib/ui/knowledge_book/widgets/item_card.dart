import 'package:flutter/material.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';

class ItemCard extends StatelessWidget {
  final Items item;
  final bool isGud;
  final bool selected;

  const ItemCard({
    super.key,
    required this.item,
    required this.isGud,
    required this.selected,
  });

  Color get color => isGud ? NGTheme.green1 : NGTheme.auraRed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? color : Colors.black,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(width: 4, color: color),
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 7,
            spreadRadius: 0.3,
          )
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Image.asset(Utils.itemImagePath(item)),
    );
  }
}
