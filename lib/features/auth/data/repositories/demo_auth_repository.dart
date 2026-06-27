import 'dart:async';

import '../../../../core/constants/demo_data.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class DemoAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  DemoAuthRepository() {
    _currentUser = DemoData.pilot;
    _controller.add(_currentUser);
  }

  @override
  Stream<AppUser?> get authStateChanges =>
      Stream.value(_currentUser).asBroadcastStream();

  @override
  Future<Result<AppUser>> signInWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (email.contains('amina')) {
      _currentUser = DemoData.spouse;
    } else {
      _currentUser = DemoData.pilot;
    }
    _controller.add(_currentUser);
    return Success(_currentUser!);
  }

  @override
  Future<Result<void>> signOut() async {
    _currentUser = null;
    _controller.add(null);
    return const Success(null);
  }

  @override
  Future<Result<AppUser>> getCurrentUser() async {
    if (_currentUser == null) {
      return Success(DemoData.pilot);
    }
    return Success(_currentUser!);
  }
}
