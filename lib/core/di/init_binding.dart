import 'package:get/get.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/match/data/repositories/match_repository_impl.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/match/domain/usecases/solve_tower_usecase.dart';
import '../../features/match/domain/usecases/claim_tower_usecase.dart';

class InitBinding extends Bindings {
  @override
  void dependencies() {
    // 1. Auth (global singleton — never disposed)
    Get.lazyPut<AuthRepository>(() => AuthRepositoryImpl(), fenix: true);

    // 2. Match repository + use-cases needed by the MatchController binding
    final matchRepo = MatchRepositoryImpl();
    Get.lazyPut<MatchRepositoryImpl>(() => matchRepo, fenix: true);
    Get.lazyPut(() => ClaimTowerUseCase(matchRepo), fenix: true);
    Get.lazyPut(() => SolveTowerUseCase(matchRepo), fenix: true);
  }
}
