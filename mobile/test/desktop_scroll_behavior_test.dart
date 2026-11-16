import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/desktop_scroll_behavior.dart';

void main() {
  group('DesktopScrollBehavior unit & widget tests', () {
    test('dragDevices excludes mouse to avoid mobile touch drag on desktop', () {
      const behavior = DesktopScrollBehavior();
      final devices = behavior.dragDevices;

      expect(devices.contains(PointerDeviceKind.mouse), isFalse);
      expect(devices.contains(PointerDeviceKind.touch), isTrue);
      expect(devices.contains(PointerDeviceKind.trackpad), isTrue);
    });

    testWidgets('horizontal scrollable scrolls with mouse wheel without holding Shift', (tester) async {
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const DesktopScrollBehavior(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 100,
              child: ListView.builder(
                controller: controller,
                scrollDirection: Axis.horizontal,
                itemCount: 50,
                itemBuilder: (context, index) => SizedBox(
                  width: 80,
                  child: Text('Item $index'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.offset, 0.0);

      // Simulate mouse wheel vertical scroll (dy = 120.0, dx = 0.0, no Shift)
      final center = tester.getCenter(find.byType(ListView));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);

      // Send hover to position mouse
      await tester.sendEventToBinding(pointer.hover(center));
      await tester.pump();

      // Dispatch vertical scroll event from mouse wheel
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pumpAndSettle();

      // Should have scrolled horizontally without holding Shift!
      expect(controller.offset, greaterThan(0.0));
    });

    testWidgets('scrolling over nested scrollable with mouse wheel does not crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const DesktopScrollBehavior(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  SizedBox(
                    height: 200,
                    child: Scrollbar(
                      child: GridView.builder(
                        itemCount: 20,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                        ),
                        itemBuilder: (context, i) => Text('Item $i'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gridCenter = tester.getCenter(find.byType(GridView));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(gridCenter));
      await tester.pump();
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      await tester.pumpAndSettle();
    });
  });
}
