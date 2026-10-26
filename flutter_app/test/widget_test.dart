import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:writescan_ai/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('WriteScanApp builds without white screen or unhandled exceptions', (WidgetTester tester) async {
    // Configure standard mobile portrait viewport dimensions to avoid any overflow during render
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build the app within a ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: WriteScanApp(),
      ),
    );

    // Initial settle
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify title and main UI components are present on Scanner screen
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

    // Verify Settings Screen renders with active Standalone Inbuilt Offline mode
    expect(find.text('Settings & Diagnostics'), findsOneWidget);
    expect(find.text('OCR Engine Selection'), findsOneWidget);
    expect(find.text('Inbuilt Offline Mode Active'), findsOneWidget);

    // Switch to Cloud Gemini Vision OCR to verify backend connectivity controls
    final cloudEngineFinder = find.text('Cloud Gemini Vision OCR');
    if (cloudEngineFinder.evaluate().isNotEmpty) {
      await tester.tap(cloudEngineFinder);
      await tester.pumpAndSettle();

      expect(find.text('OCR Backend Connectivity'), findsOneWidget);
      expect(find.text('Test Backend Connection'), findsOneWidget);
    }
  });
}
