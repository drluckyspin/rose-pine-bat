#!/usr/bin/env bash
#
#  ╭───────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
#  │                                                                                                                   │
#  │                       ██████╗  ██████╗ ███████╗███████╗      ██████╗ ██╗███╗   ██╗███████╗                        │
#  │                       ██╔══██╗██╔═══██╗██╔════╝██╔════╝      ██╔══██╗██║████╗  ██║██╔════╝                        │
#  │                       ██████╔╝██║   ██║███████╗█████╗        ██████╔╝██║██╔██╗ ██║█████╗                          │
#  │                       ██╔══██╗██║   ██║╚════██║██╔══╝        ██╔═══╝ ██║██║╚██╗██║██╔══╝                          │
#  │                       ██║  ██║╚██████╔╝███████║███████╗      ██║     ██║██║ ╚████║███████╗                        │
#  │                       ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝      ╚═╝     ╚═╝╚═╝  ╚═══╝╚══════╝                        │
#  │                                                                                                                   │
#  │                                                      for bat                                                      │
#  │                                                                                                                   │
#  │   Install the Rosé Pine Moon syntax theme and set it as the default for bat.                                      │
#  │                                                                                                                   │
#  │   Usage:                                                                                                          │
#  │     ./install.bash                Install theme + default                                                         │
#  │     ./install.bash --install-bat  Also install bat via brew                                                       │
#  │     ./install.bash --help         Show full help                                                                  │
#  │                                                                                                                   │
#  ╰───────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_FILE="Rose-Pine-Moon.tmTheme"
THEME_ID="Rose-Pine-Moon"
INSTALL_BAT=false

usage() {
	cat <<'EOF'
Usage: ./install.bash [options]

Install the Rosé Pine Moon theme for bat and set it as the default.

Options:
  --install-bat   Install bat via Homebrew if it is missing (macOS/Linux with brew)
  -h, --help      Show this help message

Without options, the script expects bat to already be installed.
EOF
}

log() {
	printf '==> %s\n' "$*"
}

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--install-bat)
		INSTALL_BAT=true
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		die "unknown option: $1 (try --help)"
		;;
	esac
done

ensure_bat() {
	if command -v bat >/dev/null 2>&1; then
		log "found $(bat --version | head -n1)"
		return 0
	fi

	if [[ "$INSTALL_BAT" == true ]] && command -v brew >/dev/null 2>&1; then
		log "installing bat via Homebrew"
		brew install bat
		return 0
	fi

	die "bat is not installed. Install it from https://github.com/sharkdp/bat or re-run with --install-bat (requires Homebrew)."
}

install_theme() {
	local source_theme="$SCRIPT_DIR/themes/$THEME_FILE"
	local themes_dir config_dir

	[[ -f "$source_theme" ]] || die "theme file not found: $source_theme"

	config_dir="$(bat --config-dir)"
	themes_dir="$config_dir/themes"

	log "copying $THEME_FILE to $themes_dir"
	mkdir -p "$themes_dir"
	cp "$source_theme" "$themes_dir/"

	log "rebuilding bat theme cache"
	bat cache --build

	log "checking that bat registered the theme"
	if bat --list-themes | grep -qi rose; then
		printf '    %s is available\n' "$THEME_ID"
	else
		die "theme was copied but $THEME_ID was not found in 'bat --list-themes'"
	fi
}

set_default_theme() {
	local config_file="$bat_config_dir/config"
	local theme_line='--theme="Rose-Pine-Moon"'

	if [[ -f "$config_file" ]] && grep -Fq -- "$theme_line" "$config_file"; then
		log "default theme already set in $config_file"
		return 0
	fi

	log "setting default theme in $config_file"
	mkdir -p "$bat_config_dir"
	printf '%s\n' "$theme_line" >>"$config_file"
}

ensure_bat
bat_config_dir="$(bat --config-dir)"
install_theme
set_default_theme

cat <<EOF

Done. Try it with:

  bat README.md
EOF
