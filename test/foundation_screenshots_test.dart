import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_venues_admin/design_system/nova_app_shell.dart';
import 'package:nova_venues_admin/main.dart';
import 'package:nova_venues_admin/models/app_provider.dart';
import 'package:nova_venues_admin/screens/inbox/inbox_screen.dart';
import 'package:nova_venues_admin/theme/app_theme.dart';
import 'package:nova_venues_admin/theme/appearance_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'read' ? null : true,
        );
  });

  Future<void> pumpShell(
    WidgetTester tester,
    AppearanceController appearance,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider.value(value: appearance),
        ],
        child: const RepaintBoundary(
          key: Key('capture'),
          child: NovaAdminApp(home: NovaAppShell()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('captures foundation review screenshots', (tester) async {
    final appearance = AppearanceController();
    await pumpShell(tester, appearance);

    await tester.tap(find.text('Operate').last);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/light_app_shell.png'),
    );

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/light_appearance_selector.png'),
    );

    await tester.tap(find.byIcon(Icons.inbox_outlined));
    await tester.pump();
    await tester.pump(NovaMotion.emphasized);
    expect(find.byType(InboxScreen), findsOneWidget);
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/light_existing_inbox_screen.png'),
    );

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();

    await appearance.select(NovaAppearance.dark);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/dark_appearance_selector.png'),
    );

    await tester.tap(find.text('Operate').last);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/dark_app_shell.png'),
    );

    await tester.tap(find.byIcon(Icons.inbox_outlined));
    await tester.pump();
    await tester.pump(NovaMotion.emphasized);
    expect(find.byType(InboxScreen), findsOneWidget);
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/dark_existing_inbox_screen.png'),
    );
  });
}
