import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';
import 'package:axis/ui/me/widgets/user_profile_card.dart';
import 'package:axis/ui/me/widgets/image_crop_dialog.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('Default UserProfile has null avatarUrl', () {
      const profile = UserProfile();
      expect(profile.avatarUrl, isNull);
      expect(profile.name, 'Commander');
      expect(profile.level, 1);
    });

    test('UserProfile copyWith updates avatarUrl correctly', () {
      const profile = UserProfile(name: 'Leo');
      final updated = profile.copyWith(avatarUrl: 'https://cdn.example.com/avatar.webp');
      expect(updated.name, 'Leo');
      expect(updated.avatarUrl, 'https://cdn.example.com/avatar.webp');

      final cleared = updated.copyWith(clearAvatarUrl: true);
      expect(cleared.avatarUrl, isNull);
    });
  });

  group('AvatarWidget Widget Tests', () {
    testWidgets('Renders initials fallback when avatarUrl is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              name: 'John Doe',
              size: 60,
            ),
          ),
        ),
      );

      expect(find.text('JD'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Renders first letters for single word name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              name: 'Commander',
              size: 60,
            ),
          ),
        ),
      );

      expect(find.text('CO'), findsOneWidget);
    });

    testWidgets('Renders uploading overlay when isUploading is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              name: 'Sarah Connor',
              size: 60,
              isUploading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Renders edit badge when showEditBadge is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              name: 'Nova Prime',
              size: 60,
              showEditBadge: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    });

    testWidgets('Triggers onTap callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              name: 'Pilot',
              size: 60,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AvatarWidget));
      expect(tapped, isTrue);
    });

    testWidgets('Handles Arabic name and unusual hex color formats safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AvatarWidget(
                  name: 'أحمد علي',
                  avatarColor: '#00FF66',
                ),
                AvatarWidget(
                  name: 'مريم',
                  avatarColor: '0xFF6366F1',
                ),
                AvatarWidget(
                  name: '',
                  avatarColor: 'invalid_hex',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(AvatarWidget), findsNWidgets(3));
    });
  });

  group('UserProfileCard Avatar Integration Tests', () {
    testWidgets('UserProfileCard renders AvatarWidget with user data and edit badge', (tester) async {
      var avatarTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserProfileCard(
              userName: 'Aiden Pearce',
              userTitle: 'Network Architect',
              level: 5,
              totalXp: 1200,
              onSaveProfile: (name, title) {},
              onAvatarTap: () => avatarTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Aiden Pearce'), findsOneWidget);
      expect(find.text('Network Architect'), findsOneWidget);
      expect(find.text('Level 5 • 1200 XP'), findsOneWidget);
      expect(find.byType(AvatarWidget), findsOneWidget);
      expect(find.text('AP'), findsOneWidget);

      await tester.tap(find.byType(AvatarWidget));
      expect(avatarTapped, isTrue);
    });
  });

  group('ImageCropDialog Widget Tests', () {
    testWidgets('Renders Crop & Reframe dialog with controls and viewfinder', (tester) async {
      // 10x10 transparent 1-pixel PNG bytes for testing
      final testPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageCropDialog(imageBytes: testPngBytes),
          ),
        ),
      );

      expect(find.text('Crop & Reframe'), findsOneWidget);
      expect(find.text('Pinch or drag to align avatar in frame'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Rotate 0°'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Apply & Save'), findsOneWidget);

      // Tap rotate button
      await tester.tap(find.text('Rotate 0°'));
      await tester.pump();
      expect(find.text('Rotate 90°'), findsOneWidget);

      // Tap reset button
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(find.text('Rotate 0°'), findsOneWidget);
    });
  });

  group('Reactive profileNotifier Tests', () {
    test('profileNotifier emits updates when profile changes', () {
      final repo = UserProfileRepository();
      UserProfile? lastProfile;
      repo.profileNotifier.addListener(() {
        lastProfile = repo.profileNotifier.value;
      });

      repo.profileNotifier.value = const UserProfile(
        name: 'Neo',
        avatarUrl: 'https://example.com/pfp.png',
      );

      expect(lastProfile?.name, 'Neo');
      expect(lastProfile?.avatarUrl, 'https://example.com/pfp.png');
    });
  });
}
