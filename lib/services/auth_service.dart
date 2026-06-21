import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  GoTrueClient get _auth => Supabase.instance.client.auth;

  User? get currentUser => _auth.currentUser;

  String? get currentEmail => _auth.currentUser?.email;

  bool get isAnonymous {
    final u = _auth.currentUser;
    if (u == null) return false;
    return u.isAnonymous;
  }

  bool get isAccount {
    final u = _auth.currentUser;
    if (u == null) return false;
    return !u.isAnonymous;
  }

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  /// 현재 익명 사용자를 그대로 두고 이메일/비밀번호만 부여해 영구 계정으로 전환.
  /// uid가 유지되므로 RLS로 묶인 데이터(pets/logs 등)가 그대로 사용자에 남아 있음.
  Future<UserResponse> convertGuestToAccount({
    required String email,
    required String password,
  }) {
    return _auth.updateUser(
      UserAttributes(email: email, password: password),
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  /// 로그아웃 후 다시 익명 세션을 시작해 앱이 항상 동작하도록 유지.
  Future<void> signOutToGuest() async {
    await _auth.signOut();
    await _auth.signInAnonymously();
  }
}
