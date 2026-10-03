#!/usr/bin/env sh
# Current UI architecture runtime trigger: 2026-10-03
set -eu

file="lib/features/home/home_page.dart"
test -f "$file"

if grep -Fq '),\n              if' "$file"; then
  echo "FAIL: home_page.dart contains a literal \\n in the drawer list"
  exit 1
fi

grep -Fq "PremiumDomainNavigationGroup(" "$file"
grep -Fq "HopeProductDomain.discovery" "$file"
grep -Fq "HopeProductDomain.work" "$file"
grep -Fq "HopeProductDomain.intelligence" "$file"
grep -Fq "HopeProductDomain.communication" "$file"
grep -Fq "HopeProductDomain.control" "$file"
echo "PASS: home_page.dart source integrity"
