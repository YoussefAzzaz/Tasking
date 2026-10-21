import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
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
        );
      }

      if (!mounted) return;

      // Navigate to main application shell
      context.go('/today');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _cleanErrorMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _cleanErrorMessage(String err) {
    if (err.contains('Invalid login credentials')) {
      return 'Invalid email or password. Please verify your credentials.';
    }
    if (err.contains('User already registered')) {
      return 'An account with this email already exists. Please sign in instead.';
    }
    if (err.contains('Password should be at least')) {
      return 'Password must contain at least 6 characters.';
    }
    if (err.contains('SocketException') || err.contains('Failed host lookup')) {
      return 'Network connection unavailable. Tap "Continue in Offline Mode" below to proceed offline.';
    }
    if (err.contains('over_email_send_rate_limit') || err.contains('rate limit exceeded')) {
      return 'Supabase email send limit reached. In Supabase Dashboard -> Auth -> Providers -> Email, turn off "Confirm email" to enable instant signup.';
    }
    return err.replaceAll('Exception:', '').replaceAll('AuthException:', '').trim();
  }

  Future<void> _continueOffline() async {
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      body: Stack(
        children: [
          // Ambient Background Glows
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AxisColors.primary.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: AxisColors.primary.withValues(alpha: 0.25),
                    blurRadius: 90,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AxisColors.secondary.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: AxisColors.secondary.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // Main Interactive Scroll Canvas
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 20,
                  bottom: bottomInset > 0 ? bottomInset + 20 : 32,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Brand & Logo Badge
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AxisColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.cover,
                                cacheWidth: 128,
                                cacheHeight: 128,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Center(
                          child: Text(
                            'AXIS',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: AxisColors.textHigh,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3.5,
                                ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        Center(
                          child: Text(
                            'OFFLINE-FIRST CLOUD SYNC & AUTH',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AxisColors.primarySoft,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.6,
                                ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Tab Switcher: Sign In vs Sign Up
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AxisColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isSignUp = false;
                                      _errorMessage = null;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_isSignUp
                                          ? AxisColors.primary.withValues(alpha: 0.22)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: !_isSignUp
                                          ? Border.all(color: AxisColors.primary.withValues(alpha: 0.6))
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'SIGN IN',
                                      style: TextStyle(
                                        color: !_isSignUp ? AxisColors.primarySoft : AxisColors.textDim,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isSignUp = true;
                                      _errorMessage = null;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isSignUp
                                          ? AxisColors.primary.withValues(alpha: 0.22)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: _isSignUp
                                          ? Border.all(color: AxisColors.primary.withValues(alpha: 0.6))
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'CREATE ACCOUNT',
                                      style: TextStyle(
                                        color: _isSignUp ? AxisColors.primarySoft : AxisColors.textDim,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Error Banner if present
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AxisColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AxisColors.error.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AxisColors.error, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AxisColors.textHigh,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Display Name Field (SignUp only)
                        if (_isSignUp) ...[
                          _buildTextField(
                            controller: _nameCtrl,
                            hint: 'Full Name or Call-Sign',
                            label: 'OPERATOR NAME',
                            icon: Icons.person_outline_rounded,
                            validator: (val) {
                              if (_isSignUp && (val == null || val.trim().isEmpty)) {
                                return 'Enter your name or operator call-sign';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email Field
                        _buildTextField(
                          controller: _emailCtrl,
                          hint: 'name@example.com',
                          label: 'SYSTEM EMAIL',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!val.contains('@') || !val.contains('.')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password Field
                        _buildTextField(
                          controller: _passwordCtrl,
                          hint: '••••••••',
                          label: 'ACCESS PASSCODE',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AxisColors.textDim,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Password is required';
                            }
                            if (val.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        GestureDetector(
                          onTap: _isLoading ? null : _submit,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AxisColors.primary, AxisColors.secondary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AxisColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isSignUp ? Icons.person_add_rounded : Icons.login_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isSignUp ? 'REGISTER ACCOUNT' : 'ENTER SYSTEM',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.4,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Offline Mode fallback entrance
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _continueOffline,
                            icon: const Icon(Icons.cloud_off_rounded,
                                size: 16, color: AxisColors.textMuted),
                            label: const Text(
                              'CONTINUE IN OFFLINE MODE',
                              style: TextStyle(
                                color: AxisColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.1,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AxisColors.borderSubtle),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Isolation & PowerSync Architecture notice
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shield_outlined,
                                color: AxisColors.tertiary, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'PowerSync user_id isolation active',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AxisColors.textDim,
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: AxisColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AxisColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AxisColors.borderSubtle),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            style: const TextStyle(
              color: AxisColors.textHigh,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AxisColors.textDim, fontSize: 13),
              prefixIcon: Icon(icon, color: AxisColors.primarySoft, size: 18),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
