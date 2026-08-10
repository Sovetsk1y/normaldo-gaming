import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';
import 'package:normaldo_gaming/ui/shop/skin_info_screen.dart';
import 'package:normaldo_gaming/ui/widgets/ng_button.dart';

class ShopSkinCard extends StatefulWidget {
  final Skin skin;
  final bool fromShop;

  const ShopSkinCard({
    super.key,
    required this.skin,
    this.fromShop = true,
  });

  @override
  State<ShopSkinCard> createState() => _ShopSkinCardState();
}

class _ShopSkinCardState extends State<ShopSkinCard> {
  bool get userHasSkin => context
      .read<UserCubit>()
      .state
      .user
      .mySkins
      .where((skin) => skin.uniqueId == widget.skin.uniqueId)
      .isNotEmpty;

  bool get userCanBuy =>
      context.read<UserCubit>().state.user.dollars >= widget.skin.price;

  void _buySkin() {
    if (userCanBuy) {
      setState(() {
        context.read<UserCubit>().buySkin(widget.skin.uniqueId);
      });
    } else {
      final textTheme = Theme.of(context).textTheme;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          margin: const EdgeInsets.all(16),
          behavior: SnackBarBehavior.floating,
          backgroundColor: NGTheme.purple2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          content: Text(
            'notEnoughFunds'.tr(),
            style: textTheme.displayMedium,
          )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.black87,
              pageBuilder: (context, animation, secondaryAnimation) =>
                  FadeTransition(
                opacity: animation,
                child: SkinInfoScreen(skin: widget.skin, fromShop: true),
              ),
            )),
            child: Hero(
              tag: widget.skin.uniqueId,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: NGTheme.colorOf(widget.skin.rarity),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      width: 5, color: NGTheme.colorOf(widget.skin.rarity)),
                ),
                height: 200,
                width: 200,
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            radius: 0.5,
                            colors: [
                              NGTheme.colorOf(widget.skin.rarity),
                              Colors.transparent,
                            ],
                          )),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4)
                              .add(EdgeInsets.only(
                                  top:
                                      widget.skin.rarity == SkinRarity.legendary
                                          ? 4
                                          : 0)),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              Utils.rarityTitleOf(widget.skin),
                              textAlign: TextAlign.center,
                              style: NGTheme.rareSkinStyle.copyWith(
                                  color: NGTheme.colorOf(widget.skin.rarity)),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Image.asset(
                            'assets/images/${widget.skin.assets.mask}',
                            fit: BoxFit.cover,
                          ),
                        ),
                        const Spacer(),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8, right: 8),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.skin.name.tr(),
                                style: NGTheme.displaySmall
                                    .copyWith(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (userHasSkin && widget.fromShop)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'BOUGHT'.tr(),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: NGTheme.green3,
                    ),
              ),
            ),
          )
        else if (!userHasSkin && widget.fromShop)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: NGButton(
              text: '${widget.skin.price}\$',
              onPressed: _buySkin,
            ),
          ),
      ],
    );
  }
}
