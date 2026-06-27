import 'package:equatable/equatable.dart';

enum UserRole { pilot, spouse, child }

class AppUser extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final UserRole role;
  final String householdId;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.householdId,
    required this.createdAt,
  });

  bool get isPilot => role == UserRole.pilot;

  @override
  List<Object?> get props =>
      [uid, email, displayName, avatarUrl, role, householdId, createdAt];
}
