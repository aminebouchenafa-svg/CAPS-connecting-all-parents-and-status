import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _datasource;

  AuthRepositoryImpl(this._datasource);

  @override
  Stream<AppUser?> get authStateChanges =>
      _datasource.authStateChanges.asyncMap((firebaseUser) async {
        if (firebaseUser == null) return null;
        try {
          return await _datasource.getUserProfile(firebaseUser.uid);
        } on AuthException {
          return null;
        }
      });

  @override
  Future<Result<AppUser>> signInWithEmail(String email, String password) async {
    try {
      final user = await _datasource.signInWithEmail(email, password);
      return Success(user);
    } on AuthException catch (e) {
      return Error(AuthFailure(e.message));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _datasource.signOut();
      return const Success(null);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<AppUser>> getCurrentUser() async {
    try {
      final firebaseUser = _datasource.currentFirebaseUser;
      if (firebaseUser == null) {
        return const Error(AuthFailure('Aucun utilisateur connecté.'));
      }
      final user = await _datasource.getUserProfile(firebaseUser.uid);
      return Success(user);
    } on AuthException catch (e) {
      return Error(AuthFailure(e.message));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }
}
