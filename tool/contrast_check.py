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
# Parse canonical tonal ramps before semantic-token aliases. This lets
# readable roles point to a palette shade without duplicating hex literals.
palette_blocks = re.findall(
    r"static const (\w+) = HopeV2TonalPalette\((.*?)\);", SOURCE, re.DOTALL
)
PALETTE_SHADES = {
    palette_name: dict(re.findall(r"shade(\d+): Color\(0xFF([0-9A-Fa-f]{6})\)", block))
    for palette_name, block in palette_blocks
}
TOKENS = {
    name: "#" + value[-6:]
    for name, value in re.findall(
        r"static const (\w+) = Color\(0xFF([0-9A-Fa-f]{6})\);", SOURCE
    )
}
for token_name, palette_name, shade in re.findall(
    r"static const (\w+) = HopeV2TonalPalettes\.(\w+)\.shade(\d+);", SOURCE
):
    value = PALETTE_SHADES.get(palette_name, {}).get(shade)
    if value:
        TOKENS[token_name] = "#" + value


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
    "warningDark", "dangerDark", "moneyTextLight", "moneyTextDark",
    "infoTextLight", "infoTextDark", "trustTextLight", "trustTextDark",
    "trustSurfaceLight", "trustSurfaceDark", "accentTextLight", "accentTextDark",
    "accentSurfaceLight", "accentSurfaceDark", "primaryActionHoverLight",
    "primaryActionPressedLight",
]
missing = [key for key in required if key not in TOKENS]
if missing:
    print("Contrast check blocked; missing tokens: " + ", ".join(missing), file=sys.stderr)
    raise SystemExit(1)

dark_surfaces = [
    "darkBackground", "darkSurface", "darkCard", "panelDark",
    "panelSoftDark", "pageDark", "inputDark", "trustSurfaceDark",
]
light_surfaces = [
    "surface", "background", "backgroundWarm", "pageLight",
    "panelLight", "panelSoftLight", "chipLight", "navigationLight",
    "trustSurfaceLight",
]
checks: list[tuple[str, str, str, float, float]] = []
for fg in ("darkText", "darkMuted"):
    for bg in dark_surfaces:
        checks.append((fg, bg, "body", ratio(TOKENS[fg], TOKENS[bg]), 4.5))
for bg in dark_surfaces + ["accentSurfaceDark"]:
    checks.append(("accentTextDark", bg, "featured/semantic text", ratio(TOKENS["accentTextDark"], TOKENS[bg]), 4.5))
for fg in ("ink", "muted", "moneyTextLight", "infoTextLight", "trustTextLight",
           "successOnLight", "warningOnLight", "dangerOnLight"):
    for bg in light_surfaces:
        checks.append((fg, bg, "body/semantic text", ratio(TOKENS[fg], TOKENS[bg]), 4.5))
for bg in light_surfaces + ["accentSurfaceLight"]:
    checks.append(("accentTextLight", bg, "featured/semantic text", ratio(TOKENS["accentTextLight"], TOKENS[bg]), 4.5))
for fg in ("primaryOnLight", "successOnLight", "warningOnLight", "dangerOnLight"):
    for bg in light_surfaces:
        checks.append((fg, bg, "icon/border", ratio(TOKENS[fg], TOKENS[bg]), 3.0))
for fg in ("moneyTextDark", "infoTextDark", "trustTextDark", "successDark", "warningDark", "dangerDark"):
    for bg in dark_surfaces:
        checks.append((fg, bg, "body/semantic text", ratio(TOKENS[fg], TOKENS[bg]), 4.5))
for fg in ("primaryDark", "successDark", "warningDark", "dangerDark"):
    for bg in dark_surfaces:
        checks.append((fg, bg, "icon/border", ratio(TOKENS[fg], TOKENS[bg]), 3.0))
for fg in ("primaryAction", "secondaryAction", "successOnLight", "warningOnLight", "dangerOnLight"):
    checks.append((fg, "surface", "button label", ratio("#FFFFFF", TOKENS[fg]), 4.5))
checks.append(("ink", "primaryDark", "dark button label", ratio(TOKENS["ink"], TOKENS["primaryDark"]), 4.5))
checks.append(("primaryDark", "darkBackground", "indigo brand accent", ratio(TOKENS["primaryDark"], TOKENS["darkBackground"]), 4.5))
# Validate that the central color genome retains the full, named 50–950 ramps.
expected_steps = {"50", "100", "200", "300", "400", "500", "600", "700", "800", "900", "950"}
palette_names = {name for name, _ in palette_blocks}
if palette_names != {"indigo", "forest", "lichen", "neutral", "info", "trust", "success", "warning", "featured", "danger"}:
    print(f"Contrast check blocked: incomplete tonal palette set: {sorted(palette_names)}", file=sys.stderr)
    raise SystemExit(1)
for palette_name, palette_shades in PALETTE_SHADES.items():
    if set(palette_shades) != expected_steps:
        print(f"Contrast check blocked: {palette_name} tonal ramp is incomplete.", file=sys.stderr)
        raise SystemExit(1)

palette_token_bindings = {
    "primary": ("indigo", "500"),
    "primaryAction": ("indigo", "600"),
    "primaryOnLight": ("indigo", "600"),
    "primaryDark": ("indigo", "400"),
    "primaryTintLight": ("indigo", "100"),
    "primaryBorderLight": ("indigo", "300"),
    "primaryActionHoverLight": ("indigo", "700"),
    "primaryActionPressedLight": ("indigo", "800"),
    "secondary": ("info", "500"),
    "secondaryStrong": ("info", "600"),
    "secondaryDark": ("info", "300"),
    "secondaryAction": ("info", "700"),
    "accent": ("warning", "500"),
    "orange": ("featured", "500"),
    "orangeDark": ("featured", "300"),
    "inkSoft": ("neutral", "800"),
    "ink": ("neutral", "900"),
    "muted": ("neutral", "600"),
    "moneyTextLight": ("neutral", "900"),
    "infoTextLight": ("info", "800"),
    "infoTextDark": ("info", "300"),
    "successOnLight": ("success", "800"),
    "successDark": ("success", "200"),
    "warningOnLight": ("warning", "800"),
    "warningDark": ("warning", "200"),
    "dangerOnLight": ("danger", "700"),
    "dangerDark": ("danger", "200"),
    "accentTextLight": ("featured", "800"),
    "accentTextDark": ("featured", "200"),
    "trustTextLight": ("trust", "800"),
    "trustTextDark": ("trust", "200"),
    "trustSurfaceLight": ("trust", "50"),
}
for token_name, (palette_name, shade) in palette_token_bindings.items():
    expected = PALETTE_SHADES.get(palette_name, {}).get(shade)
    if expected is None or TOKENS.get(token_name) != "#" + expected:
        print(
            f"Contrast check blocked: {token_name} must match {palette_name}.shade{shade}.",
            file=sys.stderr,
        )
        raise SystemExit(1)

brand_action_foregrounds = {TOKENS[name] for name in ("primary", "primaryAction", "primaryDark", "primaryActionHoverLight", "primaryActionPressedLight")}
for readable in ("moneyTextLight", "moneyTextDark", "infoTextLight", "infoTextDark", "trustTextLight", "trustTextDark", "accentTextLight", "accentTextDark"):
    if TOKENS[readable] in brand_action_foregrounds:
        print(f"Contrast check blocked: {readable} must not reuse a brand action token.", file=sys.stderr)
        raise SystemExit(1)

failures = [item for item in checks if item[3] + 1e-9 < item[4]]
for fg, bg, kind, value, threshold in checks:
    status = "FAIL" if value + 1e-9 < threshold else "PASS"
    print(f"{status} {kind}: {fg} on {bg} = {value:.2f}:1 (required {threshold:.1f}:1)")
if failures:
    print(f"Contrast check failed: {len(failures)} of {len(checks)} pairs.", file=sys.stderr)
    raise SystemExit(1)
print(f"Contrast check PASS: {len(checks)} token/surface pairs; ten complete tonal ramps verified.")
