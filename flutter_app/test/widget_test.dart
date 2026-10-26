import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:writescan_ai/app.dart';
import 'package:writescan_ai/core/theme/app_theme.dart';

void main() {
  group('AppTheme Tests', () {
    test('lightTheme has Material 3 enabled and pristine visual styling', () {
      final theme = AppTheme.lightTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, isNotNull);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
    });

    test('darkTheme has Material 3 enabled and deep slate visual styling', () {
      final theme = AppTheme.darkTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, isNotNull);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0B1329));
    });
  });

  group('WriteScan AI Application Tests', () {
    testWidgets('WriteScanApp builds and renders main scanner UI cleanly', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(
          child: WriteScanApp(),
        ),
      );

      // Bounded pumps allow widget tree and async initialization to resolve without timeout
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Verify Scanner header & primary action buttons
      expect(find.text('WriteScan AI'), findsOneWidget);
      expect(find.text('Capture with Camera'), findsOneWidget);
      expect(find.text('Import from Gallery'), findsOneWidget);

      // Verify Bottom Navigation Bar destinations
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Scanner'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('NavigationBar smoothly switches between Scanner, History, and Settings', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(
          child: WriteScanApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Switch to History tab
      await tester.tap(find.text('History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Document History'), findsOneWidget);

      // Switch to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Settings & Diagnostics'), findsOneWidget);
      expect(find.text('OCR Engine Selection'), findsOneWidget);
      expect(find.text('Inbuilt Offline Mode Active'), findsOneWidget);
    });
  });
}
