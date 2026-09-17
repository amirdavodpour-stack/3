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

19 issues found. (ran in 10.3s)
```

## flutter test
test_exit=1
```text
00:00 +0: loading /home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart
test/features/marketplace/job_detail_page_test.dart:232:54: Error: Undefined name 'MetricTile'.
    print('DEBUG mission metric tiles: ${find.byType(MetricTile).evaluate().length}');
                                                     ^^^^^^^^^^
test/features/marketplace/job_detail_page_test.dart:250:50: Error: Undefined name 'MetricTile'.
    print('DEBUG job metric tiles: ${find.byType(MetricTile).evaluate().length}');
                                                 ^^^^^^^^^^
00:00 +0 -1: loading /home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart [E]
  Failed to load "/home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart":
  Compilation failed for testPath=/home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart: test/features/marketplace/job_detail_page_test.dart:232:54: Error: Undefined name 'MetricTile'.
      print('DEBUG mission metric tiles: ${find.byType(MetricTile).evaluate().length}');
                                                       ^^^^^^^^^^
  test/features/marketplace/job_detail_page_test.dart:250:50: Error: Undefined name 'MetricTile'.
      print('DEBUG job metric tiles: ${find.byType(MetricTile).evaluate().length}');
                                                   ^^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart: loading /home/runner/work/3/3/test/features/marketplace/job_detail_page_test.dart
```
JOB_DETAIL_TEST_EXIT=1
