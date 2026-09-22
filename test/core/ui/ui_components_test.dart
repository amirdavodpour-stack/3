import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:hope_mobile/core/ui/components.dart";
import "package:hope_mobile/core/ui/premium_components.dart";
import "package:hope_mobile/l10n/generated/app_localizations.dart";
import "package:hope_mobile/core/theme/app_theme.dart";

MaterialApp _app(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale("fa"),
      supportedLocales: const [Locale("fa"), Locale("en")],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

void main() {
  testWidgets("premium components render with accessible semantics",
      (tester) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                StatusPill("منتشر شده",
                    icon: Icons.check_circle_outline_rounded),
                HopeIconTile(Icons.work_rounded),
                SearchField(onChanged: _noop),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("منتشر شده"), findsOneWidget);
    expect(find.byIcon(Icons.work_rounded), findsOneWidget);
    expect(find.bySemanticsLabel("جست‌وجو..."), findsOneWidget);
  });

  testWidgets("premium hero follows RTL text alignment", (tester) async {
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: PremiumHero(
              eyebrow: "فرصت‌ها",
              title: "فرصت‌های کاری",
              message: "فرصت‌های موجود",
              height: 260,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text("فرصت‌های کاری");
    expect(title, findsOneWidget);
    final left = tester.getTopLeft(title).dx;
    final right = tester.getBottomRight(title).dx;
    expect(right, greaterThan(520));
    expect(left, greaterThan(300));
  });

  testWidgets("section title stacks action on narrow screens",
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SectionTitle(
              title: "فرصت‌ها",
              subtitle: "آخرین فرصت‌های کاری",
              action: TextButton(onPressed: _noopAction, child: Text("مشاهده همه")),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleTop = tester.getTopLeft(find.text("فرصت‌ها")).dy;
    final actionTop = tester.getTopLeft(find.text("مشاهده همه")).dy;
    expect(actionTop, greaterThan(titleTop));
  });

  testWidgets("pressable scale exposes button semantics", (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: PressableScale(
            semanticLabel: "عمل آزمایشی",
            onTap: () => tapped = true,
            child: const Text("انجام"),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel("عمل آزمایشی"), findsOneWidget);
    await tester.tap(find.text("انجام"));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets("shared motion primitives honor reduced-motion", (tester) async {
      await tester.pumpWidget(
        _app(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Column(
              children: [
                AnimatedEntrance(child: Text("motion content")),
                SkeletonBox(width: 120, height: 20),
                PressableScale(
                  semanticLabel: "آزمایشی",
                  onTap: () {},
                  child: const SizedBox(width: 48, height: 48),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
  
      expect(find.text("motion content"), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder), findsNothing);
      expect(find.byType(AnimatedBuilder), findsNothing);
      expect(find.byType(AnimatedScale), findsNothing);
    });
}

void _noop(String _) {}
void _noopAction() {}
