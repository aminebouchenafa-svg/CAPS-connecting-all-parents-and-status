import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Une erreur serveur est survenue.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Erreur d\'authentification.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Erreur de cache local.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Pas de connexion internet.']);
}

class PermissionFailure extends Failure {
  const PermissionFailure(
      [super.message = 'Accès non autorisé à ce foyer.']);
}
