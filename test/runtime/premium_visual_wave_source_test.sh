fi
grep -Fq "fontSize: 11.5" "$premium"
grep -Fq "height: 33" "$premium"
grep -Fq "fontSize: compact ? 20 : 28" "$premium"
grep -Fq "fontSize: dense ? 21 : 24" "$premium"
grep -Fq "barHeight = 61.0" "lib/core/theme/hope_v2_design.dart"
grep -Fq "fontSize: 28" "lib/core/theme/hope_v2_design.dart"
grep -Fq "fontSize: 25" "lib/core/theme/hope_v2_design.dart"
if grep -Fq "FittedBox(" "$home"; then
  echo "FAIL: Home Pulse metrics still shrink with FittedBox" >&2
  exit 1
fi