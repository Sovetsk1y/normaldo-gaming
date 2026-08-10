import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/application/ads/ads_cubit.dart';
import 'package:normaldo_gaming/application/shop_items_list/shop_items_list_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/domain/shop/entities/shop_item.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';
import 'package:normaldo_gaming/domain/user/entities/user.dart';
import 'package:normaldo_gaming/ui/ads_widget/ads_widget.dart';
import 'package:normaldo_gaming/ui/shop/widgets/shop_skin_card.dart';
import 'package:normaldo_gaming/ui/widgets/bouncing_button.dart';

import 'widgets/shop_item_card.dart';

class ShopScreen extends StatefulWidget {
  final SkinsRepository skinsRepository;

  const ShopScreen(this.skinsRepository, {super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _scrollController = ScrollController();

  User get user => context.read<UserCubit>().state.user;

  Future<void> _onItemPressed(BuildContext context, ShopItem item) async {
    if (item is DollarForAdItem) {
      final cubit = context.read<AdsCubit>();
      cubit.showAd(
        type: AdType.rewarded,
        reward: const AdReward.bucks(30),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      Future.delayed(const Duration(milliseconds: 300))
          .whenComplete(() => _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(seconds: 30),
                curve: Curves.linear,
              ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AdsWidget(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          automaticallyImplyLeading: false,
          title: BlocBuilder<UserCubit, UserState>(builder: (context, state) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 32),
                BouncingButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    '< back',
                    style: textTheme.displaySmall,
                  ),
                ),
                const SizedBox(width: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/dollar.png', height: 30),
                    const SizedBox(width: 8),
                    Text(
                      state.user.dollars.toString(),
                      style: textTheme.displayLarge,
                    ),
                  ],
                ),
                const Spacer(flex: 2),
                Text('shop'.tr(), style: textTheme.displayLarge),
                const Spacer(),
              ],
            );
          }),
        ),
        backgroundColor: Colors.black,
        body: BlocBuilder<ShopItemsListCubit, ShopItemsListState>(
          builder: (context, state) {
            return state.when(
              initial: () => const SizedBox.shrink(),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              failed: (error) => Center(
                child: Column(
                  children: [
                    BouncingButton(
                        onPressed: () =>
                            context.read<ShopItemsListCubit>().loadList(),
                        child: const Icon(
                          Icons.replay,
                          size: 32,
                          color: Colors.white,
                        )),
                    const SizedBox(height: 8),
                    Text(
                      'Loading error'.tr(),
                      style: textTheme.displayMedium,
                    ),
                    const SizedBox(height: 4),
                    if (error != null)
                      Text(
                        error.toString(),
                        style: textTheme.displaySmall,
                      )
                  ],
                ),
              ),
              success: (items) => SafeArea(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      Text('- TV -',
                          style:
                              textTheme.displayLarge?.copyWith(fontSize: 40)),
                      const SizedBox(height: 16),
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        itemCount: items.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 4 / 3,
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ShopItemCard(
                            item: item,
                            onPressed: () => _onItemPressed(context, item),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      Text('- ${'SKINS'.tr()} -',
                          style:
                              textTheme.displayLarge?.copyWith(fontSize: 40)),
                      const SizedBox(height: 16),
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: widget.skinsRepository.skinsData.length - 1,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 32,
                        ),
                        itemBuilder: (context, index) {
                          final skin =
                              widget.skinsRepository.skinsData[index + 1];
                          return ShopSkinCard(skin: skin);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
