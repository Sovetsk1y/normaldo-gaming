enum Rolls {
  // Gives 1 exp
  exp1(7),
  // Gives 2 exp
  exp2(3),
  // Gives 3 exps
  exp3(1),
  // Reduces your bid by 2
  half1(50),
  // Shows different values on slot machine
  empty(50),
  // Gives extra life bonus to your user
  extraLife(0.5),
  // Gives x2 to your bid
  win(20),
  // Gives x100 to your bid
  jackpot(0.01);

  const Rolls(this.baseChance);

  final double baseChance;

  double weight() => baseChance;

  @override
  String toString() {
    return switch (this) {
      exp1 => '1 опыт!',
      exp2 => '2 опыта!',
      exp3 => '3 опыта!',
      half1 => '1/2 ставки!',
      empty => 'Не повезло!',
      extraLife => 'Доп. жизнь!',
      win => '1.5х ставки!',
      jackpot => '5х ставки',
    };
  }
}
