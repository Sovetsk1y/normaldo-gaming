import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/domain/shop/entities/shop_item.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';
import 'package:normaldo_gaming/ui/widgets/bouncing_button.dart';

class ShopItemCard extends StatelessWidget {
  const ShopItemCard({
    required this.item,
    required this.onPressed,
    super.key,
  });

  final ShopItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (item is DollarForAdItem) {
      return _DollarAdForItemCard(
        item: item as DollarForAdItem,
        onPressed: onPressed,
      );
    }
    throw UnexpectedError();
  }
}

class _DollarAdForItemCard extends StatelessWidget {
  const _DollarAdForItemCard({
    required this.item,
    required this.onPressed,
    super.key,
  });

  final DollarForAdItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BouncingButton(
      onPressed: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: NGTheme.colorOf(SkinRarity.classic),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ],
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(width: 5, color: NGTheme.colorOf(SkinRarity.classic)),
        ),
        height: 200,
        width: 200,
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.asset(item.imagePath),
              ),
            ),
            Expanded(
                child: Text(item.title.tr(),
                    style:
                        textTheme.titleLarge?.copyWith(color: Colors.white))),
          ],
        ),
      ),
    );
  }
}
