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
#  │   Install one or more Rosé Pine syntax themes for bat and set a default.                                          │
#  │                                                                                                                   │
#  │   Usage:                                                                                                          │
#  │     ./install.bash                Pick theme(s) with a checkbox menu, then choose a default                       │
#  │     ./install.bash --all          Install every theme (non-interactive)                                           │
#  │     ./install.bash --theme NAME   Install a specific theme (repeatable)                                           │
#  │     ./install.bash --help         Show full help                                                                  │
#  │                                                                                                                   │
#  ╰───────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_SRC_DIR="$SCRIPT_DIR/themes"
FALLBACK_DEFAULT="Rose-Pine-Moon"

INSTALL_BAT=false
ALL=false
THEME_ARGS=()
DEFAULT_FLAG=""

# Import shared logging helpers (banner, colors, log_info/success/error, ...)
source "$SCRIPT_DIR/scripts/log.bash"

# Always restore the terminal cursor, even if we exit mid-menu.
trap 'printf "\033[?25h"' EXIT

usage() {
	log_banner
	log_info "Usage: ./install.bash [options]"
	echo ""
	log_dim "Install one or more Rosé Pine themes for bat and set a default."
	echo ""
	log_info "Options:"
	log_indent log "--all            ${DIM}Install all available themes (non-interactive)"
	log_indent log "--theme NAME     ${DIM}Install a specific theme; repeatable (e.g. --theme Rose-Pine-Moon)"
	log_indent log "--default NAME   ${DIM}Set NAME as bat's default theme"
	log_indent log "--install-bat    ${DIM}Install bat via Homebrew without prompting"
	log_indent log "-h, --help       ${DIM}Show this help message"
	echo ""
	log_dim "Interactively, pick themes with a checkbox menu (↑/↓ move, space toggle, enter confirm)."
	log_dim "Non-interactively (piped/CI), all themes install and $FALLBACK_DEFAULT becomes the default."
}

die() {
	log_error "$*"
	exit 1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--all)
		ALL=true
		shift
		;;
	--theme)
		[[ $# -ge 2 ]] || die "--theme requires a theme name"
		THEME_ARGS+=("$2")
		shift 2
		;;
	--default)
		[[ $# -ge 2 ]] || die "--default requires a theme name"
		DEFAULT_FLAG="$2"
		shift 2
		;;
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

# -----------------------------------------------------------------------------------------------------------
# bat dependency
# -----------------------------------------------------------------------------------------------------------
install_bat_via_brew() {
	log_info "Installing bat via Homebrew"
	brew install bat
	log_success "bat installed"
}

prompt_install_bat() {
	if ! command -v brew >/dev/null 2>&1; then
		die "bat is not installed and Homebrew was not found. Install bat from https://github.com/sharkdp/bat"
	fi

	if [[ "$INSTALL_BAT" == true ]]; then
		install_bat_via_brew
		return 0
	fi

	if [[ ! -t 0 ]]; then
		die "bat is not installed. Install it from https://github.com/sharkdp/bat or re-run with --install-bat (requires Homebrew)."
	fi

	printf 'bat is not installed. Install it via Homebrew? [y/N] ' >&2
	read -r reply
	case "$reply" in
	[yY] | [yY][eE][sS])
		install_bat_via_brew
		;;
	*)
		die "bat is required. Install it from https://github.com/sharkdp/bat"
		;;
	esac
}

ensure_bat() {
	if command -v bat >/dev/null 2>&1; then
		log_indent log_success "$(bat --version | head -n1) is installed."
		return 0
	fi

	prompt_install_bat
}

# -----------------------------------------------------------------------------------------------------------
# Theme discovery
# -----------------------------------------------------------------------------------------------------------
THEME_IDS=()
discover_themes() {
	local f
	THEME_IDS=()
	for f in "$THEMES_SRC_DIR"/*.tmTheme; do
		[[ -e "$f" ]] || continue
		THEME_IDS+=("$(basename "$f" .tmTheme)")
	done
}

is_known_theme() {
	local needle="$1" t
	for t in "${THEME_IDS[@]}"; do
		[[ "$t" == "$needle" ]] && return 0
	done
	return 1
}

in_selection() {
	local needle="$1" t
	for t in "${SELECTED_IDS[@]}"; do
		[[ "$t" == "$needle" ]] && return 0
	done
	return 1
}

# -----------------------------------------------------------------------------------------------------------
# Minimal pure-bash TUI selectors (no external deps)
#   - read_key   : read a single keypress (handles arrow escape sequences)
#   - multiselect: checkbox list -> SELECTED_IDS
#   - choose_one : radio list     -> DEFAULT_ID
# -----------------------------------------------------------------------------------------------------------
KEY=""
read_key() {
	KEY=""
	local rest
	IFS= read -rsn1 KEY || { KEY="cancel"; return; }
	if [[ "$KEY" == $'\e' ]]; then
		# Arrow/function keys send more bytes immediately. bash >= 4 supports
		# fractional timeouts (snappy lone-ESC handling); bash 3.2 only integers.
		if ((BASH_VERSINFO[0] >= 4)); then
			IFS= read -rsn2 -t 0.01 rest || true
		else
			IFS= read -rsn2 -t 1 rest || true
		fi
		KEY+="$rest"
	fi
}

SELECTED_IDS=()
multiselect() {
	local items=("$@")
	local n=${#items[@]}
	local -a state
	local i cur=0
	for ((i = 0; i < n; i++)); do state[i]=1; done

	_ms_render() {
		for ((i = 0; i < n; i++)); do
			local ptr="  " mark
			[[ $i -eq $cur ]] && ptr="❯ "
			if [[ ${state[i]} -eq 1 ]]; then
				mark="${RP_FOAM}[✔]${RESET}"
			else
				mark="${RP_MUTED}[ ]${RESET}"
			fi
			printf "  ${RP_IRIS}%s${RESET}%b ${RP_TEXT}%s${RESET}\033[K\n" "$ptr" "$mark" "${items[i]}"
		done
	}

	printf '\033[?25l'
	_ms_render
	while true; do
		read_key
		case "$KEY" in
		$'\e[A' | k) cur=$(((cur - 1 + n) % n)) ;;
		$'\e[B' | j) cur=$(((cur + 1) % n)) ;;
		' ') state[cur]=$((1 - ${state[cur]})) ;;
		a | A) for ((i = 0; i < n; i++)); do state[i]=1; done ;;
		n | N) for ((i = 0; i < n; i++)); do state[i]=0; done ;;
		"") break ;;
		cancel | q | Q | $'\e') printf '\033[?25h'; die "Selection cancelled" ;;
		esac
		printf '\033[%dA' "$n"
		_ms_render
	done
	printf '\033[?25h'

	SELECTED_IDS=()
	for ((i = 0; i < n; i++)); do
		[[ ${state[i]} -eq 1 ]] && SELECTED_IDS+=("${items[i]}")
	done
	return 0
}

DEFAULT_ID=""
choose_one() {
	local items=("$@")
	local n=${#items[@]}
	local i cur=0

	_co_render() {
		for ((i = 0; i < n; i++)); do
			if [[ $i -eq $cur ]]; then
				printf "  ${RP_IRIS}❯ ${RP_FOAM}%s${RESET}\033[K\n" "${items[i]}"
			else
				printf "    ${RP_TEXT}%s${RESET}\033[K\n" "${items[i]}"
			fi
		done
	}

	printf '\033[?25l'
	_co_render
	while true; do
		read_key
		case "$KEY" in
		$'\e[A' | k) cur=$(((cur - 1 + n) % n)) ;;
		$'\e[B' | j) cur=$(((cur + 1) % n)) ;;
		"") break ;;
		cancel | q | Q | $'\e') printf '\033[?25h'; die "Selection cancelled" ;;
		esac
		printf '\033[%dA' "$n"
		_co_render
	done
	printf '\033[?25h'

	DEFAULT_ID="${items[cur]}"
	return 0
}

# -----------------------------------------------------------------------------------------------------------
# Resolve which themes to install (flags > non-interactive > interactive menu)
# -----------------------------------------------------------------------------------------------------------
resolve_selection() {
	if [[ "$ALL" == true ]]; then
		SELECTED_IDS=("${THEME_IDS[@]}")
		log_info "Installing all themes"
		return
	fi

	if [[ ${#THEME_ARGS[@]} -gt 0 ]]; then
		local t name
		SELECTED_IDS=()
		for t in "${THEME_ARGS[@]}"; do
			name="${t%.tmTheme}"
			is_known_theme "$name" || die "unknown theme: $t (available: ${THEME_IDS[*]})"
			SELECTED_IDS+=("$name")
		done
		log_info "Installing selected theme(s)"
		return
	fi

	if [[ ! -t 0 || ! -t 1 ]]; then
		SELECTED_IDS=("${THEME_IDS[@]}")
		log_info_dim "Non-interactive: installing all themes"
		return
	fi

	log_info "Select themes to install"
	log_indent log_dim "↑/↓ move · space toggle · a all · n none · enter confirm"
	multiselect "${THEME_IDS[@]}"
	[[ ${#SELECTED_IDS[@]} -gt 0 ]] || die "No themes selected"
}

# -----------------------------------------------------------------------------------------------------------
# Resolve the default theme (flag > single selection > non-interactive > interactive pick)
# -----------------------------------------------------------------------------------------------------------
resolve_default() {
	if [[ -n "$DEFAULT_FLAG" ]]; then
		local d="${DEFAULT_FLAG%.tmTheme}"
		in_selection "$d" || die "--default $DEFAULT_FLAG is not among the installed themes (${SELECTED_IDS[*]})"
		DEFAULT_ID="$d"
		return
	fi

	if [[ ${#SELECTED_IDS[@]} -eq 1 ]]; then
		DEFAULT_ID="${SELECTED_IDS[0]}"
		return
	fi

	# Flags or no TTY -> deterministic, no prompt.
	if [[ "$ALL" == true || ${#THEME_ARGS[@]} -gt 0 || ! -t 0 || ! -t 1 ]]; then
		if in_selection "$FALLBACK_DEFAULT"; then
			DEFAULT_ID="$FALLBACK_DEFAULT"
		else
			DEFAULT_ID="${SELECTED_IDS[0]}"
		fi
		return
	fi

	log_info "Choose the default theme"
	log_indent log_dim "↑/↓ move · enter confirm"
	choose_one "${SELECTED_IDS[@]}"
}

# -----------------------------------------------------------------------------------------------------------
# Install + verify the selected themes, then wire up the default in bat's config
# -----------------------------------------------------------------------------------------------------------
install_selected_themes() {
	local themes_dir="$bat_config_dir/themes"
	local id src listed

	mkdir -p "$themes_dir"
	log_info "Installing ${#SELECTED_IDS[@]} theme(s)"
	for id in "${SELECTED_IDS[@]}"; do
		src="$THEMES_SRC_DIR/$id.tmTheme"
		[[ -f "$src" ]] || die "theme file not found: $src"
		log_indent log_dim "Copying $id.tmTheme"
		cp "$src" "$themes_dir/"
	done

	log_indent log_dim "Rebuilding bat theme cache"
	bat cache --build >/dev/null

	listed="$(bat --list-themes)"
	for id in "${SELECTED_IDS[@]}"; do
		if printf '%s\n' "$listed" | grep -Fq -- "$id"; then
			log_indent log_success "$id"
		else
			die "theme $id was copied but not found in 'bat --list-themes'"
		fi
	done
}

set_default_theme() {
	local config_file="$bat_config_dir/config"
	local desired="--theme=\"$DEFAULT_ID\""
	local tmp

	mkdir -p "$bat_config_dir"
	touch "$config_file"

	if grep -Fxq -- "$desired" "$config_file"; then
		log_info_dim "Default theme already set to $DEFAULT_ID"
		return 0
	fi

	# Drop any previous Rosé Pine default so we don't stack --theme lines.
	tmp="$(mktemp)"
	grep -v -E '^--theme="Rose-Pine[^"]*"$' "$config_file" >"$tmp" || true
	mv "$tmp" "$config_file"

	printf '%s\n' "$desired" >>"$config_file"
	log_success "Default theme set to $DEFAULT_ID"
}

# -----------------------------------------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------------------------------------
log_separator
log_banner

log_info "Checking dependencies"
ensure_bat
bat_config_dir="$(bat --config-dir)"

discover_themes
[[ ${#THEME_IDS[@]} -gt 0 ]] || die "no .tmTheme files found in $THEMES_SRC_DIR"

resolve_selection
install_selected_themes
resolve_default
set_default_theme

echo ""
log_success "All done! Try it with: ${RP_GOLD}bat README.md${RESET}"
