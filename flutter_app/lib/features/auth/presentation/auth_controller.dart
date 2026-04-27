import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;

import '../../../app/app_providers.dart';
import '../../../core/network/app_exception.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

class AuthState {
  const AuthState({
    this.isInitializing = false,
    this.isSubmitting = false,
    this.token,
    this.user,
    this.errorMessage,
  });

  final bool isInitializing;
  final bool isSubmitting;
  final String? token;
  final AuthUser? user;
  final String? errorMessage;

  bool get isAuthenticated => (token?.isNotEmpty ?? false) && user != null;

  AuthState copyWith({
    bool? isInitializing,
    bool? isSubmitting,
    String? token,
    AuthUser? user,
    String? errorMessage,
    bool clearToken = false,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      isInitializing: isInitializing ?? this.isInitializing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      token: clearToken ? null : (token ?? this.token),
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this.ref) : super(const AuthState(isInitializing: true)) {
    restoreSession();
  }

  final Ref ref;

  Future<void> restoreSession() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.readToken();

    if (token == null || token.isEmpty) {
      state = const AuthState(isInitializing: false);
      return;
    }

    try {
      final user = await ref.read(authRepositoryProvider).getMe();
      state = AuthState(
        isInitializing: false,
        token: token,
        user: user,
      );
    } catch (_) {
      await storage.clearToken();
      state = const AuthState(isInitializing: false);
    }
  }

  Future<bool> login({
    required String account,
    required String password,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
    );

    try {
      final session = await ref.read(authRepositoryProvider).login(
            account: account,
            password: password,
          );

      await ref.read(secureStorageProvider).writeToken(session.token);
      state = AuthState(
        isSubmitting: false,
        token: session.token,
        user: session.user,
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Login failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> refreshMe() async {
    if (!(state.token?.isNotEmpty ?? false)) {
      return;
    }

    try {
      final user = await ref.read(authRepositoryProvider).getMe();
      state = state.copyWith(user: user, clearError: true);
    } on AppException catch (error) {
      state = state.copyWith(errorMessage: error.message);
    }
  }

  Future<void> logout() async {
    await ref.read(secureStorageProvider).clearToken();
    state = const AuthState();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
