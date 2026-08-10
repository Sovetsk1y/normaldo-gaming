import 'package:normaldo_gaming/domain/shop/entities/shop_item.dart';
import 'package:normaldo_gaming/domain/shop/shop_repository.dart';

final class ShopRepositoryImpl implements ShopRepository {
  @override
  Future<List<ShopItem>> getRelevantItems() async {
    return [DollarForAdItem()];
  }
}
