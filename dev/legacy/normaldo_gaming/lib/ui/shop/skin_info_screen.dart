import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/knowledge/knowledge_repository.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';
import 'package:normaldo_gaming/injection/injection.dart';
import 'package:normaldo_gaming/routing/ng_router.dart';
import 'package:normaldo_gaming/ui/knowledge_book/widgets/detailed_item_card.dart';
import 'package:normaldo_gaming/ui/widgets/bouncing_button.dart';
import 'package:normaldo_gaming/ui/widgets/ng_button.dart';

class SkinInfoScreen extends StatefulWidget {
  final Skin skin;
  final bool fromShop;

  const SkinInfoScreen({
    super.key,
    required this.skin,
    this.fromShop = false,
  });

  @override
  State<SkinInfoScreen> createState() => _SkinInfoScreenState();
}

class _SkinInfoScreenState extends State<SkinInfoScreen> {
  final _resistScrollController = ScrollController();
  final _itemsRepo = injector.get<KnowledgeRepository>();

  bool userHasSkin(BuildContext context) => context
      .read<UserCubit>()
      .state
      .user
      .mySkins
      .where((skin) => skin.uniqueId == widget.skin.uniqueId)
      .isNotEmpty;

  bool userCanBuy(BuildContext context) =>
      context.read<UserCubit>().state.user.dollars >= widget.skin.price;

  TextStyle? get infoHeaderStyle {
    final textTheme = Theme.of(context).textTheme;
    return textTheme.displayMedium?.copyWith(backgroundColor: NGTheme.purple2);
  }

  void _buySkin() {
    if (userCanBuy(context)) {
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
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      Future.delayed(const Duration(milliseconds: 300))
          .whenComplete(() => _resistScrollController.animateTo(
                _resistScrollController.position.maxScrollExtent,
                duration: const Duration(seconds: 10),
                curve: Curves.linear,
              ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: SafeArea(
                  child: BouncingButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      '< back',
                      style: textTheme.displaySmall,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                      child: Column(
                    children: [
                      Expanded(child: _buildCard()),
                      Expanded(child: _buildBaseInfo(context)),
                    ],
                  )),
                  Expanded(
                    flex: 2,
                    child: _buildInfo(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _buildFats(),
        ),
        const SizedBox(height: 16),
        if (widget.skin.resistanceToItems.isNotEmpty)
          Expanded(
            flex: 2,
            child: _buildResist(),
          ),
        const SizedBox(height: 16),
        if (widget.skin.uniqueSkill != null)
          Expanded(
            flex: 2,
            child: _buildUniqueSkill(),
          ),
      ],
    );
  }

  Widget _buildUniqueSkill() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(' ${'Unique'.tr()}', style: infoHeaderStyle),
        const SizedBox(height: 16),
        Expanded(
            child: Text(
          widget.skin.uniqueSkill?.tr() ?? '',
          style: textTheme.displayMedium,
        )),
      ],
    );
  }

  Widget _buildResist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(' ${'Resist'.tr()}', style: infoHeaderStyle),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            controller: _resistScrollController,
            scrollDirection: Axis.horizontal,
            children:
                List.generate(widget.skin.resistanceToItems.length, (index) {
              final item = widget.skin.resistanceToItems[index];
              return GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  barrierColor: Colors.black54,
                  builder: (context) => Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width / 3),
                      child: DetailedItemCard(
                        item: _itemsRepo.descriptionOf(item),
                      ),
                    ),
                  ),
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 100),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Image.asset(Utils.itemImagePath(item)),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildFats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(' ${'Fats'.tr()}', style: infoHeaderStyle),
        const SizedBox(height: 8),
        Flexible(
          child: Row(
            children: List.generate(
                4,
                (index) => Expanded(
                      child: FatPresenter(
                        skin: widget.skin,
                        fatIndex: index,
                      ),
                    )),
          ),
        ),
      ],
    );
  }

  Widget _buildBaseInfo(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.skin.name.tr(),
            style: NGTheme.displaySmall.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            Utils.rarityTitleOf(widget.skin),
            textAlign: TextAlign.center,
            style: NGTheme.rareSkinStyle
                .copyWith(color: NGTheme.colorOf(widget.skin.rarity)),
          ),
        ),
        if (userHasSkin(context))
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
        else if (widget.fromShop)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: NGButton(
              text: '${widget.skin.price}\$',
              onPressed: _buySkin,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: NGButton(
              text: '${'toShop'.tr()} >>',
              onPressed: () => context.go(NGRoutes.shop.path),
            ),
          ),
      ],
    );
  }

  Widget _buildCard() {
    return Hero(
      tag: widget.skin.uniqueId,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.all(24),
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
          child: Stack(
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
              Image.asset(Utils.maskImagePath(widget.skin.uniqueId)),
            ],
          ),
        ),
      ),
    );
  }
}

class FatPresenter extends StatefulWidget {
  final Skin skin;
  final int fatIndex;

  const FatPresenter({
    super.key,
    required this.skin,
    required this.fatIndex,
  });

  @override
  State<FatPresenter> createState() => _FatPresenterState();
}

class _FatPresenterState extends State<FatPresenter> with HasNgAudio {
  bool _animating = false;

  void _onTap() {
    if (_animating) return;
    setState(() {
      _animating = true;
    });
    final biteSound = widget.skin.assets.sfx['bite'] ?? '/sfx/havaet.mp3';
    audio.playAssetSfx(
      biteSound is List
          ? Utils.skinSfxWrapper(biteSound[Random().nextInt(biteSound.length)])
          : biteSound as String,
    );
    Future.delayed(const Duration(milliseconds: 300)).whenComplete(() {
      setState(() {
        _animating = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: _animating
          ? Image.asset(
              'assets/images/${widget.skin.assets.fatBiteFromIndex(widget.fatIndex)}')
          : Image.asset(
              'assets/images/${widget.skin.assets.fatFromIndex(widget.fatIndex)}'),
    );
  }
}
