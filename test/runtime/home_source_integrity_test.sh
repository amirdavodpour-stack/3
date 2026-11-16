#!/usr/bin/env sh
# Current grouped UI batch visual validation bridge: 2026-10-03.
set -eu

# The scaffold/drawer was extracted from home_page.dart into its Dart part.
# Check both source files so the guard remains valid when presentation code is moved.
files="lib/features/home/home_page.dart lib/features/home/home_widgets.part.dart"
for file in $files; do
  if [ ! -f "$file" ]; then
    echo "FAIL: required Home source file is missing: $file" >&2
    exit 1
  fi
done

if grep -Fq '),\n              if' $files; then
  echo "FAIL: Home source contains a literal \\n in the drawer list" >&2
  exit 1
fi

for marker in \
  'PremiumDomainNavigationGroup(' \
  'HopeProductDomain.discovery' \
  'HopeProductDomain.work' \
  'HopeProductDomain.intelligence' \
  'HopeProductDomain.communication' \
  'HopeProductDomain.control'; do
  if ! grep -Fq "$marker" $files; then
    echo "FAIL: Home source integrity is missing marker: $marker" >&2
    exit 1
  fi
done

echo "PASS: Home page and widget part source integrity"
