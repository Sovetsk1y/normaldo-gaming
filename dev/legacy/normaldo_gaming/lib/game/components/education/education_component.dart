import 'dart:async';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/application/education/cubit/education_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/item_components/banana_peel.dart';
import 'package:normaldo_gaming/game/components/item_components/cone.dart';
import 'package:normaldo_gaming/game/components/item_components/dollar.dart';
import 'package:normaldo_gaming/game/components/item_components/energizer.dart';
import 'package:normaldo_gaming/game/components/item_components/girl.dart';
import 'package:normaldo_gaming/game/components/item_components/hourglass.dart';
import 'package:normaldo_gaming/game/components/item_components/magic_hat.dart';
import 'package:normaldo_gaming/game/components/item_components/pizza.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

class EducationComponent extends Component with HasGameRef<PullUpGame> {
  EducationCubit get cubit => gameRef.educationCubit;
  UserCubit get userCubit => gameRef.userCubit;
  double get lineSize => gameRef.grid.lineSize;
  Grid get grid => gameRef.grid;

  final _rnd = Random();

  final _effectItems = <Item>[
    BananaPeel(),
    Energizer(),
    Hourglass(),
    MagicHat(),
    Girl(),
    BananaPeel(),
    BananaPeel(),
    BananaPeel(),
    BananaPeel(),
  ];

  @override
  FutureOr<void> onLoad() {
    cubit.showMessage(
        text: 'text1'.tr(),
        ignorePointer: true,
        onTypeWritingFinished: () {
          cubit.hideMessage();
          cubit.showMessage(
              text: 'text2'.tr(),
              ignorePointer: false,
              onTypeWritingFinished: () {
                if (gameRef.findByKey<TimerComponent>(
                        ComponentKey.named('timer1')) ==
                    null) {
                  add(TimerComponent(
                      period: 1,
                      removeOnFinish: true,
                      repeat: true,
                      key: ComponentKey.named('timer1'),
                      onTick: () {
                        if (gameRef.grid.normaldo.position !=
                            gameRef.grid.center) {
                          final thisTimer = gameRef.findByKey<TimerComponent>(
                              ComponentKey.named('timer1'));
                          thisTimer?.timer.stop();
                          cubit.hideMessage();
                          cubit.showMessage(
                            text: 'text3'.tr(),
                            ignorePointer: false,
                            onTypeWritingFinished: () {
                              grid.addAll([
                                Pizza()
                                  ..size = Items.pizza.getSize(lineSize)
                                  ..position = Vector2(gameRef.size.x + 100,
                                      grid.linesCentersY[1]),
                                Dollar()
                                  ..size = Items.dollar.getSize(lineSize)
                                  ..position = Vector2(gameRef.size.x + 100,
                                      grid.linesCentersY[2]),
                              ]);
                              if (gameRef.findByKey<TimerComponent>(
                                      ComponentKey.named('timer2')) ==
                                  null) {
                                add(TimerComponent(
                                  period: 1,
                                  repeat: true,
                                  removeOnFinish: true,
                                  key: ComponentKey.named('timer2'),
                                  onTick: () {
                                    final gridIsNotEmpty = grid.children
                                        .whereType<Item>()
                                        .isNotEmpty;
                                    if (gridIsNotEmpty) return;
                                    final nextItems = <Component>[];
                                    if (gameRef.gameSessionCubit.state.score ==
                                        0) {
                                      nextItems.add(Pizza()
                                        ..size = Items.pizza.getSize(lineSize)
                                        ..position = Vector2(
                                            gameRef.size.x + 100,
                                            grid.linesCentersY[1]));
                                    }
                                    if (gameRef
                                            .gameSessionCubit.state.dollars ==
                                        0) {
                                      nextItems.add(Dollar()
                                        ..size = Items.dollar.getSize(lineSize)
                                        ..position = Vector2(
                                            gameRef.size.x + 100,
                                            grid.linesCentersY[2]));
                                    }
                                    if (nextItems.isNotEmpty) {
                                      grid.addAll(nextItems);
                                    } else {
                                      final thisTimer =
                                          gameRef.findByKey<TimerComponent>(
                                              ComponentKey.named('timer2'));
                                      thisTimer?.timer.stop();
                                      cubit.hideMessage();
                                      cubit.showMessage(
                                          text: 'text4'.tr(),
                                          ignorePointer: false,
                                          onTypeWritingFinished: () {
                                            add(TimerComponent(
                                                period: 2,
                                                removeOnFinish: true,
                                                onTick: () {
                                                  cubit.hideMessage();
                                                }));
                                            if (gameRef
                                                    .findByKey<TimerComponent>(
                                                        ComponentKey.named(
                                                            'timer3')) ==
                                                null) {
                                              add(TimerComponent(
                                                  period: 1,
                                                  removeOnFinish: true,
                                                  repeat: true,
                                                  key: ComponentKey.named(
                                                      'timer3'),
                                                  onTick: () {
                                                    if (gameRef.gameSessionCubit
                                                            .state.score <
                                                        10) {
                                                      final rndIndex =
                                                          _rnd.nextInt(grid
                                                              .linesCentersY
                                                              .length);
                                                      final pizza = Pizza()
                                                        ..size = Items.pizza
                                                            .getSize(lineSize)
                                                        ..position = Vector2(
                                                            gameRef.size.x +
                                                                100,
                                                            grid.linesCentersY[
                                                                rndIndex]);
                                                      grid.add(pizza);
                                                    } else {
                                                      final thisTimer =
                                                          gameRef.findByKey<
                                                                  TimerComponent>(
                                                              ComponentKey.named(
                                                                  'timer3'));
                                                      thisTimer?.timer.stop();
                                                      cubit.showMessage(
                                                          text: 'text5'.tr(),
                                                          ignorePointer: false,
                                                          onTypeWritingFinished:
                                                              () {
                                                            cubit.hideMessage();
                                                            grid.addAll(
                                                                List.generate(
                                                              grid.linesCentersY
                                                                  .length,
                                                              (index) => Cone()
                                                                ..size = Items
                                                                    .cone
                                                                    .getSize(
                                                                        lineSize)
                                                                ..position = Vector2(
                                                                    grid.size
                                                                            .x +
                                                                        100,
                                                                    grid.linesCentersY[
                                                                        index]),
                                                            ));
                                                            if (gameRef.findByKey<
                                                                        TimerComponent>(
                                                                    ComponentKey
                                                                        .named(
                                                                            'timer4')) ==
                                                                null) {
                                                              add(
                                                                  TimerComponent(
                                                                      period: 1,
                                                                      repeat:
                                                                          true,
                                                                      removeOnFinish:
                                                                          true,
                                                                      key: ComponentKey
                                                                          .named(
                                                                              'timer4'),
                                                                      onTick:
                                                                          () {
                                                                        if (grid
                                                                            .normaldo
                                                                            .isSkinny) {
                                                                          final thisTimer =
                                                                              gameRef.findByKey<TimerComponent>(ComponentKey.named('timer4'));
                                                                          thisTimer
                                                                              ?.timer
                                                                              .stop();
                                                                          cubit
                                                                              .hideMessage();
                                                                          cubit.showMessage(
                                                                              text: 'text6'.tr(),
                                                                              ignorePointer: false,
                                                                              onTypeWritingFinished: () {
                                                                                cubit.hideMessage();
                                                                                cubit.showMessage(
                                                                                    text: 'text7'.tr(),
                                                                                    ignorePointer: false,
                                                                                    onTypeWritingFinished: () {
                                                                                      cubit.hideMessage();
                                                                                      if (gameRef.findByKey<TimerComponent>(ComponentKey.named('timer5')) == null) {
                                                                                        add(TimerComponent(
                                                                                            period: 1,
                                                                                            removeOnFinish: true,
                                                                                            repeat: true,
                                                                                            key: ComponentKey.named('timer5'),
                                                                                            onTick: () {
                                                                                              if (_effectItems.isNotEmpty) {
                                                                                                final rndIndex = _rnd.nextInt(grid.linesCentersY.length);
                                                                                                final item = _effectItems.removeAt(0);
                                                                                                grid.add(
                                                                                                  item
                                                                                                    ..size = item.item.getSize(lineSize)
                                                                                                    ..position = Vector2(grid.size.x + 100, grid.linesCentersY[rndIndex]),
                                                                                                );
                                                                                              } else {
                                                                                                final thisTimer = gameRef.findByKey<TimerComponent>(ComponentKey.named('timer5'));
                                                                                                thisTimer?.timer.stop();
                                                                                                cubit.showMessage(
                                                                                                  text: 'text8'.tr(),
                                                                                                  ignorePointer: false,
                                                                                                  onTypeWritingFinished: () {
                                                                                                    cubit.hideMessage();
                                                                                                    userCubit.educate();
                                                                                                    userCubit.introduce();
                                                                                                    gameRef.scene.moveToNextLevel();
                                                                                                    gameRef.pauseButton.position += Vector2(0, 200);
                                                                                                  },
                                                                                                );
                                                                                              }
                                                                                            }));
                                                                                      }
                                                                                    });
                                                                              });
                                                                        }
                                                                      }));
                                                            }
                                                          });
                                                    }
                                                  }));
                                            }
                                          });
                                    }
                                  },
                                ));
                              }
                            },
                          );
                        }
                      }));
                }
              });
        });
    return super.onLoad();
  }
}
