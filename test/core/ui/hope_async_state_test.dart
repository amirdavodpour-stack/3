import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/hope_async_state.dart';
import 'package:hope_mobile/core/ui/components.dart';

void main() {
  testWidgets('all async state kinds expose a deterministic semantic contract',
      (tester) async {
    for (final kind in HopeStateKind.values) {
      final title = 'State ${kind.name}';
      final message = 'Message ${kind.name}';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: HopeAsyncState(
              kind: kind,
              title: title,
              message: message,
            ),
          ),
        ),
      );
      await tester.pump();

      final semantics = tester.getSemantics(find.byType(HopeAsyncState));
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
      expect(semantics.label, '$title. $message');
    }
  });

  testWidgets('pending async state uses the canonical warning semantic token',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: HopeAsyncState(
            kind: HopeStateKind.pending,
            title: 'در انتظار',
            message: 'در حال پردازش',
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(HopeV2Icons.pending));
    expect(icon.color, HopeV2Colors.warning);
  });

  testWidgets('async state exposes a single live semantic announcement',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: HopeAsyncState(
            kind: HopeStateKind.error,
            title: 'خطا',
            message: 'دوباره تلاش کنید',
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(HopeAsyncState));
    expect(semantics.flagsCollection.isLiveRegion, isTrue);
    expect(semantics.label, 'خطا. دوباره تلاش کنید');
  });

  testWidgets('loading state removes animated spinner when reduced motion is enabled',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: HopeAsyncState(
              kind: HopeStateKind.loading,
              title: 'در حال بارگذاری',
              message: 'لطفاً صبر کنید',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(HopeV2Icons.pending), findsOneWidget);
  });

  test('maps transport and authorization failures to truthful state kinds',
      () {
    expect(
      hopeStateKindForError(ApiException('NETWORK_ERROR', 'network')),
      HopeStateKind.offline,
    );
    expect(
      hopeStateKindForError(ApiException('TIMEOUT', 'timeout')),
      HopeStateKind.offline,
    );
    expect(
      hopeStateKindForError(ApiException('UNAUTHENTICATED', 'auth')),
      HopeStateKind.unauthorized,
    );
    expect(
      hopeStateKindForError(ApiException('FORBIDDEN', 'forbidden')),
      HopeStateKind.forbidden,
    );
    expect(
      hopeStateKindForError(ApiException('RATE_LIMITED', 'limited')),
      HopeStateKind.rateLimited,
    );
    expect(
      hopeStateKindForError(StateError('unknown')),
      HopeStateKind.error,
    );
  });

  testWidgets('semantic error state uses the compact kinetic glyph frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: HopeAsyncState(
            kind: HopeStateKind.error,
            title: 'Connection failed',
            message: 'Try again when the service is available.',
          ),
        ),
      ),
    );

    expect(find.byType(HopeKineticGlyph), findsOneWidget);
    expect(find.byIcon(HopeV2Icons.error), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('async state action is constrained to the shared touch minimum',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HopeAsyncState(
            kind: HopeStateKind.error,
            title: 'خطا',
            message: 'دوباره تلاش کنید',
            action: FilledButton(
              onPressed: () {},
              child: const Text('تلاش دوباره'),
            ),
          ),
        ),
      ),
    );

    final button = find.byType(FilledButton);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(HopeV2Touch.minimum));
  });

  testWidgets('successful async state uses the botanical green peer accent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: HopeAsyncState(
            kind: HopeStateKind.success,
            title: 'Complete',
            message: 'The operation completed.',
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(HopeV2Icons.success));
    expect(icon.color, HopeV2TonalPalettes.forest.shade300);
    expect(tester.takeException(), isNull);
  });

}
