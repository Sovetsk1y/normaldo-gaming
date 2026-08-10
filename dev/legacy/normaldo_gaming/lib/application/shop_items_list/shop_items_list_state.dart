part of 'shop_items_list_cubit.dart';

@freezed
class ShopItemsListState with _$ShopItemsListState {
  const factory ShopItemsListState.initial() = _Initial;
  const factory ShopItemsListState.loading() = _Loading;
  const factory ShopItemsListState.failed({ShopException? error}) = _Failed;
  const factory ShopItemsListState.success({
    required List<ShopItem> items,
  }) = _Success;
}
