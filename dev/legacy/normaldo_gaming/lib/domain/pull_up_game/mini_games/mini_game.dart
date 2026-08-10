import 'package:freezed_annotation/freezed_annotation.dart';

part 'mini_game.freezed.dart';

@freezed
class MiniGame with _$MiniGame {
  const factory MiniGame.shredder() = _Shredder;
}
