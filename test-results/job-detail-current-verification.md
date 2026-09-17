# Current Job Detail Verification

Branch: hope/full-stack-hardening-2026-09-17
Analyze exit=0

## flutter analyze
```text
Resolving dependencies...
Downloading packages...
  code_assets 2.0.0 (2.1.0 available)
  dbus 0.7.15 (0.8.0 available)
  file_picker 8.3.7 (13.1.0 available)
  flutter_lints 4.0.0 (6.0.0 available)
  flutter_secure_storage 9.2.4 (11.2.0 available)
  flutter_secure_storage_linux 1.2.3 (3.0.3 available)
  flutter_secure_storage_macos 3.1.3 (4.0.0 available)
  flutter_secure_storage_platform_interface 1.1.2 (2.1.1 available)
  flutter_secure_storage_web 1.2.1 (2.1.1 available)
  flutter_secure_storage_windows 3.1.2 (4.2.2 available)
  geolocator 14.0.2 (14.0.3 available)
  geolocator_linux 0.2.4 (0.2.6 available)
  js 0.6.7 (0.7.2 available)
  lints 4.0.0 (6.1.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_info_plus 9.0.1 (10.2.1 available)
  package_info_plus_platform_interface 3.2.1 (4.1.0 available)
  platform 3.1.6 (3.2.0 available)
  test_api 0.7.12 (0.7.14 available)
  webdriver 3.1.0 (3.2.0 available)
  win32 5.15.0 (6.4.0 available)
Got dependencies!
21 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing 3...                                                  

   info • Don't use 'BuildContext's across async gaps. Try rewriting the code to not use the 'BuildContext', or guard the use with a 'mounted' check • lib/features/admin/admin_operations_page.dart:317:13 • use_build_context_synchronously
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/home/home_page.dart:87:30 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/home/home_page.dart:89:30 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/home/premium_home_feed.dart:280:41 • prefer_const_constructors
   info • Use 'const' literals as arguments to constructors of '@immutable' classes. Try adding 'const' before the literal • lib/features/home/premium_home_feed.dart:280:58 • prefer_const_literals_to_create_immutables
   info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a 'mounted' check on the State, and other BuildContext use with a 'mounted' check on the BuildContext • lib/features/marketplace/job_detail_page.dart:336:28 • use_build_context_synchronously
   info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a 'mounted' check on the State, and other BuildContext use with a 'mounted' check on the BuildContext • lib/features/marketplace/job_detail_page.dart:341:37 • use_build_context_synchronously
   info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a 'mounted' check on the State, and other BuildContext use with a 'mounted' check on the BuildContext • lib/features/marketplace/job_detail_page.dart:367:18 • use_build_context_synchronously
   info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a 'mounted' check on the State, and other BuildContext use with a 'mounted' check on the BuildContext • lib/features/marketplace/job_detail_page.dart:429:28 • use_build_context_synchronously
   info • Don't use 'BuildContext's across async gaps. Try rewriting the code to not use the 'BuildContext', or guard the use with a 'mounted' check • lib/features/marketplace/job_detail_page.dart:485:13 • use_build_context_synchronously
   info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a 'mounted' check on the State, and other BuildContext use with a 'mounted' check on the BuildContext • lib/features/marketplace/job_detail_page.dart:491:28 • use_build_context_synchronously
   info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a 'mounted' check on the State, and other BuildContext use with a 'mounted' check on the BuildContext • lib/features/marketplace/job_detail_page.dart:496:28 • use_build_context_synchronously
   info • Statements in an if should be enclosed in a block. Try wrapping the statement in a block • lib/features/offers/offers_page.dart:32:23 • curly_braces_in_flow_control_structures
   info • Don't use 'BuildContext's across async gaps. Try rewriting the code to not use the 'BuildContext', or guard the use with a 'mounted' check • lib/features/offers/offers_page.dart:181:15 • use_build_context_synchronously
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/privacy/privacy_center_page.dart:55:13 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/privacy/privacy_center_page.dart:200:21 • prefer_const_constructors
   info • Don't use 'BuildContext's across async gaps. Try rewriting the code to not use the 'BuildContext', or guard the use with a 'mounted' check • lib/features/wallet/wallet_page.dart:148:28 • use_build_context_synchronously
   info • Don't use 'BuildContext's across async gaps. Try rewriting the code to not use the 'BuildContext', or guard the use with a 'mounted' check • lib/features/wallet/wallet_page.dart:183:28 • use_build_context_synchronously
   info • Don't use 'BuildContext's across async gaps. Try rewriting the code to not use the 'BuildContext', or guard the use with a 'mounted' check • lib/features/wallet/wallet_page.dart:204:28 • use_build_context_synchronously

19 issues found. (ran in 10.1s)
```

## flutter test
test_exit=1
```text
00:00 +0: loading /home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart
00:00 +0: mission details render pricing, duration and transaction entry
DEBUG mission list size: Size(900.0, 0.0)
DEBUG mission scrollables: 1
DEBUG mission text: [Mission details]
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Mission budget": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:238:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart line 238
The test description was:
  mission details render pricing, duration and transaction entry
════════════════════════════════════════════════════════════════════════════════════════════════════
00:01 +0 -1: mission details render pricing, duration and transaction entry [E]
  Test failed. See exception logs above.
  The test description was: mission details render pricing, duration and transaction entry
  
00:01 +0 -1: job details render monthly pay, deadline and admin banner
DEBUG job list size: Size(900.0, 0.0)
DEBUG job text: [Job details]
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Monthly pay": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:255:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart line 255
The test description was:
  job details render monthly pay, deadline and admin banner
════════════════════════════════════════════════════════════════════════════════════════════════════
00:01 +0 -2: job details render monthly pay, deadline and admin banner [E]
  Test failed. See exception logs above.
  The test description was: job details render monthly pay, deadline and admin banner
  
00:01 +0 -2: owner job with forwarded candidates renders candidate actions
DEBUG owner list size: Size(900.0, 0.0)
DEBUG owner candidate text: []
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.element (package:flutter_test/src/controller.dart:888:30)
#2      WidgetController.ensureVisible (package:flutter_test/src/controller.dart:2389:32)
#3      main.<anonymous closure> (file:///home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart:285:18)
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
00:01 +0 -3: owner job with forwarded candidates renders candidate actions [E]
  Test failed. See exception logs above.
  The test description was: owner job with forwarded candidates renders candidate actions
  
00:01 +0 -3: non-owner never sees the candidate pipeline
00:01 +1 -3: owner mission opens the transaction route intent
00:01 +2 -3: Some tests failed.

Failing tests:
  /home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart: job details render monthly pay, deadline and admin banner
  /home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart: mission details render pricing, duration and transaction entry
  /home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart: owner job with forwarded candidates renders candidate actions
```
JOB_DETAIL_TEST_EXIT=1
