#!/usr/bin/env sh
set -eu

file="lib/features/home/home_page.dart"
test -f "$file"

if grep -Fq '),\n              if' "$file"; then
  echo "FAIL: home_page.dart contains a literal \\n in the drawer list"
  exit 1
fi

grep -Fq "if (!auth.isGuest) _drawerTile(context, Icons.auto_awesome" "$file"
echo "PASS: home_page.dart source integrity"
