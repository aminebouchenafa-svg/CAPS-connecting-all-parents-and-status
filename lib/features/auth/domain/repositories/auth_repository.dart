import '../../../../core/utils/result.dart';
import '../entities/app_user.dart';

abstract interface class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  Future<Result<AppUser>> signInWithEmail(String email, String password);
  Future<Result<void>> signOut();
  Future<Result<AppUser>> getCurrentUser();
}
