### test/features/transactions/transaction_page_test.dart
FAIL (exit=1)
```text

::group::❌ loading then funded payload shows status, amount and start work (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Start work": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/transactions/transaction_page_test.dart:206:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/3/3/test/features/transactions/transaction_page_test.dart line 206
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
            Text("طراحی", dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
            Text("طراحی", inherit: true, color: Color(alpha: 1.0000, red: 0.4196, green: 0.4039,
blue: 0.5020, colorSpace: ColorSpace.sRGB), size: 11.0, weight: 900, overflow: ellipsis, maxLines:
2, dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
          ]>
   Which: is too many

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/jobs_page_test.dart:255:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/3/3/test/features/marketplace/jobs_page_test.dart line 255
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
#3      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/jobs_page_test.dart:272:18)
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

::group::❌ mission details render pricing, duration and transaction entry (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Design a logo": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:231:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart line 231
The test description was:
  mission details render pricing, duration and transaction entry
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: mission details render pricing, duration and transaction entry

::endgroup::
::group::❌ job details render monthly pay, deadline and admin banner (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Flutter developer": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:245:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart line 245
The test description was:
  job details render monthly pay, deadline and admin banner
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: job details render monthly pay, deadline and admin banner

::endgroup::
::group::❌ owner job with forwarded candidates renders candidate actions (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Forwarded candidates": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:274:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart line 274
The test description was:
  owner job with forwarded candidates renders candidate actions
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: owner job with forwarded candidates renders candidate actions

::endgroup::
::group::✅ Passing tests
✅ non-owner never sees the candidate pipeline
✅ owner mission opens the transaction route intent
::endgroup::

::error::2 tests passed, 3 failed.
```
OVERALL_EXIT=1
