import 'package:flame/components.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/item_components/all_in.dart';
import 'package:normaldo_gaming/game/components/item_components/angry_dog.dart';
import 'package:normaldo_gaming/game/components/item_components/banana_peel.dart';
import 'package:normaldo_gaming/game/components/item_components/beer.dart';
import 'package:normaldo_gaming/game/components/item_components/bird.dart';
import 'package:normaldo_gaming/game/components/item_components/boombox.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/ninja_foot/smoke.dart';
import 'package:normaldo_gaming/game/components/item_components/bubbles.dart';
import 'package:normaldo_gaming/game/components/item_components/bullet.dart';
import 'package:normaldo_gaming/game/components/item_components/cannibal.dart';
import 'package:normaldo_gaming/game/components/item_components/casey_mask.dart';
import 'package:normaldo_gaming/game/components/item_components/casino_chip.dart';
import 'package:normaldo_gaming/game/components/item_components/cocktail.dart';
import 'package:normaldo_gaming/game/components/item_components/compass.dart';
import 'package:normaldo_gaming/game/components/item_components/cone.dart';
import 'package:normaldo_gaming/game/components/item_components/dollar.dart';
import 'package:normaldo_gaming/game/components/item_components/energizer.dart';
import 'package:normaldo_gaming/game/components/item_components/girl.dart';
import 'package:normaldo_gaming/game/components/item_components/gold_clocks.dart';
import 'package:normaldo_gaming/game/components/item_components/green_poison.dart';
import 'package:normaldo_gaming/game/components/item_components/gun.dart';
import 'package:normaldo_gaming/game/components/item_components/handcuffs.dart';
import 'package:normaldo_gaming/game/components/item_components/homeless.dart';
import 'package:normaldo_gaming/game/components/item_components/fat_pizza.dart';
import 'package:normaldo_gaming/game/components/item_components/hourglass.dart';
import 'package:normaldo_gaming/game/components/item_components/huge_item.dart';
import 'package:normaldo_gaming/game/components/item_components/letter_bottle.dart';
import 'package:normaldo_gaming/game/components/item_components/loser_ticket.dart';
import 'package:normaldo_gaming/game/components/item_components/magic_box.dart';
import 'package:normaldo_gaming/game/components/item_components/magic_hat.dart';
import 'package:normaldo_gaming/game/components/item_components/magnet.dart';
import 'package:normaldo_gaming/game/components/item_components/molotov.dart';
import 'package:normaldo_gaming/game/components/item_components/money_bag.dart';
import 'package:normaldo_gaming/game/components/item_components/mutagen.dart';
import 'package:normaldo_gaming/game/components/item_components/note.dart';
import 'package:normaldo_gaming/game/components/item_components/note2.dart';
import 'package:normaldo_gaming/game/components/item_components/phone.dart';
import 'package:normaldo_gaming/game/components/item_components/pizza.dart';
import 'package:normaldo_gaming/game/components/item_components/police_alarm.dart';
import 'package:normaldo_gaming/game/components/item_components/police_car.dart';
import 'package:normaldo_gaming/game/components/item_components/policeman.dart';
import 'package:normaldo_gaming/game/components/item_components/punch.dart';
import 'package:normaldo_gaming/game/components/item_components/road_sign.dart';
import 'package:normaldo_gaming/game/components/item_components/security.dart';
import 'package:normaldo_gaming/game/components/item_components/ship_part.dart';
import 'package:normaldo_gaming/game/components/item_components/shredder_sword.dart';
import 'package:normaldo_gaming/game/components/item_components/shuriken.dart';
import 'package:normaldo_gaming/game/components/item_components/snake.dart';
import 'package:normaldo_gaming/game/components/item_components/spades_card.dart';
import 'package:normaldo_gaming/game/components/item_components/stone.dart';
import 'package:normaldo_gaming/game/components/item_components/tire.dart';
import 'package:normaldo_gaming/game/components/item_components/trash_bin.dart';
import 'package:normaldo_gaming/game/components/item_components/tv.dart';
import 'package:normaldo_gaming/game/components/item_components/umbrella.dart';

enum Items {
  trashBin,
  pizza,
  dollar,
  fatPizza,
  homeless,
  moneyBag,
  boombox,
  cocktail,
  molotov,
  hourglass,
  punch,
  hugeItem,
  allIn,
  angryDog,
  bananaPeel,
  beer,
  cannibal,
  casinoChip,
  greenPoison,
  compass,
  energizer,
  bird,
  snake,
  policeAlarm,
  gun,
  bubbles,
  girl,
  goldClocks,
  handcuffs,
  caseyMask,
  loserTicket,
  magicHat,
  magicBox,
  magnet,
  note,
  note2,
  phone,
  spadesCard,
  policeman,
  security,
  shipPart,
  cone,
  stone,
  letterBottle,
  roadSign,
  umbrella,
  mutagen,
  tv,
  tire,
  bullet,
  policeCar,
  // BOSSES&ATTACKS
  shredder,
  shuriken,
  shredderSword,
  smoke;

  Item component() {
    switch (this) {
      case Items.trashBin:
        return TrashBin();
      case Items.pizza:
        return Pizza();
      case Items.dollar:
        return Dollar();
      case Items.fatPizza:
        return FatPizza();
      case Items.homeless:
        return Homeless();
      case Items.moneyBag:
        return MoneyBag();
      case Items.boombox:
        return Boombox();
      case Items.cocktail:
        return PurpleCocktail();
      case Items.molotov:
        return Molotov();
      case Items.hourglass:
        return Hourglass();
      case Items.punch:
        return Punch();
      case shredder:
        return Cone();
      case shuriken:
        return Shuriken();
      case shredderSword:
        return ShredderSword();
      case hugeItem:
        return HugeItem();
      case allIn:
        return AllIn();
      case angryDog:
        return AngryDog();
      case bananaPeel:
        return BananaPeel();
      case beer:
        return Beer();
      case cannibal:
        return Cannibal();
      case casinoChip:
        return CasinoChip();
      case greenPoison:
        return GreenPoison();
      case compass:
        return Compass();
      case energizer:
        return Energizer();
      case bird:
        return Bird();
      case snake:
        return Snake();
      case policeAlarm:
        return PoliceAlarm();
      case gun:
        return Gun();
      case bubbles:
        return Bubbles();
      case girl:
        return Girl();
      case goldClocks:
        return GoldClocks();
      case handcuffs:
        return Handcuffs();
      case caseyMask:
        return CaseyMask();
      case loserTicket:
        return LoserTicket();
      case magicHat:
        return MagicHat();
      case magicBox:
        return MagicBox();
      case magnet:
        return Magnet();
      case note:
        return Note();
      case note2:
        return Note2();
      case phone:
        return Phone();
      case spadesCard:
        return SpadesCard();
      case policeman:
        return Policeman();
      case security:
        return Security();
      case shipPart:
        return ShipPart();
      case cone:
        return Cone();
      case stone:
        return Stone();
      case letterBottle:
        return LetterBottle();
      case roadSign:
        return RoadSign();
      case umbrella:
        return Umbrella();
      case smoke:
        return Smoke(corners: []);
      case mutagen:
        return Mutagen();
      case tv:
        return Tv();
      case tire:
        return Tire();
      case bullet:
        return Bullet();
      case policeCar:
        return PoliceCar();
    }
  }

  Vector2 getSize(double lineSize) {
    switch (this) {
      case Items.trashBin:
        final height = lineSize * 3;
        return Vector2(height * _widthFactor, height);
      case Items.pizza:
        return Vector2(lineSize * 0.7, lineSize * 0.7);
      case Items.dollar:
        return Vector2(lineSize * 0.7, lineSize * 0.7);
      case Items.fatPizza:
        return Vector2(lineSize, lineSize);
      case Items.homeless:
        return Vector2(lineSize, lineSize);
      case Items.moneyBag:
        return Vector2(lineSize / 1.5, lineSize / 1.5);
      case Items.boombox:
        return Vector2(lineSize * 2, lineSize * 1.7);
      case Items.cocktail:
        return Vector2(lineSize, lineSize);
      case Items.molotov:
        return Vector2(lineSize * 1.8, lineSize * 1.5);
      case Items.hourglass:
        return Vector2(lineSize * 0.9, lineSize * 0.9);
      case Items.punch:
        return Vector2(lineSize, lineSize);
      case hugeItem:
        return Vector2(lineSize * 6 / 1.2, lineSize * 3 * 0.95);
      case shredder:
        return Vector2(lineSize * 0.8, lineSize * 0.8);
      case shuriken:
        return Vector2(lineSize / 2, lineSize / 2);
      case shredderSword:
        return Vector2(lineSize * 0.8, lineSize * 0.8);
      case allIn:
        return Vector2(lineSize * 0.8, lineSize * 0.8);
      case angryDog:
        return Vector2(lineSize, lineSize);
      case bananaPeel:
        return Vector2(lineSize, lineSize);
      // case bananaPeel:
      //   return Vector2(lineSize * 0.8, lineSize * 0.8);
      case beer:
        return Vector2(lineSize * 0.6, lineSize * 0.8);
      case Items.cannibal:
        return Vector2(lineSize * 0.8, lineSize * 0.8);
      case Items.casinoChip:
        return Vector2(lineSize * 0.6, lineSize * 0.6);
      case Items.greenPoison:
        return Vector2(lineSize, lineSize * 1.2);
      case Items.compass:
        return Vector2(lineSize * 0.7, lineSize * 0.7);
      case Items.energizer:
        return Vector2(lineSize * 0.6, lineSize * 0.8);
      case Items.bird:
        return Vector2(lineSize * 1.2, lineSize * 1.2);
      case Items.snake:
        return Vector2(lineSize * 0.7, lineSize * 0.7);
      case Items.policeAlarm:
        return Vector2(lineSize * 0.7, lineSize * 0.7);
      case Items.gun:
        return Vector2(lineSize * 0.7, lineSize * 0.7);
      case Items.bubbles:
        return Vector2(lineSize * 0.7, lineSize * 0.7);
      case Items.girl:
        return Vector2(lineSize * 1.3, lineSize * 1.3);
      case Items.goldClocks:
        return Vector2(lineSize * 0.6, lineSize * 0.6);
      case Items.handcuffs:
        return Vector2(lineSize, lineSize);
      case Items.caseyMask:
        return Vector2(lineSize, lineSize);
      // case Items.caseyMask:
      //   return Vector2(lineSize * 0.6, lineSize * 0.6);
      case Items.loserTicket:
        return Vector2(lineSize * 0.8, lineSize * 0.6);
      case Items.magicHat:
        return Vector2(lineSize, lineSize);
      case Items.magicBox:
        return Vector2(lineSize, lineSize);
      case Items.magnet:
        return Vector2(lineSize * 0.8, lineSize * 0.8);
      case Items.note:
        return Vector2(lineSize * 0.7, lineSize * 0.7);
      case Items.note2:
        return Vector2(lineSize * 0.7, lineSize * 0.7);
      case Items.phone:
        return Vector2(lineSize * 0.7, lineSize * 0.6);
      case Items.spadesCard:
        return Vector2(lineSize * 0.7, lineSize * 0.7);
      case Items.policeman:
        return Vector2(lineSize * 1, lineSize * 1);
      case Items.security:
        return Vector2(lineSize * 1.3, lineSize * 1.3);
      case Items.shipPart:
        return Vector2(lineSize * 3, lineSize * 3);
      case Items.cone:
        return Vector2(lineSize * _widthFactor, lineSize);
      case Items.stone:
        return Vector2(lineSize * 0.7, lineSize * 0.7);
      case Items.letterBottle:
        return Vector2(lineSize, lineSize);
      case Items.roadSign:
        final height = lineSize * 2.5;
        return Vector2(height * _widthFactor, height);
      // case Items.roadSign:
      //   return Vector2(lineSize, lineSize);
      case Items.umbrella:
        return Vector2(lineSize, lineSize);
      case Items.smoke:
        return Vector2(lineSize * 0.5, lineSize * 0.5);
      case Items.mutagen:
        return Vector2(lineSize * 0.8, lineSize * 0.8);
      case Items.tv:
        return Vector2(lineSize * 0.8 * 1.356, lineSize * 0.8);
      case Items.tire:
        return Vector2(lineSize, lineSize);
      case Items.bullet:
        const double height = 25;
        return Vector2(height * 1.57, height);
      case Items.policeCar:
        final height = lineSize * 3;
        return Vector2(height * _widthFactor, height);
    }
  }

  double get _widthFactor => switch (this) {
        trashBin => 1.295,
        cone => 1,
        homeless => 1,
        roadSign => 1,
        bananaPeel => 1,
        policeCar => 1,
        _ => 1,
      };
}
