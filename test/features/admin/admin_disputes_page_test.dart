import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/admin/admin_repository.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/features/admin/admin_disputes_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _AdminDisputesRepository extends Fake implements AdminRepository {
  @override
  Future<List<Map<String, dynamic>>> listDisputes() async => const [];

  @override
  Future<Map<String, dynamic>> getPanelAccess() async => const {
        'verified': true,
        'permissions': <String>[],
      };
}

void main() {
  testWidgets('admin disputes page uses a compact editorial page tail',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Provider<AdminRepository>.value(
          value: _AdminDisputesRepository(),
          child: const AdminDisputesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<PremiumPageFrame>(find.byType(PremiumPageFrame)).padding.bottom,
      24,
    );
    expect(find.text('No dispute cases need attention'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
