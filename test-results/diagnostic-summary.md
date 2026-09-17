### test/features/home/home_page_navigation_test.dart
FAIL (exit=1)
```text

::group::❌ member drawer shows account entries and hides admin panel (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with widget matching predicate: []" (used in a call to "tap()") could
not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2095:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1080:7)
#3      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/home/home_page_navigation_test.dart:171:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  member drawer shows account entries and hides admin panel
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: member drawer shows account entries and hides admin panel

::endgroup::
::group::❌ admin member sees the admin panel entry in the drawer (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with widget matching predicate: []" (used in a call to "tap()") could
not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2095:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1080:7)
#3      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/home/home_page_navigation_test.dart:185:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  admin member sees the admin panel entry in the drawer
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: admin member sees the admin panel entry in the drawer

::endgroup::
::group::❌ notifications drawer entry opens the notifications page (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with widget matching predicate: []" (used in a call to "tap()") could
not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2095:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1080:7)
#3      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/home/home_page_navigation_test.dart:195:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  notifications drawer entry opens the notifications page
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: notifications drawer entry opens the notifications page

::endgroup::
::group::❌ drawer language toggle switches the app locale (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with widget matching predicate: []" (used in a call to "tap()") could
not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2095:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1080:7)
#3      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/home/home_page_navigation_test.dart:207:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  drawer language toggle switches the app locale
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: drawer language toggle switches the app locale

::endgroup::
::group::✅ Passing tests
✅ bottom navigation switches tabs and shows profile scaffold
::endgroup::

::error::1 test passed, 4 failed.
```
### test/features/profile/profile_page_test.dart
PASS
### test/features/transactions/transaction_page_test.dart
FAIL (exit=1)
```text

::group::❌ loading then funded payload shows status, amount and start work (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "1000000 TOMAN": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/transactions/transaction_page_test.dart:204:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/3/3/test/features/transactions/transaction_page_test.dart line 204
The test description was:
  loading then funded payload shows status, amount and start work
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: loading then funded payload shows status, amount and start work

::endgroup::
::group::✅ Passing tests
✅ load failure shows retry which recovers
✅ no-transaction view offers fund payment
✅ held payment shows refund only to the job owner
✅ completed and released payment shows settled copy
✅ financial details section renders fee breakdown rows
::endgroup::

::error::5 tests passed, 1 failed.
```
### test/features/marketplace/jobs_page_test.dart
FAIL (exit=1)
```text

::group::✅ Passing tests
✅ jobs page requests categories and opportunities
✅ search narrows the rendered opportunity list
✅ online jobs remain visible for a selected city
✅ kind chip narrows the list to missions only
✅ kind chip narrows the list to jobs only
✅ visibility chip narrows the list to specialized only
✅ visibility chip toggles from specialized back to public
::endgroup::
::group::❌ selecting a category filters the list and shows its localized label (regression: picker used to leak the raw slug and never match any job) (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 2 widgets with text "طراحی": [
            Text("طراحی", inherit: true, color: Color(alpha: 1.0000, red: 0.4196, green: 0.4039,
blue: 0.5020, colorSpace: ColorSpace.sRGB), size: 11.0, weight: 900, overflow: ellipsis, maxLines:
2, dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
            Text("طراحی", dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
          ]>
   Which: is too many

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/jobs_page_test.dart:248:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/3/3/test/features/marketplace/jobs_page_test.dart line 248
The test description was:
  selecting a category filters the list and shows its localized label (regression: picker used to
  leak the raw slug and never match any job)
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: selecting a category filters the list and shows its localized label (regression: picker used to leak the raw slug and never match any job)

::endgroup::
::group::❌ choosing "همه حوزه‌ها" again clears the category filter (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 2 widgets with text "طراحی": [
  Text("طراحی", inherit: true, color: Color(alpha: 1.0000, red: 0.4196, green: 0.4039, blue: 0.5020,
colorSpace: ColorSpace.sRGB), size: 11.0, weight: 900, overflow: ellipsis, maxLines: 2,
dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
  Text("طراحی", dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
]" (used in a call to "tap()") ambiguously found multiple matching widgets. The "tap()" method needs
a single target.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2100:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1080:7)
#3      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/jobs_page_test.dart:271:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  choosing "همه حوزه‌ها" again clears the category filter
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: choosing "همه حوزه‌ها" again clears the category filter

::endgroup::
::group::✅ Passing tests
✅ selecting "همه" (all cities) surfaces jobs from every city (regression: the literal word used to be sent to the server as the city filter, and since no job's city equals that string the server returned zero jobs)
✅ picking a specific city still shows online jobs (regression: forwarding the city filter to the server used to drop every online job, since the server has no carve-out for them)
::endgroup::

::error::9 tests passed, 2 failed.
```
### test/features/marketplace/job_detail_page_test.dart
FAIL (exit=1)
```text
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.


Warning: A call to drag() with finder "Found 1 widget with type "Scrollable": [
  Scrollable(axisDirection: down, physics: AlwaysScrollableScrollPhysics, restorationId: null, dependencies: [InheritedCupertinoTheme, MediaQuery, ScrollConfiguration, UnmanagedRestorationScope, _InheritedTheme, _LocalizationsScope-[GlobalKey#90974]], state: ScrollableState#6386b(position: ScrollPositionWithSingleContext#04475(offset: 0.0, range: 0.0..817.4, viewport: 0.0, ScrollableState, AlwaysScrollableScrollPhysics -> ClampingScrollPhysics -> RangeMaintainingScrollPhysics, IdleScrollActivity#e3fe6, ScrollDirection.idle), effective physics: AlwaysScrollableScrollPhysics -> ClampingScrollPhysics -> RangeMaintainingScrollPhysics)),
]" derived an Offset (Offset(450.0, 56.0)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: RenderClipRect#efa00 relayoutBoundary=up3
The hit test result at that offset is: HitTestResult(_RenderInkFeatures#f8ef4@Offset(450.0, 56.0), RenderPhysicalModel#9ce7e@Offset(450.0, 56.0), RenderSemanticsAnnotations#22954@Offset(450.0, 56.0), RenderRepaintBoundary#0f56a@Offset(450.0, 56.0), RenderIgnorePointer#4b8fe@Offset(450.0, 56.0), RenderAnimatedOpacity#3c5fd@Offset(450.0, 56.0), RenderAnimatedOpacity#7e554@Offset(450.0, 56.0), _RenderColoredBox#7cf40@Offset(450.0, 56.0), RenderAnimatedOpacity#1d121@Offset(450.0, 56.0), RenderIgnorePointer#bcd08@Offset(450.0, 56.0), RenderAnimatedOpacity#f0a57@Offset(450.0, 56.0), RenderRepaintBoundary#940ac@Offset(450.0, 56.0), RenderSemanticsAnnotations#26428@Offset(450.0, 56.0), RenderOffstage#ad470@Offset(450.0, 56.0), RenderSemanticsAnnotations#b9bc7@Offset(450.0, 56.0), _RenderTheater#3688c@Offset(450.0, 56.0), RenderAbsorbPointer#29138@Offset(450.0, 56.0), RenderPointerListener#d4623@Offset(450.0, 56.0), RenderSemanticsAnnotations#fa8f7@Offset(450.0, 56.0), RenderCustomPaint#9e469@Offset(450.0, 56.0), RenderSemanticsAnnotations#43a80@Offset(450.0, 56.0), RenderSemanticsAnnotations#5885f@Offset(450.0, 56.0), RenderSemanticsAnnotations#deed9@Offset(450.0, 56.0), RenderTapRegionSurface#5caa2@Offset(450.0, 56.0), RenderSemanticsAnnotations#15749@Offset(450.0, 56.0), RenderSemanticsAnnotations#95064@Offset(450.0, 56.0), HitTestEntry<HitTestTarget>#16365(_ReusableRenderView#fc497), HitTestEntry<HitTestTarget>#22cd0(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2165:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.drag (package:flutter_test/src/controller.dart:1604:7)
#3      WidgetController.dragUntilVisible.<anonymous closure> (package:flutter_test/src/controller.dart:2483:17)
<asynchronous suspension>
#4      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#5      WidgetController.scrollUntilVisible.<anonymous closure> (package:flutter_test/src/controller.dart:2439:7)
<asynchronous suspension>
#6      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#7      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:309:5)
<asynchronous suspension>
#8      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#9      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
#10     StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "drag()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.


Warning: A call to drag() with finder "Found 1 widget with type "Scrollable": [
  Scrollable(axisDirection: down, physics: AlwaysScrollableScrollPhysics, restorationId: null, dependencies: [InheritedCupertinoTheme, MediaQuery, ScrollConfiguration, UnmanagedRestorationScope, _InheritedTheme, _LocalizationsScope-[GlobalKey#90974]], state: ScrollableState#6386b(position: ScrollPositionWithSingleContext#04475(offset: 0.0, range: 0.0..817.4, viewport: 0.0, ScrollableState, AlwaysScrollableScrollPhysics -> ClampingScrollPhysics -> RangeMaintainingScrollPhysics, IdleScrollActivity#e3fe6, ScrollDirection.idle), effective physics: AlwaysScrollableScrollPhysics -> ClampingScrollPhysics -> RangeMaintainingScrollPhysics)),
]" derived an Offset (Offset(450.0, 56.0)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: RenderClipRect#efa00 relayoutBoundary=up3
The hit test result at that offset is: HitTestResult(_RenderInkFeatures#f8ef4@Offset(450.0, 56.0), RenderPhysicalModel#9ce7e@Offset(450.0, 56.0), RenderSemanticsAnnotations#22954@Offset(450.0, 56.0), RenderRepaintBoundary#0f56a@Offset(450.0, 56.0), RenderIgnorePointer#4b8fe@Offset(450.0, 56.0), RenderAnimatedOpacity#3c5fd@Offset(450.0, 56.0), RenderAnimatedOpacity#7e554@Offset(450.0, 56.0), _RenderColoredBox#7cf40@Offset(450.0, 56.0), RenderAnimatedOpacity#1d121@Offset(450.0, 56.0), RenderIgnorePointer#bcd08@Offset(450.0, 56.0), RenderAnimatedOpacity#f0a57@Offset(450.0, 56.0), RenderRepaintBoundary#940ac@Offset(450.0, 56.0), RenderSemanticsAnnotations#26428@Offset(450.0, 56.0), RenderOffstage#ad470@Offset(450.0, 56.0), RenderSemanticsAnnotations#b9bc7@Offset(450.0, 56.0), _RenderTheater#3688c@Offset(450.0, 56.0), RenderAbsorbPointer#29138@Offset(450.0, 56.0), RenderPointerListener#d4623@Offset(450.0, 56.0), RenderSemanticsAnnotations#fa8f7@Offset(450.0, 56.0), RenderCustomPaint#9e469@Offset(450.0, 56.0), RenderSemanticsAnnotations#43a80@Offset(450.0, 56.0), RenderSemanticsAnnotations#5885f@Offset(450.0, 56.0), RenderSemanticsAnnotations#deed9@Offset(450.0, 56.0), RenderTapRegionSurface#5caa2@Offset(450.0, 56.0), RenderSemanticsAnnotations#15749@Offset(450.0, 56.0), RenderSemanticsAnnotations#95064@Offset(450.0, 56.0), HitTestEntry<HitTestTarget>#50dad(_ReusableRenderView#fc497), HitTestEntry<HitTestTarget>#f364e(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2165:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.drag (package:flutter_test/src/controller.dart:1604:7)
#3      WidgetController.dragUntilVisible.<anonymous closure> (package:flutter_test/src/controller.dart:2483:17)
<asynchronous suspension>
#4      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#5      WidgetController.scrollUntilVisible.<anonymous closure> (package:flutter_test/src/controller.dart:2439:7)
<asynchronous suspension>
#6      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#7      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:309:5)
<asynchronous suspension>
#8      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#9      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
#10     StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "drag()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.


Warning: A call to drag() with finder "Found 1 widget with type "Scrollable": [
  Scrollable(axisDirection: down, physics: AlwaysScrollableScrollPhysics, restorationId: null, dependencies: [InheritedCupertinoTheme, MediaQuery, ScrollConfiguration, UnmanagedRestorationScope, _InheritedTheme, _LocalizationsScope-[GlobalKey#90974]], state: ScrollableState#6386b(position: ScrollPositionWithSingleContext#04475(offset: 0.0, range: 0.0..817.4, viewport: 0.0, ScrollableState, AlwaysScrollableScrollPhysics -> ClampingScrollPhysics -> RangeMaintainingScrollPhysics, IdleScrollActivity#e3fe6, ScrollDirection.idle), effective physics: AlwaysScrollableScrollPhysics -> ClampingScrollPhysics -> RangeMaintainingScrollPhysics)),
]" derived an Offset (Offset(450.0, 56.0)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: RenderClipRect#efa00 relayoutBoundary=up3
The hit test result at that offset is: HitTestResult(_RenderInkFeatures#f8ef4@Offset(450.0, 56.0), RenderPhysicalModel#9ce7e@Offset(450.0, 56.0), RenderSemanticsAnnotations#22954@Offset(450.0, 56.0), RenderRepaintBoundary#0f56a@Offset(450.0, 56.0), RenderIgnorePointer#4b8fe@Offset(450.0, 56.0), RenderAnimatedOpacity#3c5fd@Offset(450.0, 56.0), RenderAnimatedOpacity#7e554@Offset(450.0, 56.0), _RenderColoredBox#7cf40@Offset(450.0, 56.0), RenderAnimatedOpacity#1d121@Offset(450.0, 56.0), RenderIgnorePointer#bcd08@Offset(450.0, 56.0), RenderAnimatedOpacity#f0a57@Offset(450.0, 56.0), RenderRepaintBoundary#940ac@Offset(450.0, 56.0), RenderSemanticsAnnotations#26428@Offset(450.0, 56.0), RenderOffstage#ad470@Offset(450.0, 56.0), RenderSemanticsAnnotations#b9bc7@Offset(450.0, 56.0), _RenderTheater#3688c@Offset(450.0, 56.0), RenderAbsorbPointer#29138@Offset(450.0, 56.0), RenderPointerListener#d4623@Offset(450.0, 56.0), RenderSemanticsAnnotations#fa8f7@Offset(450.0, 56.0), RenderCustomPaint#9e469@Offset(450.0, 56.0), RenderSemanticsAnnotations#43a80@Offset(450.0, 56.0), RenderSemanticsAnnotations#5885f@Offset(450.0, 56.0), RenderSemanticsAnnotations#deed9@Offset(450.0, 56.0), RenderTapRegionSurface#5caa2@Offset(450.0, 56.0), RenderSemanticsAnnotations#15749@Offset(450.0, 56.0), RenderSemanticsAnnotations#95064@Offset(450.0, 56.0), HitTestEntry<HitTestTarget>#8b8d3(_ReusableRenderView#fc497), HitTestEntry<HitTestTarget>#f6159(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2165:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.drag (package:flutter_test/src/controller.dart:1604:7)
#3      WidgetController.dragUntilVisible.<anonymous closure> (package:flutter_test/src/controller.dart:2483:17)
<asynchronous suspension>
#4      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#5      WidgetController.scrollUntilVisible.<anonymous closure> (package:flutter_test/src/controller.dart:2439:7)
<asynchronous suspension>
#6      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#7      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:309:5)
<asynchronous suspension>
#8      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#9      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
#10     StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "drag()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.


Warning: A call to drag() with finder "Found 1 widget with type "Scrollable": [
  Scrollable(axisDirection: down, physics: AlwaysScrollableScrollPhysics, restorationId: null, dependencies: [InheritedCupertinoTheme, MediaQuery, ScrollConfiguration, UnmanagedRestorationScope, _InheritedTheme, _LocalizationsScope-[GlobalKey#90974]], state: ScrollableState#6386b(position: ScrollPositionWithSingleContext#04475(offset: 0.0, range: 0.0..817.4, viewport: 0.0, ScrollableState, AlwaysScrollableScrollPhysics -> ClampingScrollPhysics -> RangeMaintainingScrollPhysics, IdleScrollActivity#e3fe6, ScrollDirection.idle), effective physics: AlwaysScrollableScrollPhysics -> ClampingScrollPhysics -> RangeMaintainingScrollPhysics)),
]" derived an Offset (Offset(450.0, 56.0)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: RenderClipRect#efa00 relayoutBoundary=up3
The hit test result at that offset is: HitTestResult(_RenderInkFeatures#f8ef4@Offset(450.0, 56.0), RenderPhysicalModel#9ce7e@Offset(450.0, 56.0), RenderSemanticsAnnotations#22954@Offset(450.0, 56.0), RenderRepaintBoundary#0f56a@Offset(450.0, 56.0), RenderIgnorePointer#4b8fe@Offset(450.0, 56.0), RenderAnimatedOpacity#3c5fd@Offset(450.0, 56.0), RenderAnimatedOpacity#7e554@Offset(450.0, 56.0), _RenderColoredBox#7cf40@Offset(450.0, 56.0), RenderAnimatedOpacity#1d121@Offset(450.0, 56.0), RenderIgnorePointer#bcd08@Offset(450.0, 56.0), RenderAnimatedOpacity#f0a57@Offset(450.0, 56.0), RenderRepaintBoundary#940ac@Offset(450.0, 56.0), RenderSemanticsAnnotations#26428@Offset(450.0, 56.0), RenderOffstage#ad470@Offset(450.0, 56.0), RenderSemanticsAnnotations#b9bc7@Offset(450.0, 56.0), _RenderTheater#3688c@Offset(450.0, 56.0), RenderAbsorbPointer#29138@Offset(450.0, 56.0), RenderPointerListener#d4623@Offset(450.0, 56.0), RenderSemanticsAnnotations#fa8f7@Offset(450.0, 56.0), RenderCustomPaint#9e469@Offset(450.0, 56.0), RenderSemanticsAnnotations#43a80@Offset(450.0, 56.0), RenderSemanticsAnnotations#5885f@Offset(450.0, 56.0), RenderSemanticsAnnotations#deed9@Offset(450.0, 56.0), RenderTapRegionSurface#5caa2@Offset(450.0, 56.0), RenderSemanticsAnnotations#15749@Offset(450.0, 56.0), RenderSemanticsAnnotations#95064@Offset(450.0, 56.0), HitTestEntry<HitTestTarget>#e3597(_ReusableRenderView#fc497), HitTestEntry<HitTestTarget>#403f3(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2165:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.drag (package:flutter_test/src/controller.dart:1604:7)
#3      WidgetController.dragUntilVisible.<anonymous closure> (package:flutter_test/src/controller.dart:2483:17)
<asynchronous suspension>
#4      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#5      WidgetController.scrollUntilVisible.<anonymous closure> (package:flutter_test/src/controller.dart:2439:7)
<asynchronous suspension>
#6      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#7      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:309:5)
<asynchronous suspension>
#8      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#9      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
#10     StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "drag()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.


Warning: A call to drag() with finder "Found 1 widget with type "Scrollable": [
  Scrollable(axisDirection: down, physics: AlwaysScrollableScrollPhysics, restorationId: null, dependencies: [InheritedCupertinoTheme, MediaQuery, ScrollConfiguration, UnmanagedRestorationScope, _InheritedTheme, _LocalizationsScope-[GlobalKey#90974]], state: ScrollableState#6386b(position: ScrollPositionWithSingleContext#04475(offset: 0.0, range: 0.0..817.4, viewport: 0.0, ScrollableState, AlwaysScrollableScrollPhysics -> ClampingScrollPhysics -> RangeMaintainingScrollPhysics, IdleScrollActivity#e3fe6, ScrollDirection.idle), effective physics: AlwaysScrollableScrollPhysics -> ClampingScrollPhysics -> RangeMaintainingScrollPhysics)),
]" derived an Offset (Offset(450.0, 56.0)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: RenderClipRect#efa00 relayoutBoundary=up3
The hit test result at that offset is: HitTestResult(_RenderInkFeatures#f8ef4@Offset(450.0, 56.0), RenderPhysicalModel#9ce7e@Offset(450.0, 56.0), RenderSemanticsAnnotations#22954@Offset(450.0, 56.0), RenderRepaintBoundary#0f56a@Offset(450.0, 56.0), RenderIgnorePointer#4b8fe@Offset(450.0, 56.0), RenderAnimatedOpacity#3c5fd@Offset(450.0, 56.0), RenderAnimatedOpacity#7e554@Offset(450.0, 56.0), _RenderColoredBox#7cf40@Offset(450.0, 56.0), RenderAnimatedOpacity#1d121@Offset(450.0, 56.0), RenderIgnorePointer#bcd08@Offset(450.0, 56.0), RenderAnimatedOpacity#f0a57@Offset(450.0, 56.0), RenderRepaintBoundary#940ac@Offset(450.0, 56.0), RenderSemanticsAnnotations#26428@Offset(450.0, 56.0), RenderOffstage#ad470@Offset(450.0, 56.0), RenderSemanticsAnnotations#b9bc7@Offset(450.0, 56.0), _RenderTheater#3688c@Offset(450.0, 56.0), RenderAbsorbPointer#29138@Offset(450.0, 56.0), RenderPointerListener#d4623@Offset(450.0, 56.0), RenderSemanticsAnnotations#fa8f7@Offset(450.0, 56.0), RenderCustomPaint#9e469@Offset(450.0, 56.0), RenderSemanticsAnnotations#43a80@Offset(450.0, 56.0), RenderSemanticsAnnotations#5885f@Offset(450.0, 56.0), RenderSemanticsAnnotations#deed9@Offset(450.0, 56.0), RenderTapRegionSurface#5caa2@Offset(450.0, 56.0), RenderSemanticsAnnotations#15749@Offset(450.0, 56.0), RenderSemanticsAnnotations#95064@Offset(450.0, 56.0), HitTestEntry<HitTestTarget>#4185f(_ReusableRenderView#fc497), HitTestEntry<HitTestTarget>#89b0b(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2165:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.drag (package:flutter_test/src/controller.dart:1604:7)
#3      WidgetController.dragUntilVisible.<anonymous closure> (package:flutter_test/src/controller.dart:2483:17)
<asynchronous suspension>
#4      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#5      WidgetController.scrollUntilVisible.<anonymous closure> (package:flutter_test/src/controller.dart:2439:7)
<asynchronous suspension>
#6      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#7      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:309:5)
<asynchronous suspension>
#8      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#9      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
#10     StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "drag()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.element (package:flutter_test/src/controller.dart:888:30)
#2      WidgetController.dragUntilVisible.<anonymous closure> (package:flutter_test/src/controller.dart:2489:38)
<asynchronous suspension>
#3      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#4      WidgetController.scrollUntilVisible.<anonymous closure> (package:flutter_test/src/controller.dart:2439:7)
<asynchronous suspension>
#5      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#6      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:309:5)
<asynchronous suspension>
#7      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#8      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  owner mission opens the transaction route intent
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: owner mission opens the transaction route intent

::endgroup::

::error::1 test passed, 4 failed.
```
### test/features/marketplace/create_job_page_test.dart
FAIL (exit=1)
```text

::group::✅ Passing tests
✅ mission publish delegates create then publish and pops back
✅ validation failure blocks submit without category
::endgroup::
::group::❌ switching types swaps price fields, fee copy and job deadline (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: contains 'create:JOB:Flutter developer'
  Actual: []
   Which: does not contain 'create:JOB:Flutter developer'

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/create_job_page_test.dart:250:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/3/3/test/features/marketplace/create_job_page_test.dart line 250
The test description was:
  switching types swaps price fields, fee copy and job deadline
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: switching types swaps price fields, fee copy and job deadline

::endgroup::
::group::✅ Passing tests
✅ busy state disables the submit action while in flight
✅ create failure surfaces server error snackbar
::endgroup::

::error::4 tests passed, 1 failed.
```
### test/core/router/app_routes_test.dart
PASS
OVERALL_EXIT=1
