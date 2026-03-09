import 'package:get/get.dart';
import '../../features/match/presentation/controllers/lobby_controller.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/match/data/repositories/match_repository_impl.dart';
import '../../features/match/domain/usecases/create_match_usecase.dart';
import '../../features/match/domain/usecases/join_match_usecase.dart';
import '../../features/match/domain/usecases/generate_tower_pool_usecase.dart';

class LobbyBinding extends Bindings {
  @override
  void dependencies() {
    // We instantiate the repo specifically for the lobby
    final matchRepo = MatchRepositoryImpl();
    
    Get.lazyPut(() => CreateMatchUseCase(matchRepo), fenix: true);
    Get.lazyPut(() => JoinMatchUseCase(matchRepo), fenix: true);
    Get.lazyPut(() => GenerateTowerPoolUseCase(), fenix: true);
    
    Get.lazyPut(() => LobbyController(
      authRepo: Get.find<AuthRepository>(),
      matchRepo: matchRepo,
      createMatchUseCase: Get.find<CreateMatchUseCase>(),
      joinMatchUseCase: Get.find<JoinMatchUseCase>(),
      generateTowerPoolUseCase: Get.find<GenerateTowerPoolUseCase>(),
    ), fenix: true);
  }
}
