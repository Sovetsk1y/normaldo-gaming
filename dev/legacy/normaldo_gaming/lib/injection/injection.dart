import 'package:chopper/chopper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:normaldo_gaming/application/ads/ads_cubit.dart';
import 'package:normaldo_gaming/application/auth/auth_cubit.dart';
import 'package:normaldo_gaming/application/daily_reward/cubit/daily_reward_cubit.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
import 'package:normaldo_gaming/application/mission/mission_cubit.dart';
import 'package:normaldo_gaming/application/pre_death/pre_death_cubit.dart';
import 'package:normaldo_gaming/application/shop_items_list/shop_items_list_cubit.dart';
import 'package:normaldo_gaming/application/sign_in/sign_in_cubit.dart';
import 'package:normaldo_gaming/application/sign_up/sign_up_cubit.dart';
import 'package:normaldo_gaming/application/slot_machine/cubit/slot_machine_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/config/config.dart';
import 'package:normaldo_gaming/data/ads/ng_ad_manager.dart';
import 'package:normaldo_gaming/data/auth/auth_repository_impl.dart';
import 'package:normaldo_gaming/data/auth/services/auth_api_service.dart';
import 'package:normaldo_gaming/data/auth/services/auth_local_storage.dart';
import 'package:normaldo_gaming/data/core/interceptors/auth_interceptor.dart';
import 'package:normaldo_gaming/data/core/interceptors/token_interceptor.dart';
import 'package:normaldo_gaming/data/level/level_manager_impl.dart';
import 'package:normaldo_gaming/data/mission/missions_repository_impl.dart';
import 'package:normaldo_gaming/data/shop/shop_repository_impl.dart';
import 'package:normaldo_gaming/data/skins/skins_repository_test_impl.dart';
import 'package:normaldo_gaming/data/user/services/user_api_service.dart';
import 'package:normaldo_gaming/data/user/user_repository_impl.dart';
import 'package:normaldo_gaming/domain/ads/ad_manager.dart';
import 'package:normaldo_gaming/domain/app/audio_pools.dart';
import 'package:normaldo_gaming/domain/auth/auth_repository.dart';
import 'package:normaldo_gaming/domain/knowledge/knowledge_repository.dart';
import 'package:normaldo_gaming/domain/pull_up_game/level_manager.dart';
import 'package:normaldo_gaming/domain/pull_up_game/missions/missions_repository.dart';
import 'package:normaldo_gaming/domain/shop/shop_repository.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';
import 'package:normaldo_gaming/domain/user/user_repository.dart';

final injector = Injector();

void initializeInjector(Config config) {
  // Cubits&Blocs
  injector.map<UserCubit>((injector) => UserCubit(
        injector.get(),
        injector.get(key: 'skins_test'),
      ));
  injector.map<GameSessionCubit>((injector) => GameSessionCubit());
  injector.map<LevelBloc>((injector) => LevelBloc());
  injector.map<SlotMachineCubit>((injector) => SlotMachineCubit());
  injector.map<PreDeathCubit>((injector) => PreDeathCubit());
  injector.map<AdsCubit>((injector) => AdsCubit());
  injector.map<ShopItemsListCubit>(
      (injector) => ShopItemsListCubit(injector.get()));
  injector.map<AuthCubit>((injector) => AuthCubit(injector.get()));
  injector.map<SignUpCubit>((injector) => SignUpCubit(injector.get()));
  injector.map<SignInCubit>((injector) => SignInCubit(injector.get()));
  injector.map<MissionCubit>(
    (injector) => MissionCubit(injector.get()),
    allowFutureReassignment: true,
  );
  injector.map<DailyRewardCubit>((injector) => DailyRewardCubit());

  // Repositories
  injector.map<MissionsRepository>((injector) => MissionsRepositoryImpl());
  injector.map<ShopRepository>((injector) => ShopRepositoryImpl());
  injector.map<KnowledgeRepository>((injector) => KnowledgeRepositoryImpl());
  injector.map<UserRepository>((injector) => UserRepositoryImpl(
        injector.get<ChopperClient>().getService<UserApiService>(),
      ));
  injector.map<AuthRepository>(
    (injector) => AuthRepositoryImpl(
      injector.get<ChopperClient>().getService<AuthApiService>(),
      injector.get<AuthLocalStorage>(),
    ),
    isSingleton: true,
  );
  injector.map<SkinsRepository>(
    (injector) => SkinsRepositoryTestImpl(),
    key: 'skins_test',
    isSingleton: true,
  );

  // Services

  // Audio
  injector.map<AudioManager>((injector) => AudioManager(), isSingleton: true);
  injector.map<AudioPools>(
    (injector) => AudioPools(injector.get()),
    isSingleton: true,
  );

  // Storages
  injector.map<AuthLocalStorage>(
      (injector) => const AuthLocalStorageImpl(FlutterSecureStorage()));

  // Managers
  injector.map<BaseAdManager>((injector) => AdManager(config));
  injector.map<LevelManager>(
    (injector) => LevelManagerImpl(),
    isSingleton: true,
  );

  // Network
  injector.map<ChopperClient>((injector) => ChopperClient(
          baseUrl: Uri.parse('http://45.135.164.174:3000'),
          converter: const JsonConverter(),
          interceptors: [
            TokenInterceptor(
              injector.get<AuthLocalStorage>(),
            ),
            AuthInterceptor(injector.get<AuthLocalStorage>()),
          ],
          services: [
            AuthApiService.create(),
            UserApiService.create(),
          ]));
}
