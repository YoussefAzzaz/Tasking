import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;
  final bool rememberMe;

  const AuthSignInRequested({
    required this.email,
    required this.password,
    this.rememberMe = true,
  });

  @override
  List<Object?> get props => [email, password, rememberMe];
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String displayName;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.displayName,
  });

  @override
  List<Object?> get props => [email, password, displayName];
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}
