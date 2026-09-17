### test/features/home/home_page_navigation_test.dart
PASS
### test/features/profile/profile_page_test.dart
PASS
### test/features/transactions/transaction_page_test.dart
PASS
### test/features/marketplace/jobs_page_test.dart
PASS
### test/features/marketplace/job_detail_page_test.dart
FAIL (exit=1)
```text

::group::❌ mission details render pricing, duration and transaction entry (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Mission budget": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:235:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart line 235
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
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Monthly pay": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:250:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart line 250
The test description was:
  job details render monthly pay, deadline and admin banner
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: job details render monthly pay, deadline and admin banner

::endgroup::
::group::❌ owner job with forwarded candidates renders candidate actions (failed)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.element (package:flutter_test/src/controller.dart:888:30)
#2      WidgetController.ensureVisible (package:flutter_test/src/controller.dart:2389:32)
#3      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:278:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

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
### test/features/marketplace/create_job_page_test.dart
PASS
### test/core/router/app_routes_test.dart
PASS
OVERALL_EXIT=1
