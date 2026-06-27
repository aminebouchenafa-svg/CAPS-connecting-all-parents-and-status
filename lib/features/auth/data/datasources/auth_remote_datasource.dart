import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

class AuthRemoteDatasource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRemoteDatasource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Future<UserModel> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user == null) {
        throw const AuthException('Utilisateur non trouvé.');
      }
      return getUserProfile(credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Erreur d\'authentification.');
    }
  }

  Future<UserModel> getUserProfile(String uid) async {
    final doc = await _firestore.doc(FirestorePaths.user(uid)).get();
    if (!doc.exists) {
      throw const AuthException('Profil utilisateur introuvable.');
    }
    return UserModel.fromFirestore(doc);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
