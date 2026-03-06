import '../../domain/repositories/match_repository.dart';

class CreateMatchUseCase {
  final MatchRepository repository;
  
  CreateMatchUseCase(this.repository);
  
  Future<String?> call(List<int> towerPool, int targetValue) async {
    return await repository.createMatch(towerPool, targetValue);
  }
}
