import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_user.dart';

class UserModel extends AppUser {
  const UserModel({
    required super.uid,
    required super.email,
    required super.displayName,
    super.avatarUrl,
    required super.role,
    required super.householdId,
    required super.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] as String,
      displayName: data['displayName'] as String,
      avatarUrl: data['avatarUrl'] as String?,
      role: UserRole.values.byName(data['role'] as String),
      householdId: data['householdId'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'role': role.name,
        'householdId': householdId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory UserModel.fromEntity(AppUser user) => UserModel(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        role: user.role,
        householdId: user.householdId,
        createdAt: user.createdAt,
      );
}
