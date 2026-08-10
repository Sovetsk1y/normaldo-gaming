import 'package:easy_localization/easy_localization.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/data/user/models/skin_model.dart';
import 'package:normaldo_gaming/data/user/models/user_model.dart';
import 'package:normaldo_gaming/domain/pull_up_game/entities/reward.dart';
import 'package:normaldo_gaming/domain/pull_up_game/level_manager.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';
import 'package:normaldo_gaming/domain/user/entities/user.dart';
import 'package:normaldo_gaming/domain/user/user_repository.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';
import 'package:normaldo_gaming/injection/injection.dart';

part 'user_state.dart';
part 'user_cubit.freezed.dart';

class UserCubit extends HydratedCubit<UserState> {
  UserCubit(
    this._userRepository,
    this._skinsRepository,
  ) : super(UserState.initial());

  final UserRepository _userRepository;
  final SkinsRepository _skinsRepository;

  final _levelManager = injector.get<LevelManager>();

  (Skin? skin, String? error) activateCode(String code) {
    if (state.activatedPromoCodes.contains(code)) {
      return (null, 'You have already activated this code'.tr());
    }
    final skinId = Utils.promoCodes[code];
    if (skinId != null) {
      final hasSkin = state.user.mySkins
          .where((element) => element.uniqueId == skinId)
          .isNotEmpty;
      if (!hasSkin) {
        final newMySkins = List<Skin>.from(state.user.mySkins);
        final newSkin = _skinsRepository.getSkinById(skinId);
        newMySkins.add(newSkin);
        final newActivatedPromoCodes =
            List<String>.from(state.activatedPromoCodes);
        newActivatedPromoCodes.add(code);
        emit(state.copyWith(
          activatedPromoCodes: newActivatedPromoCodes,
          user: UserModel.fromEntity(state.user)
              .copyWith(mySkins: newMySkins)
              .toEntity(),
        ));
        return (newSkin, null);
      } else {
        final newActivatedPromoCodes =
            List<String>.from(state.activatedPromoCodes);
        newActivatedPromoCodes.add(code);
        emit(state.copyWith(
          activatedPromoCodes: newActivatedPromoCodes,
          user: UserModel.fromEntity(state.user)
              .copyWith(dollars: state.user.dollars + 500)
              .toEntity(),
        ));
        return (null, 'You already have this skin. Take 500\$ instead'.tr());
      }
    } else {
      return (null, 'Unknown code'.tr());
    }
  }

  void buySkin(String uniqueId) {
    final skin = _skinsRepository.getSkinById(uniqueId);
    if (state.user.dollars < skin.price) throw UnexpectedError();
    final newMySkins = List<Skin>.from(state.user.mySkins);
    newMySkins.add(skin);
    emit(state.copyWith(
      user: UserModel.fromEntity(state.user)
          .copyWith(
            dollars: state.user.dollars - skin.price,
            mySkins: newMySkins,
          )
          .toEntity(),
    ));
  }

  void changeHighScore(int highScore) {
    assert(highScore > 0, "high score must be greater than 0");
    emit(state.copyWith(
      user: UserModel.fromEntity(state.user)
          .copyWith(highScore: highScore)
          .toEntity(),
    ));
    // _userRepository.updateUser(user: state.user);
  }

  void addDollars(int dollars) {
    assert(dollars >= 0, "dollars amount must be greater than 0");
    emit(state.copyWith(
      user: UserModel.fromEntity(state.user)
          .copyWith(dollars: state.user.dollars + dollars)
          .toEntity(),
    ));
    // _userRepository.updateUser(user: state.user);
  }

  void takeDollars(int dollars) {
    assert(dollars <= state.user.dollars);
    emit(
      state.copyWith(
        user: UserModel.fromEntity(state.user)
            .copyWith(dollars: state.user.dollars - dollars)
            .toEntity(),
      ),
    );
    // _userRepository.updateUser(user: state.user).catchError((e) {
    //   print(e);
    // });
  }

  void applyRewards(List<Reward> rewards) {
    var bucksRewarded = 0;
    var extraLivesRewarded = 0;
    List<Skin> newSkins = [];
    for (final reward in rewards) {
      switch (reward) {
        case BucksReward():
          bucksRewarded += reward.amount;
        case ExtraLiveReward():
          extraLivesRewarded += reward.amount;
        case SkinReward():
          if (state.user.mySkins.every((s) => s.uniqueId != reward.uniqueId)) {
            newSkins.add(_skinsRepository.getSkinById(reward.uniqueId));
          }
        default:
          continue;
      }
    }
    emit(state.copyWith(
        user: UserModel.fromEntity(state.user)
            .copyWith(
              dollars: state.user.dollars + bucksRewarded,
              extraLives: state.user.extraLives + extraLivesRewarded,
              mySkins: (newSkins..addAll(state.user.mySkins)),
            )
            .toEntity()));
  }

  void addExtraLife(int amount) {
    assert(amount > 0);
    emit(
      state.copyWith(
        user: UserModel.fromEntity(state.user)
            .copyWith(extraLives: state.user.extraLives + amount)
            .toEntity(),
      ),
    );
    // _userRepository.updateUser(user: state.user);
  }

  void educate() {
    emit(state.copyWith(educated: true));
  }

  void introduce() {
    emit(state.copyWith(introduced: true));
  }

  void toggleEducation() {
    emit(state.copyWith(educated: !state.educated));
  }

  void takeExtraLife(int amount) {
    assert(amount > 0);
    emit(
      state.copyWith(
        user: UserModel.fromEntity(state.user)
            .copyWith(extraLives: state.user.extraLives - amount)
            .toEntity(),
      ),
    );
    // _userRepository.updateUser(user: state.user);
  }

  void changeName(String name) {
    assert(name.length >= 3, "too short name");
    emit(state.copyWith(
      user: UserModel.fromEntity(state.user).copyWith(name: name).toEntity(),
    ));
    // _userRepository.updateUser(user: state.user);
  }

  void changeSkin(Skin skin) {
    emit(state.copyWith(skin: skin));
  }

  void addExp(int exp) {
    assert(exp > 0);
    var newExp = state.user.exp + exp;
    var newLevel = state.user.level;
    void configureLevel() {
      if (newExp >= _levelManager.nextLevelExp(state.user)) {
        final levelsCount = newExp ~/ _levelManager.nextLevelExp(state.user);
        newExp = newExp % _levelManager.nextLevelExp(state.user);
        if (levelsCount > 0 || newExp == 0) {
          newLevel += levelsCount;
          configureLevel();
        } else {
          return;
        }
      }
    }

    configureLevel();

    emit(state.copyWith(
      user: UserModel.fromEntity(state.user)
          .copyWith(
            exp: newExp,
            level: newLevel,
          )
          .toEntity(),
    ));
    // _userRepository.updateUser(user: state.user);
  }

  void reset() {
    emit(UserState.initial());
  }

  @override
  UserState? fromJson(Map<String, dynamic> json) {
    return UserState(
        user: UserModel.fromJson(json).toEntity(),
        educated: json['educated'],
        introduced: json['introduced'],
        activatedPromoCodes: (json['activatedPromoCodes'] as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
        skin: SkinModel.fromJson(
          json['skin'],
        ).toEntity());
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    print(error);
    super.onError(error, stackTrace);
  }

  @override
  Map<String, dynamic>? toJson(UserState state) {
    final user = state.user;
    final json = UserModel(
      id: user.id,
      name: user.name,
      dollars: user.dollars,
      highScore: user.highScore,
      level: state.user.level,
      exp: state.user.exp,
      extraLives: state.user.extraLives,
      totalPizzas: state.user.totalPizzas,
      mySkins: user.mySkins,
    ).toJson()
      ..addEntries([
        MapEntry('educated', state.educated),
        MapEntry('introduced', state.introduced),
        MapEntry('activatedPromoCodes', state.activatedPromoCodes),
        MapEntry(
          'skin',
          SkinModel.fromEntity(state.skin).toJson(),
        ),
      ]);
    return json;
  }
}
