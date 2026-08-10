enum CurrencyType {
  dollars,
  realMoney,
}

abstract base class ShopItem {
  double get price;
  String get title;
  String get description;
  String get imagePath;
  CurrencyType get currencyType;
}

final class DollarForAdItem extends ShopItem {
  @override
  double get price => 0;

  @override
  String get description => 'Watch AD and get some dollars!!!';

  @override
  String get imagePath => 'assets/images/tv.png';

  @override
  String get title => '+30 dollars';

  @override
  CurrencyType get currencyType => CurrencyType.dollars;
}
