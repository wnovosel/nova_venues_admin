import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_venues_admin/design_system/nova_components.dart';
import 'package:nova_venues_admin/design_system/nova_navigation_shell.dart';
import 'package:nova_venues_admin/main.dart';
import 'package:nova_venues_admin/models/app_provider.dart';
import 'package:nova_venues_admin/screens/events/events_screen.dart';
import 'package:nova_venues_admin/theme/appearance_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureValues = <String, String>{};

  setUp(() {
    secureValues.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final arguments = Map<String, dynamic>.from(
          call.arguments as Map? ?? const {},
        );
        final key = arguments['key'] as String?;
        switch (call.method) {
          case 'read':
            return key == null ? null : secureValues[key];
          case 'write':
            if (key != null) {
              secureValues[key] = arguments['value'] as String;
            }
            return null;
          case 'delete':
            if (key != null) secureValues.remove(key);
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  testWidgets('appearance selector updates the app theme immediately', (
    tester,
  ) async {
    final appearance = AppearanceController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appearance,
        child: const MaterialApp(
          home: Scaffold(body: NovaAppearanceSelector()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(appearance.themeMode, ThemeMode.dark);
  });

  testWidgets('saved appearance is restored by a fresh controller', (
    tester,
  ) async {
    final first = AppearanceController();
    await tester.pump();
    await first.select(NovaAppearance.dark);

    final restored = AppearanceController();
    await tester.pump();

    expect(restored.ready, isTrue);
    expect(restored.appearance, NovaAppearance.dark);
    expect(restored.themeMode, ThemeMode.dark);
  });

  testWidgets('shell navigation selection matches visible hub', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider(create: (_) => AppearanceController()),
        ],
        child: const NovaAdminApp(home: NovaAppShell()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Operate').last);
    await tester.pumpAndSettle();
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Reservations'), findsOneWidget);

    await tester.tap(find.text('Grow').last);
    await tester.pumpAndSettle();
    expect(find.text('Marketing'), findsOneWidget);
    expect(find.text('Phone Assistant'), findsOneWidget);

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.byType(NovaAppearanceSelector), findsOneWidget);
  });

  testWidgets('open module remains mounted when switching tabs', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider(create: (_) => AppearanceController()),
        ],
        child: const NovaAdminApp(home: NovaAppShell()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Operate').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events'));
    await tester.pump();
    expect(find.byType(EventsScreen), findsOneWidget);

    await tester.tap(find.text('Grow').last);
    await tester.pumpAndSettle();
    expect(find.text('Marketing'), findsOneWidget);

    await tester.tap(find.text('Operate').last);
    await tester.pump();
    expect(find.byType(EventsScreen), findsOneWidget);
  });
}
