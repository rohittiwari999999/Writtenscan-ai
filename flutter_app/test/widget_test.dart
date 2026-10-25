import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:writescan_ai/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('WriteScanApp builds without white screen or unhandled exceptions', (WidgetTester tester) async {
    // Build the app within a ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: WriteScanApp(),
      ),
    );

    // Initial settle
    await tester.pumpAndSettle();

    // Verify title and main UI components are present
    expect(find.text('WriteScan AI'), findsOneWidget);
    expect(find.text('Capture with Camera'), findsOneWidget);
    expect(find.text('Import from Gallery'), findsOneWidget);

    // Verify Bottom Navigation Bar items
    expect(find.text('Scanner'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Tap on History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // Verify History Screen renders
    expect(find.text('Document History'), findsOneWidget);

    // Tap on Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Verify Settings Screen renders with OCR Backend Connectivity card
    expect(find.text('Settings & Diagnostics'), findsOneWidget);
    expect(find.text('OCR Backend Connectivity'), findsOneWidget);
    expect(find.text('Test Backend Connection'), findsOneWidget);
  });
}
