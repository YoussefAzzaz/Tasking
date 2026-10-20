import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';

void main() {
  testWidgets('AxisCard renders child properly with dark theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: const Scaffold(
          body: AxisCard(
            tier: GlassTier.two,
            child: Text('AXIS KINETIC TEST'),
          ),
        ),
      ),
    );

    expect(find.text('AXIS KINETIC TEST'), findsOneWidget);
    expect(find.byType(AxisCard), findsOneWidget);
  });
}
