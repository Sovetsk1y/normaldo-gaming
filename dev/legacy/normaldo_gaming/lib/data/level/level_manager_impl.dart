import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/domain/pull_up_game/entities/reward.dart';
import 'package:normaldo_gaming/domain/pull_up_game/level_manager.dart';
import 'package:normaldo_gaming/domain/user/entities/user.dart';

class LevelManagerImpl implements LevelManager {
  static const _ranks = [
    'Hungerling',
    'Nibbler',
    'Gourmand',
    'Muncher',
    'Glutton',
    'Sweet Tooth',
    'Foodie',
    'Foodie-Pro',
    'Devourer',
    'Gutspiller',
    'Digestor',
    'Epic Devourer',
    'Engulfer',
    'Abdominal Magnate',
    'Satiated Warrior',
    'Belly Gladiator',
    'Omnivorous Monster',
    'Bottomless Barrel',
    'Fat',
    'Universe Eater',
    'FATBOSS',
  ];

  LevelManagerImpl();

  @override
  int nextLevelExp(User user) {
    return switch (user.level) {
      0 => 3,
      1 || 2 => 5,
      3 || 4 => 7,
      5 || 6 => 9,
      7 || 8 || 9 || 10 => 10,
      100 => LevelManager.maxLevelExp,
      _ => (user.level + 1) + 2,
    };
  }

  @override
  String rank(User user) {
    if (_ranks.isEmpty) throw UnexpectedError();
    final level = user.level;
    if (level < 5) return _ranks[0];
    if (level < 7) return _ranks[1];
    if (level < 10) return _ranks[2];
    if (level < 13) return _ranks[3];
    if (level < 15) return _ranks[4];
    if (level < 17) return _ranks[5];
    if (level < 20) return _ranks[6];
    if (level < 23) return _ranks[7];
    if (level < 25) return _ranks[8];
    if (level < 27) return _ranks[9];
    if (level < 30) return _ranks[10];
    if (level < 33) return _ranks[11];
    if (level < 35) return _ranks[12];
    if (level >= 35) {
      final nextIndex = level - 22;
      if (nextIndex >= _ranks.length) {
        return _ranks[_ranks.length - 1];
      }
      return _ranks[nextIndex];
    }
    return _ranks[0];
  }

  String rankFromLvl(int lvl) {
    return rank(User(
      id: '',
      name: '',
      highScore: 0,
      dollars: 0,
      level: lvl,
      exp: 0,
      extraLives: 0,
      totalPizzas: 0,
      mySkins: [],
    ));
  }

  @override
  bool isMaxLevel(User user) => nextLevelExp(user) == LevelManager.maxLevelExp;

  @override
  List<List<Reward>> get levelUpRewards => [
        // 1 lvl
        [const TextReward(text: 'HERE WE GO')],
        // 2 lvl
        [const BucksReward(amount: 50)],
        // 3 lvl
        [const BucksReward(amount: 50)],
        // 4 lvl
        [const BucksReward(amount: 50)],
        // 5 lvl
        [
          const BucksReward(amount: 100),
          const ExtraLiveReward(amount: 2),
          RankReward(rank: rankFromLvl(5)),
          const SkinReward('viking'),
        ],
        // 6 lvl
        [const BucksReward(amount: 100)],
        // 7 lvl
        [
          const BucksReward(amount: 150),
          const ExtraLiveReward(amount: 2),
          RankReward(rank: rankFromLvl(7)),
        ],
        // 8 lvl
        [const BucksReward(amount: 150)],
        // 9 lvl
        [const BucksReward(amount: 150)],
        // 10 lvl
        [
          const BucksReward(amount: 300),
          const SkinReward('batman'),
          const ExtraLiveReward(amount: 5),
          RankReward(rank: rankFromLvl(10)),
        ],
        // 11 lvl
        [const BucksReward(amount: 300)],
        // 12 lvl
        [const BucksReward(amount: 300)],
        // 13 lvl
        [
          const BucksReward(amount: 400),
          RankReward(rank: rankFromLvl(13)),
          const ExtraLiveReward(amount: 3),
        ],
        // 14 lvl
        [const BucksReward(amount: 400)],
        // 15 lvl
        [
          const BucksReward(amount: 500),
          RankReward(rank: rankFromLvl(15)),
          const ExtraLiveReward(amount: 3),
        ],
        // 16 lvl
        [const BucksReward(amount: 500)],
        // 17 lvl
        [
          const BucksReward(amount: 500),
          RankReward(rank: rankFromLvl(17)),
          const SkinReward('dracula'),
          const ExtraLiveReward(amount: 3),
        ],
        // 18 lvl
        [const BucksReward(amount: 500)],
        // 19 lvl
        [const BucksReward(amount: 500)],
        // 20 lvl
        [
          const BucksReward(amount: 500),
          RankReward(rank: rankFromLvl(20)),
          const ExtraLiveReward(amount: 2),
        ],
        // 21 lvl
        [const BucksReward(amount: 500)],
        // 22 lvl
        [const BucksReward(amount: 500)],
        // 23 lvl
        [
          const BucksReward(amount: 500),
          RankReward(rank: rankFromLvl(23)),
          const ExtraLiveReward(amount: 2),
        ],
        // 24 lvl
        [const BucksReward(amount: 500)],
        // 25 lvl
        [
          const BucksReward(amount: 500),
          RankReward(rank: rankFromLvl(25)),
          const ExtraLiveReward(amount: 1),
        ],
        // 26 lvl
        [const BucksReward(amount: 500)],
        // 27 lvl
        [
          const BucksReward(amount: 500),
          RankReward(rank: rankFromLvl(27)),
          const ExtraLiveReward(amount: 1),
        ],
        // 28 lvl
        [const BucksReward(amount: 500)],
        // 29 lvl
        [const BucksReward(amount: 500)],
        // 30 lvl
        [
          const BucksReward(amount: 700),
          RankReward(rank: rankFromLvl(30)),
          const SkinReward('spider-man'),
          const ExtraLiveReward(amount: 1),
        ],
        // 31 lvl
        [const BucksReward(amount: 700)],
        // 32 lvl
        [const BucksReward(amount: 700)],
        // 33 lvl
        [
          const BucksReward(amount: 700),
          RankReward(rank: rankFromLvl(33)),
          const ExtraLiveReward(amount: 1),
        ],
        // 34 lvl
        [const BucksReward(amount: 700)],
        // 35 lvl
        [
          const BucksReward(amount: 1000),
          RankReward(rank: rankFromLvl(35)),
          const ExtraLiveReward(amount: 1),
        ],
      ];
}
