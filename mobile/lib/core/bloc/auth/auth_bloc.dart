import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axis/data/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

export 'auth_event.dart';
export 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc({AuthService? authService})
      : _authService = authService ?? AuthService(),
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignInRequested>(_onAuthSignInRequested);
    on<AuthSignUpRequested>(_onAuthSignUpRequested);
    on<AuthSignOutRequested>(_onAuthSignOutRequested);

    _authService.authStateNotifier.addListener(_syncAuthState);
  }

  void _syncAuthState() {
    if (!isClosed) {
      add(const AuthCheckRequested());
    }
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (_authService.hasActiveSession) {
      emit(Authenticated(
        userId: _authService.currentUserId ?? '',
        email: _authService.userEmail ?? '',
        displayName: _authService.displayName,
        isOfflineSession: _authService.currentSession == null,
      ));
    } else {
      emit(const Unauthenticated());
    }
  }

  Future<void> _onAuthSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final res = await _authService.signIn(
        email: event.email,
        password: event.password,
        rememberMe: event.rememberMe,
      );
      emit(Authenticated(
        userId: res.user?.id ?? _authService.currentUserId ?? '',
        email: res.user?.email ?? event.email,
        displayName: _authService.displayName,
      ));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final res = await _authService.signUp(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );
      emit(Authenticated(
        userId: res.user?.id ?? _authService.currentUserId ?? '',
        email: res.user?.email ?? event.email,
        displayName: event.displayName,
      ));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.signOut();
      emit(const Unauthenticated());
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _authService.authStateNotifier.removeListener(_syncAuthState);
    return super.close();
  }
}
