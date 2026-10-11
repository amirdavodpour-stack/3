#!/usr/bin/env python3
"""Contrast checks for the canonical HOPE semantic tokens.

Checks foregrounds against the active light/dark surface palette. Disabled
controls are excluded from body-text contrast because WCAG exempts inactive UI.
This is a token-level guard; widget-level Flutter guideline tests remain required.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKEN_FILE = ROOT / "lib/core/theme/hope_v2_design.dart"
SOURCE = TOKEN_FILE.read_text(encoding="utf-8")
TOKENS = {
    name: "#" + value[-6:]
    for name, value in re.findall(
        r"static const (\w+) = Color\(0xFF([0-9A-Fa-f]{6})\);", SOURCE
    )
}


def luminance(hex_color: str) -> float:
    values = [int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [
        v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
        for v in values
    ]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def ratio(foreground: str, background: str) -> float:
    high, low = sorted((luminance(foreground), luminance(background)), reverse=True)
    return (high + 0.05) / (low + 0.05)


required = [
    "darkText", "darkMuted", "darkBackground", "darkSurface", "darkCard",
    "panelDark", "panelSoftDark", "pageDark", "inputDark",
    "ink", "muted", "surface", "background", "backgroundWarm", "pageLight",
    "panelLight", "panelSoftLight", "chipLight", "navigationLight",
    "primaryAction", "primaryOnLight", "successOnLight", "warningOnLight",
    "dangerOnLight", "secondaryAction", "primaryDark", "successDark",
    "warningDark", "dangerDark",
]
missing = [key for key in required if key not in TOKENS]
if missing:
    print("Contrast check blocked; missing tokens: " + ", ".join(missing), file=sys.stderr)
    raise SystemExit(1)

dark_surfaces = [
    "darkBackground", "darkSurface", "darkCard", "panelDark",
    "panelSoftDark", "pageDark", "inputDark",
]
light_surfaces = [
    "surface", "background", "backgroundWarm", "pageLight",
    "panelLight", "panelSoftLight", "chipLight", "navigationLight",
]
checks: list[tuple[str, str, str, float, float]] = []
for fg in ("darkText", "darkMuted"):
    for bg in dark_surfaces:
        checks.append((fg, bg, "body", ratio(TOKENS[fg], TOKENS[bg]), 4.5))
for fg in ("ink", "muted"):
    for bg in light_surfaces:
        checks.append((fg, bg, "body", ratio(TOKENS[fg], TOKENS[bg]), 4.5))
for fg in ("primaryOnLight", "successOnLight", "warningOnLight", "dangerOnLight"):
    for bg in light_surfaces:
        checks.append((fg, bg, "icon/border", ratio(TOKENS[fg], TOKENS[bg]), 3.0))
for fg in ("primaryDark", "successDark", "warningDark", "dangerDark"):
    for bg in dark_surfaces:
        checks.append((fg, bg, "icon/border", ratio(TOKENS[fg], TOKENS[bg]), 3.0))
for fg in ("primaryAction", "secondaryAction", "successOnLight", "warningOnLight", "dangerOnLight"):
    checks.append((fg, "surface", "button label", ratio("#FFFFFF", TOKENS[fg]), 4.5))
checks.append(("ink", "primaryDark", "dark button label", ratio(TOKENS["ink"], TOKENS["primaryDark"]), 4.5))

failures = [item for item in checks if item[3] + 1e-9 < item[4]]
for fg, bg, kind, value, threshold in checks:
    status = "FAIL" if value + 1e-9 < threshold else "PASS"
    print(f"{status} {kind}: {fg} on {bg} = {value:.2f}:1 (required {threshold:.1f}:1)")
if failures:
    print(f"Contrast check failed: {len(failures)} of {len(checks)} pairs.", file=sys.stderr)
    raise SystemExit(1)
print(f"Contrast check PASS: {len(checks)} token/surface pairs.")
