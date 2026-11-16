import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/ui/auth/auth_screen.dart';

void main() {
  group('AuthRememberMeButton Component Tests', () {
    testWidgets('renders check icon when value is true and toggles on tap', (tester) async {
      bool currentValue = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AuthRememberMeButton(
                  value: currentValue,
                  onChanged: (val) {
                    setState(() => currentValue = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify button and check icon
      expect(find.byKey(const ValueKey('auth_remember_me_button')), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('Remember me on this device'), findsOneWidget);

      // Tap to toggle
      await tester.tap(find.byKey(const ValueKey('auth_remember_me_button')));
      await tester.pumpAndSettle();

      expect(currentValue, isFalse);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });

  group('DesktopAuthView Remember Me Tests', () {
    testWidgets('displays Remember Me toggle on Sign In mode and hides on Sign Up mode', (tester) async {
      final formKey = GlobalKey<FormState>();
      final emailCtrl = TextEditingController();
      final passCtrl = TextEditingController();
      final nameCtrl = TextEditingController();
      late AnimationController animCtrl;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              animCtrl = AnimationController(vsync: const TestVSync(), duration: const Duration(milliseconds: 300));
              return DesktopAuthView(
                formKey: formKey,
                fadeAnim: animCtrl,
                isSignUp: false,
                obscurePassword: true,
                isLoading: false,
                errorMessage: null,
                nameCtrl: nameCtrl,
                emailCtrl: emailCtrl,
                passwordCtrl: passCtrl,
                rememberMe: true,
                onRememberMeChanged: (_) {},
                onModeChanged: (_) {},
                onTogglePasswordVisibility: () {},
                onSubmit: () {},
                onContinueOffline: () {},
              );
            },
          ),
        ),
      );

      expect(find.byKey(const ValueKey('auth_remember_me_button')), findsOneWidget);

      // Re-pump with isSignUp: true
      await tester.pumpWidget(
        MaterialApp(
          home: DesktopAuthView(
            formKey: formKey,
            fadeAnim: animCtrl,
            isSignUp: true,
            obscurePassword: true,
            isLoading: false,
            errorMessage: null,
            nameCtrl: nameCtrl,
            emailCtrl: emailCtrl,
            passwordCtrl: passCtrl,
            rememberMe: true,
            onRememberMeChanged: (_) {},
            onModeChanged: (_) {},
            onTogglePasswordVisibility: () {},
            onSubmit: () {},
            onContinueOffline: () {},
          ),
        ),
      );

      expect(find.byKey(const ValueKey('auth_remember_me_button')), findsNothing);
      animCtrl.dispose();
    });
  });

  group('MobileAuthView Remember Me Tests', () {
    testWidgets('displays Remember Me toggle on Sign In mode and hides on Sign Up mode', (tester) async {
      final formKey = GlobalKey<FormState>();
      final emailCtrl = TextEditingController();
      final passCtrl = TextEditingController();
      final nameCtrl = TextEditingController();
      final animCtrl = AnimationController(vsync: const TestVSync(), duration: const Duration(milliseconds: 300));

      await tester.pumpWidget(
        MaterialApp(
          home: MobileAuthView(
            formKey: formKey,
            fadeAnim: animCtrl,
            isSignUp: false,
            obscurePassword: true,
            isLoading: false,
            errorMessage: null,
            nameCtrl: nameCtrl,
            emailCtrl: emailCtrl,
            passwordCtrl: passCtrl,
            rememberMe: true,
            onRememberMeChanged: (_) {},
            onModeChanged: (_) {},
            onTogglePasswordVisibility: () {},
            onSubmit: () {},
            onContinueOffline: () {},
          ),
        ),
      );

      expect(find.byKey(const ValueKey('auth_remember_me_button')), findsOneWidget);

      // Re-pump with isSignUp: true
      await tester.pumpWidget(
        MaterialApp(
          home: MobileAuthView(
            formKey: formKey,
            fadeAnim: animCtrl,
            isSignUp: true,
            obscurePassword: true,
            isLoading: false,
            errorMessage: null,
            nameCtrl: nameCtrl,
            emailCtrl: emailCtrl,
            passwordCtrl: passCtrl,
            rememberMe: true,
            onRememberMeChanged: (_) {},
            onModeChanged: (_) {},
            onTogglePasswordVisibility: () {},
            onSubmit: () {},
            onContinueOffline: () {},
          ),
        ),
      );

      expect(find.byKey(const ValueKey('auth_remember_me_button')), findsNothing);
      animCtrl.dispose();
    });
  });

  group('AuthScreen Integration Tests', () {
    testWidgets('AuthScreen desktop toggles Remember Me correctly and adapts to signup', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Remember Me button is present and starts checked
      expect(find.byKey(const ValueKey('auth_remember_me_button')), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Tap Remember Me button
      await tester.tap(find.byKey(const ValueKey('auth_remember_me_button')));
      await tester.pumpAndSettle();

      // Checkbox is now unchecked
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // Switch to CREATE ACCOUNT
      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();

      // Remember Me button should be hidden
      expect(find.byKey(const ValueKey('auth_remember_me_button')), findsNothing);

      // Switch back to SIGN IN
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();

      // Remember Me button should reappear
      expect(find.byKey(const ValueKey('auth_remember_me_button')), findsOneWidget);
    });

    testWidgets('AuthScreen mobile toggles Remember Me correctly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Remember Me button is present and starts checked
      expect(find.byKey(const ValueKey('auth_remember_me_button')), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Tap Remember Me button
      await tester.tap(find.byKey(const ValueKey('auth_remember_me_button')));
      await tester.pumpAndSettle();

      // Checkbox is now unchecked
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });
}
