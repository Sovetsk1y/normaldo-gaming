mixin ConsumableReward {
  int get amount;
}

sealed class Reward {
  const Reward();
}

final class BucksReward extends Reward with ConsumableReward {
  const BucksReward({required this.amount});

  @override
  final int amount;
}

final class SkinReward extends Reward {
  const SkinReward(this.uniqueId);

  final String uniqueId;
}

final class ExtraLiveReward extends Reward with ConsumableReward {
  const ExtraLiveReward({required this.amount});

  @override
  final int amount;
}

final class RankReward extends Reward {
  const RankReward({required this.rank});

  final String rank;
}

final class TextReward extends Reward {
  const TextReward({required this.text});

  final String text;
}
