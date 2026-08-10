import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:normaldo_gaming/domain/knowledge/item_description.dart';
import 'package:normaldo_gaming/domain/knowledge/knowledge_repository.dart';

import 'package:normaldo_gaming/injection/injection.dart';
import 'package:normaldo_gaming/ui/knowledge_book/widgets/detailed_item_card.dart';
import 'package:normaldo_gaming/ui/knowledge_book/widgets/item_card.dart';

import 'package:normaldo_gaming/ui/knowledge_book/widgets/type_picker.dart';
import 'package:normaldo_gaming/ui/widgets/bouncing_button.dart';
import 'package:normaldo_gaming/ui/widgets/liner_button.dart';

class KnowledgeBookScreen extends StatefulWidget {
  const KnowledgeBookScreen({super.key});

  @override
  State<KnowledgeBookScreen> createState() => _KnowledgeBookScreenState();
}

class _KnowledgeBookScreenState extends State<KnowledgeBookScreen> {
  Types _type = Types.good;

  final _repository = injector.get<KnowledgeRepository>();

  ItemDescription? _pickedItem;

  List<ItemDescription> get gudItems =>
      _repository.itemDescriptions.where((element) => element.isGood).toList();
  List<ItemDescription> get badItems =>
      _repository.itemDescriptions.where((element) => !element.isGood).toList();

  @override
  void initState() {
    if (gudItems.isNotEmpty) {
      _pickedItem = gudItems.first;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(context),
            const SizedBox(height: 12),
            _buildItemsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    final items = _type == Types.good ? gudItems : badItems;
    if (_pickedItem == null) {
      return Expanded(
        child: _buildGrid(items: items, crossAxisCount: 8),
      );
    } else {
      return Expanded(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildGrid(items: items, crossAxisCount: 5),
            ),
            const SizedBox(width: 32),
            Expanded(
              flex: 2,
              child: DetailedItemCard(
                key: ObjectKey(_pickedItem),
                item: _pickedItem!,
              ),
            ),
          ],
        ),
      );
    }
  }

  GridView _buildGrid({
    required List<ItemDescription> items,
    required int crossAxisCount,
  }) {
    return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return BouncingButton(
            onPressed: () {
              setState(() => _pickedItem = item);
            },
            child: ItemCard(
              isGud: _type == Types.good,
              item: item.item,
              selected: _pickedItem == item,
            ),
          );
        });
  }

  Row _buildAppBar(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              LinerButton(
                side: LinerSide.top,
                onPressed: () => context.pop(),
                child: Text('<', style: textTheme.displayLarge),
              ),
            ],
          ),
        ),
        Column(
          children: [
            // const SizedBox(height: 8),
            // Text(
            //   'Book of Knowledge'.tr(),
            //   style: textTheme.displayLarge,
            // ),
            // const SizedBox(height: 8),
            TypePicker(
              onChanged: (type) {
                setState(() {
                  if (_type != type) {
                    _pickedItem = null;
                  }
                  _type = type;
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}
