import 'package:equatable/equatable.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';

class LineItem {
  final Items item;

  /// null means that line should be randomized
  final int? line;

  const LineItem({required this.item, this.line})
      : assert((line ?? 0) >= 0 && (line ?? 0) < Utils.linesCount);
}

abstract class Level extends Equatable {
  int get index;
  double get frequency;
  double get speed;

  @override
  bool? get stringify => true;
}

class LinearLevel implements Level {
  LinearLevel({
    required this.index,
    required this.frequency,
    required this.speed,
  });

  @override
  final int index;

  @override
  final double frequency;

  @override
  final double speed;

  final List<Items> _itemsPool = [];

  LinearLevel copyWith({
    double? frequency,
    double? speed,
  }) =>
      LinearLevel(
        index: index,
        frequency: frequency ?? this.frequency,
        speed: speed ?? this.speed,
      );

  @override
  List<Object?> get props => [
        speed,
        frequency,
        index,
      ];

  @override
  bool? get stringify => true;
}
