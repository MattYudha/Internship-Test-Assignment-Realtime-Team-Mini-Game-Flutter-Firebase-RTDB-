import 'package:get/get.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../data/repositories/match_repository_impl.dart';
import '../../auth/data/repositories/auth_repository_impl.dart';
import '../domain/usecases/create_match_usecase.dart';
import '../domain/usecases/join_match_usecase.dart';
import '../domain/usecases/generate_tower_pool_usecase.dart';
import '../presentation/controllers/lobby_controller.dart';
import '../domain/usecases/solve_tower_usecase.dart';
import '../domain/usecases/claim_tower_usecase.dart';
import '../presentation/controllers/match_controller.dart';

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
