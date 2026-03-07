import 'package:get/get.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/match/data/repositories/match_repository_impl.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/match/domain/usecases/create_match_usecase.dart';
import '../../features/match/domain/usecases/join_match_usecase.dart';
import '../../features/match/domain/usecases/generate_tower_pool_usecase.dart';
import '../../features/match/presentation/controllers/lobby_controller.dart';
import '../../features/match/domain/usecases/solve_tower_usecase.dart';
import '../../features/match/domain/usecases/claim_tower_usecase.dart';
import '../../features/match/presentation/controllers/match_controller.dart';

class InitBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthRepository>(() => AuthRepositoryImpl());
    final matchRepo = MatchRepositoryImpl();
    
    // Core Dependencies for Lobby
    Get.lazyPut(() => CreateMatchUseCase(matchRepo));
    Get.lazyPut(() => JoinMatchUseCase(matchRepo));
    Get.lazyPut(() => GenerateTowerPoolUseCase());
    
    Get.lazyPut(() => LobbyController(
      authRepo: Get.find(),
      matchRepo: matchRepo,
      createMatchUseCase: Get.find(),
      joinMatchUseCase: Get.find(),
      generateTowerPoolUseCase: Get.find(),
    ));
    
    // Core Dependencies for Match (These are kept alive so the MatchScreen can consume them)
    Get.lazyPut(() => ClaimTowerUseCase(matchRepo));
    Get.lazyPut(() => SolveTowerUseCase(matchRepo));
    Get.lazyPut(() => MatchRepositoryImpl()); // Base instance for the controller
  }
}
