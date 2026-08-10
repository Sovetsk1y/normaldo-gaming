import 'package:normaldo_gaming/domain/shop/entities/shop_item.dart';

abstract interface class ShopRepository {
  Future<List<ShopItem>> getRelevantItems();
}

sealed class ShopException implements Exception {}

final class ShopUnknown extends ShopException {
  ShopUnknown([this.description]);

  final String? description;
}
