import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/domain/knowledge/item_description.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';

class DetailedItemCard extends StatelessWidget {
  final ItemDescription item;

  const DetailedItemCard({
    super.key,
    required this.item,
  });

  Color get color => item.isGood ? NGTheme.green1 : NGTheme.auraRed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
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
      child: Column(
        children: [
          Expanded(
            child: Image.asset(Utils.itemImagePath(item.item)),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(item.item.name.tr(), style: textTheme.displayMedium),
                  const SizedBox(height: 16),
                  if (item.damage > 0)
                    Row(
                      children: [
                        Text(
                          '${'Damage'.tr()}:',
                          style: textTheme.bodyMedium
                              ?.copyWith(color: NGTheme.auraRed),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.damage.toString(),
                          style: textTheme.bodySmall,
                        )
                      ],
                    ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'Located'.tr()}:',
                        style: textTheme.titleSmall
                            ?.copyWith(color: NGTheme.purple2),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.locations.fold(
                              '',
                              (previousValue, element) =>
                                  '${previousValue.isEmpty ? '' : '${previousValue.tr()},'} ${element.tr()}'),
                          style: textTheme.bodySmall,
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (item.skills.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${'Effects'.tr()}:',
                          style: textTheme.titleSmall
                              ?.copyWith(color: NGTheme.purple2),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${item.item.name}Skill'.tr(),
                            style: textTheme.bodySmall,
                          ),
                        )
                      ],
                    ),
                  const SizedBox(height: 4),
                  if (item.gives.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${'Gives'.tr()}:',
                          style: textTheme.titleSmall
                              ?.copyWith(color: NGTheme.green1),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.gives.fold(
                                '',
                                (previousValue, element) =>
                                    '${previousValue.tr()} ${element.tr()}'),
                            style: textTheme.bodySmall,
                          ),
                        )
                      ],
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.description.tr(),
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
