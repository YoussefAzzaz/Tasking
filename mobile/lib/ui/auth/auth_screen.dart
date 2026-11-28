import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axis/core/bloc/blocs.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/powersync_db.dart' show isDatabaseInitialized;
import 'package:axis/ui/auth/widgets/desktop_auth_view.dart';
import 'package:axis/ui/auth/widgets/mobile_auth_view.dart';

export 'package:axis/ui/auth/widgets/auth_text_field.dart';
export 'package:axis/ui/auth/widgets/auth_form_components.dart';
export 'package:axis/ui/auth/widgets/auth_ambient_glows.dart';
export 'package:axis/ui/auth/widgets/desktop_auth_view.dart';
export 'package:axis/ui/auth/widgets/mobile_auth_view.dart';
export 'package:axis/ui/auth/widgets/auth_language_switcher.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = true;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _populateSavedCredentials();
  }

  Future<void> _populateSavedCredentials() async {
    final auth = AuthService();
    await auth.loadPersistentCredentials(forceReload: true);
    if (auth.savedEmail == null && isDatabaseInitialized) {
      await auth.init();
    }
    final savedEmail = auth.savedEmail;
    final savedPass = auth.getDecryptedPassword();
    if (mounted && ((savedEmail != null && savedEmail.isNotEmpty) || (savedPass != null && savedPass.isNotEmpty))) {
      setState(() {
        _rememberMe = true;
        if (savedEmail != null && savedEmail.isNotEmpty && _emailCtrl.text.isEmpty) {
          _emailCtrl.text = savedEmail;
        }
        if (savedPass != null && savedPass.isNotEmpty && _passwordCtrl.text.isEmpty) {
          _passwordCtrl.text = savedPass;
        }
      });
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    AuthBloc? bloc;
    try {
      bloc = context.read<AuthBloc>();
    } catch (_) {}

    try {
      if (bloc != null) {
        final completer = Completer<void>();
        StreamSubscription<AuthState>? sub;
        try {
          sub = bloc.stream.listen((state) {
            if (state is Authenticated) {
              if (!completer.isCompleted) completer.complete();
            } else if (state is AuthFailure) {
              if (!completer.isCompleted) completer.completeError(state.message);
            }
          });

          if (_isSignUp) {
            bloc.add(AuthSignUpRequested(
              email: _emailCtrl.text,
              password: _passwordCtrl.text,
              displayName: _nameCtrl.text,
            ));
          } else {
            bloc.add(AuthSignInRequested(
              email: _emailCtrl.text,
              password: _passwordCtrl.text,
              rememberMe: _rememberMe,
            ));
          }
          await completer.future.timeout(const Duration(seconds: 25));
        } finally {
          await sub?.cancel();
        }
      } else {
        if (_isSignUp) {
          await AuthService().signUp(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            displayName: _nameCtrl.text,
          );
        } else {
          await AuthService().signIn(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            rememberMe: _rememberMe,
          );
        }
      }

      if (!mounted) return;

      // Navigate to main application shell
      context.go('/today');
    } catch (e) {
      if (!mounted) return;
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      setState(() {
        _errorMessage = _cleanErrorMessage(e.toString(), isAr);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _cleanErrorMessage(String err, bool isArabic) {
    if (err.contains('Invalid login credentials')) {
      return isArabic
          ? 'بيانات الاعتماد غير صحيحة. يرجى التحقق من البريد الإلكتروني وكلمة المرور.'
          : 'Invalid email or password. Please verify your credentials.';
    }
    if (err.contains('User already registered')) {
      return isArabic
          ? 'يوجد حساب مسجل بهذا البريد الإلكتروني مسبقاً. يرجى تسجيل الدخول بدلاً من ذلك.'
          : 'An account with this email already exists. Please sign in instead.';
    }
    if (err.contains('Password should be at least')) {
      return isArabic
          ? 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.'
          : 'Password must contain at least 6 characters.';
    }
    if (err.contains('TimeoutException') || err.toLowerCase().contains('timed out')) {
      return isArabic
          ? 'انتهت مهلة الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت والمحاولة مجدداً.'
          : 'Connection timed out. Please check your internet connection and try again.';
    }
    if (err.contains('SocketException') ||
        err.contains('Failed host lookup') ||
        err.contains('ClientException') ||
        err.contains('AuthRetryableFetchException')) {
      return isArabic
          ? 'الاتصال بالإنترنت غير متاح. اضغط على "المتابعة في وضع عدم الاتصال" للمتابعة.'
          : 'Network connection unavailable. Tap "Continue in Offline Mode" below to proceed offline.';
    }
    if (err.contains('over_email_send_rate_limit') || err.contains('rate limit exceeded')) {
      return isArabic
          ? 'تم تجاوز حد إرسال رسائل البريد الإلكتروني في Supabase. في لوحة تحكم Supabase -> Auth -> Providers -> Email، قم بإيقاف "Confirm email" لتفعيل التسجيل الفوري.'
          : 'Supabase email send limit reached. In Supabase Dashboard -> Auth -> Providers -> Email, turn off "Confirm email" to enable instant signup.';
    }
    return err.replaceAll('Exception:', '').replaceAll('AuthException:', '').trim();
  }

  Future<void> _continueOffline() async {
    if (AuthService().isGuest) {
      context.go('/today');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthService().saveLocalSession(
        userId: 'local_guest',
        email: 'guest@tasking.local',
        displayName: 'Guest Operative',
      );
      if (!mounted) return;
      context.go('/today');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to initialize offline session: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopPlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final isDesktop = isDesktopPlatform || MediaQuery.sizeOf(context).width >= 1024;

    if (isDesktop) {
      return DesktopAuthView(
        formKey: _formKey,
        fadeAnim: _fadeAnim,
        isSignUp: _isSignUp,
        obscurePassword: _obscurePassword,
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        nameCtrl: _nameCtrl,
        emailCtrl: _emailCtrl,
        passwordCtrl: _passwordCtrl,
        onModeChanged: (val) {
          setState(() {
            _isSignUp = val;
            _errorMessage = null;
          });
        },
        onTogglePasswordVisibility: () {
          setState(() {
            _obscurePassword = !_obscurePassword;
          });
        },
        rememberMe: _rememberMe,
        onRememberMeChanged: (val) => setState(() => _rememberMe = val),
        onSubmit: _submit,
        onContinueOffline: _continueOffline,
      );
    }

    return MobileAuthView(
      formKey: _formKey,
      fadeAnim: _fadeAnim,
      isSignUp: _isSignUp,
      obscurePassword: _obscurePassword,
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      nameCtrl: _nameCtrl,
      emailCtrl: _emailCtrl,
      passwordCtrl: _passwordCtrl,
      onModeChanged: (val) {
        setState(() {
          _isSignUp = val;
          _errorMessage = null;
        });
      },
      onTogglePasswordVisibility: () {
        setState(() {
          _obscurePassword = !_obscurePassword;
        });
      },
      rememberMe: _rememberMe,
      onRememberMeChanged: (val) => setState(() => _rememberMe = val),
      onSubmit: _submit,
      onContinueOffline: _continueOffline,
    );
  }
}
