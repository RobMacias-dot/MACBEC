import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import 'auth_state.dart';

enum AuthStartupDestination {
  welcome,
  login,
  dashboard,
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authRepository) : super(const AuthState.initial());

  final AuthRepository _authRepository;

  Future<AuthStartupDestination> resolveStartupDestination() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final sessionUser = await _authRepository.restoreSession();
      if (sessionUser != null) {
        state = AuthState(
          isLoading: false,
          isAuthenticated: true,
          user: sessionUser,
        );
        return AuthStartupDestination.dashboard;
      }

      final hasAdmin = await _authRepository.hasAdminUser();
      state = const AuthState.initial();

      return hasAdmin
          ? AuthStartupDestination.login
          : AuthStartupDestination.welcome;
    } catch (_) {
      state = const AuthState.initial();
      return AuthStartupDestination.welcome;
    }
  }

  Future<bool> createInitialAdmin({
    required String fullName,
    required String email,
    required String pin,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _authRepository.createInitialAdmin(
        fullName: fullName,
        email: email,
        pin: pin,
      );

      state = AuthState(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );

      return true;
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: error.message,
        clearUser: true,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: 'No se pudo crear el administrador inicial.',
        clearUser: true,
      );
      return false;
    }
  }

  Future<bool> signInLocal({
    required String email,
    required String pin,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _authRepository.signInLocal(
        email: email,
        pin: pin,
      );

      state = AuthState(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );

      return true;
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: error.message,
        clearUser: true,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: 'No se pudo iniciar sesión.',
        clearUser: true,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    state = const AuthState.initial();
  }
}
