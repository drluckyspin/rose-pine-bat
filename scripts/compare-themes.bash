#!/usr/bin/env bash
#
# compare-themes.bash — preview the Rosé Pine bat themes side by side.
# Renders color swatches for the values that differ between variants, then
# highlights a sample snippet with each installed theme using bat.
#
# Usage: ./scripts/compare-themes.bash
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
THEMES_DIR="$REPO_DIR/themes"

# Force 24-bit color so the true palette shows (not 256-color fallback).
export COLORTERM=truecolor

reset=$'\033[0m'

swatch() {
	# swatch "r;g;b" "#hex" "label"
	printf '   \033[48;2;%sm        %s  \033[38;2;%sm%-8s%s  %s\n' "$1" "$reset" "$1" "$2" "$reset" "$3"
}

heading() {
	printf '\n\033[1m%s\033[0m\n' "$1"
}

heading "Differing colors  —  Moon  vs  Main  vs  Dawn"

printf '\n  Background:\n'
swatch "25;23;36" "#191724" "Moon — dark"
swatch "25;23;36" "#191724" "Main — dark"
swatch "250;244;237" "#faf4ed" "Dawn — light"

printf '\n  Keyword (if / return / const / function):\n'
swatch "62;143;176" "#3e8fb0" "Moon — brighter blue"
swatch "49;116;143" "#31748f" "Main — muted teal"
swatch "40;105;131" "#286983" "Dawn — deep pine"

printf '\n  Function names:\n'
swatch "234;154;151" "#ea9a97" "Moon — warm peach"
swatch "235;188;186" "#ebbcba" "Main — softer pink"
swatch "215;130;126" "#d7827e" "Dawn — dusty rose"

printf '\n  lineHighlight (current-line background):\n'
swatch "42;39;63" "#2a273f" "Moon — lighter"
swatch "31;29;46" "#1f1d2e" "Main — darker"
swatch "255;250;243" "#fffaf3" "Dawn — surface"

printf '\n  selection (selected-text background):\n'
swatch "68;65;90" "#44415a" "Moon — lighter"
swatch "64;61;82" "#403d52" "Main — darker"
swatch "223;218;217" "#dfdad9" "Dawn — highlight med"

# -----------------------------------------------------------------------------
# Live bat render of a sample snippet in each theme.
# -----------------------------------------------------------------------------
if ! command -v bat >/dev/null 2>&1; then
	printf '\n(bat is not installed — run ./install.bash to see the live render.)\n'
	exit 0
fi

# Use a throwaway bat config so this works even if the themes are not installed
# in your real config, and never touches your setup.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
export BAT_CONFIG_DIR="$TMP_DIR/cfg" BAT_CACHE_PATH="$TMP_DIR/cache"
mkdir -p "$BAT_CONFIG_DIR/themes" "$BAT_CACHE_PATH"
cp "$THEMES_DIR"/*.tmTheme "$BAT_CONFIG_DIR/themes/"
bat cache --build >/dev/null 2>&1

SAMPLE="$TMP_DIR/sample.js"
cat >"$SAMPLE" <<'EOF'
// fetch a user and greet them
const greeting = "Hello";
function greetUser(name, count = 3) {
  return `${greeting}, ${name}!`.repeat(count);
}
EOF

for theme_file in "$THEMES_DIR"/*.tmTheme; do
	theme_id="$(basename "$theme_file" .tmTheme)"
	heading "bat theme: $theme_id"
	bat --color=always --theme="$theme_id" --style=numbers "$SAMPLE"
done

printf '\n'
