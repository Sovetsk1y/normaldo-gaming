import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:normaldo_gaming/domain/shop/entities/shop_item.dart';
import 'package:normaldo_gaming/domain/shop/shop_repository.dart';

part 'shop_items_list_state.dart';
part 'shop_items_list_cubit.freezed.dart';

class ShopItemsListCubit extends Cubit<ShopItemsListState> {
  ShopItemsListCubit(this._shopRepository)
      : super(const ShopItemsListState.initial());

  final ShopRepository _shopRepository;

  Future<void> loadList() async {
    emit(const ShopItemsListState.loading());
    try {
      final items = await _shopRepository.getRelevantItems();
      emit(ShopItemsListState.success(items: items));
    } on ShopException catch (e) {
      emit(ShopItemsListState.failed(error: e));
    }
  }
}
