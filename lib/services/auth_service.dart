// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  /// Stream de mudanças no estado de autenticação
  Stream<User?> get userChanges => _auth.authStateChanges();

  /// Tenta entrar com email/senha
  Future<void> signIn({required String email, required String pass}) {
    return _auth.signInWithEmailAndPassword(email: email, password: pass);
  }

  /// Cria conta
  Future<void> signUp({required String email, required String pass}) {
    return _auth.createUserWithEmailAndPassword(email: email, password: pass);
  }

  /// Envia email de recuperação
  Future<void> resetPassword(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Desloga
  Future<void> signOut() {
    return _auth.signOut();
  }
}
