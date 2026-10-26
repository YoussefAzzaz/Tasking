import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final String userId;
  final String email;
  final String displayName;
  final bool isOfflineSession;

  const Authenticated({
    required this.userId,
    required this.email,
    required this.displayName,
    this.isOfflineSession = false,
  });

  @override
  List<Object?> get props => [userId, email, displayName, isOfflineSession];
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}
