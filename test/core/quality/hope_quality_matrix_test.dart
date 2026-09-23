import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

void main() {
  testWidgets(
    'premium controls survive the core accessibility presentation matrix',
    (tester) async {
      for (final brightness in Brightness.values) {
        for (final direction in TextDirection.values) {
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(
                disableAnimations: true,
                textScaler: TextScaler.linear(1.8),
              ),
              child: MaterialApp(
                theme: brightness == Brightness.light
                    ? AppTheme.light()
                    : AppTheme.dark(),
                home: Directionality(
                  textDirection: direction,
                  child: Scaffold(
                    body: SizedBox(
                      width: 320,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PremiumHeader(
                            eyebrow: 'ACCESS',
                            title: 'نمونه‌ی کنترل‌های دسترس‌پذیر',
                            subtitle:
                                'متن بزرگ و حرکت غیرفعال باید بدون شکست چیدمان کار کند.',
                            trailing: PremiumIconButton(
                              icon: HopeV2Icons.close,
                              tooltip: 'بستن',
                              semanticsIdentifier: 'quality-close-action',
                              onPressed: () {},
                            ),
                          ),
                          const PremiumFilterChip(
                            label: 'فیلتر',
                            selected: false,
                            onTap: _noop,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.bySemanticsIdentifier('quality-close-action'), findsOneWidget);
          expect(
            tester.getSize(find.byType(PremiumIconButton)).height,
            greaterThanOrEqualTo(HopeV2Touch.minimum),
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}

void _noop() {}
