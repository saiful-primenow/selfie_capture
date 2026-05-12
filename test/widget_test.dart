import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfie_capture/main.dart';

void main() {
  testWidgets('Home screen renders camera actions', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Camera Dashboard'), findsOneWidget);
    expect(find.text('Check Liveness'), findsOneWidget);
    expect(find.text('Capture NID'), findsOneWidget);
  });
}
