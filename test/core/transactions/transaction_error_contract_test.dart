import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction UI catches expose the error object to apiErrorMessage', () {
    final source = File('lib/features/transactions/transaction_page.dart')
        .readAsStringSync();
    expect(
        RegExp(r'catch \(e\)[\s\S]{0,500}apiErrorMessage\(\s*e\s*,')
            .allMatches(source)
            .length,
        greaterThanOrEqualTo(2));
  });
}
