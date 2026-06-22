#!/bin/bash

# -----------------------------------------------------------------------------------------------------------
# Script Name: log.bash
# Version: 1.9
#
# Project: Rose Pin Bat
#
# Description: A collection of logging utility functions for bash scripts that
#              provide colored and formatted console output using the Rosé Pine
#              Moon palette from themes/Rose-Pine-Moon.tmTheme.
#
# Functions:
#   get_terminal_width : Get current terminal width (max 120 chars)
#   log                : Text logging (#e0def4 foreground)
#   log_dim            : Muted text logging (#6e6a86)
#   log_info           : Info messages (#3e8fb0 keyword)
#   log_info_dim       : Dimmed info messages
#   log_success        : Success messages (#9ccfd8 foam)
#   log_error          : Error messages (#eb6f92 love)
#   log_warning        : Warning messages (#f6c177 gold)
#   log_indent         : Indent (2 spaces) and call any log function (usage: log_indent log_success "message")
#   log_separator      : Print a separator line across terminal width
#   log_centered       : Print centered text
#   log_verbose        : Log message only if VERBOSE environment variable is true
#   log_banner         : Display Rose Pin Bat ASCII art banner
# -----------------------------------------------------------------------------------------------------------
# Usage Example: source scripts/log.bash
# -----------------------------------------------------------------------------------------------------------

# -----------------------------------------------------------------------------------------------------------
# Global variables
# -----------------------------------------------------------------------------------------------------------
VERBOSE=false

# -----------------------------------------------------------------------------------------------------------
# Rosé Pine Moon palette (themes/Rose-Pine-Moon.tmTheme)
# -----------------------------------------------------------------------------------------------------------
RP_TEXT='\033[38;2;224;222;244m'   # #e0def4 foreground
RP_MUTED='\033[38;2;110;106;134m'  # #6e6a86 muted / comment
RP_INFO='\033[38;2;62;143;176m'    # #3e8fb0 keyword
RP_FOAM='\033[38;2;156;207;216m'   # #9ccfd8 foam
RP_LOVE='\033[38;2;235;111;146m'   # #eb6f92 love / error
RP_GOLD='\033[38;2;246;193;119m'   # #f6c177 gold / warning
RP_IRIS='\033[38;2;196;167;231m'   # #c4a7e7 iris
WHITE='\033[38;2;255;255;255m'     # #ffffff white
RESET='\033[0m'
DIM='\033[2m'


# -----------------------------------------------------------------------------------------------------------
# Function: get_terminal_width
# Description: Get current terminal width (max 120 chars)
# -----------------------------------------------------------------------------------------------------------
get_terminal_width() {
    local width
    width=$(tput cols)
    if [ "$width" -gt 120 ]; then
        width=120
    fi
    echo "$width"
}

# -----------------------------------------------------------------------------------------------------------
# Basic Logging functions for consistent console output
# -----------------------------------------------------------------------------------------------------------

log() {
    echo -e "${RP_TEXT} $1${RESET}"
}

log_dim() {
    echo -e "${RP_MUTED} $1${RESET}"
}

log_info() {
    echo -e "${RP_INFO} $1${RESET}"
}

log_info_dim() {
    echo -e "${DIM}${RP_INFO} $1${RESET}"
}

log_success() {
    echo -e " ${RP_FOAM}✔${RESET} ${DIM}${RP_FOAM} $1${RESET}"
}

log_error() {
    echo -e " ${RP_LOVE}🅇${RESET}  ${DIM}${RP_LOVE}$1${RESET}"
}

log_warning() {
    echo -e " ${RP_GOLD}▲${RESET}  ${DIM}${RP_GOLD}$1${RESET}"
}

# -----------------------------------------------------------------------------------------------------------
# Function: log_separator
# Description: Print a separator line across terminal width
# -----------------------------------------------------------------------------------------------------------
log_separator() {
    local terminal_width
    terminal_width=$(get_terminal_width)
    printf "${RP_MUTED}"
    printf "=-%.0s" $(seq 1 $((terminal_width / 2)))
    echo -e "=${RESET}"
}

# -----------------------------------------------------------------------------------------------------------
# Function: log_indent
# Description: Indent (2 spaces) and call any log function (usage: log_indent log_success "message")
# -----------------------------------------------------------------------------------------------------------
log_indent() {
    local log_func=$1
    shift
    printf "  "
    $log_func "$@"
}

# -----------------------------------------------------------------------------------------------------------
# Function: log_centered
# Description: Center a message in the terminal.
# -----------------------------------------------------------------------------------------------------------
log_centered() {
    local terminal_width
    local message="$1"
    terminal_width=$(get_terminal_width)

    # Calculate padding
    local padding=$(((terminal_width - ${#message}) / 2))

    # Create padding string
    local pad_str
    pad_str=$(printf '%*s' "$padding" '')

    # Print centered message
    echo -e "${pad_str}${RP_TEXT}${message}${RESET}"
}

# -----------------------------------------------------------------------------------------------------------
# Function: log_verbose
# Description: Log message only if VERBOSE environment variable is true
# -----------------------------------------------------------------------------------------------------------
log_verbose() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        log_info_dim "$*"
    fi
}

# -----------------------------------------------------------------------------------------------------------
# Function: log_banner
# Description: Show the Rose Pin Bat banner.
# -----------------------------------------------------------------------------------------------------------
log_banner() {

    echo -e "
    ${RP_IRIS}██████╗  ██████╗ ███████╗███████╗    ██████╗ ██╗███╗   ██╗███████╗
    ${RP_IRIS}██╔══██╗██╔═══██╗██╔════╝██╔════╝    ██╔══██╗██║████╗  ██║██╔════╝
    ${RP_IRIS}██████╔╝██║   ██║███████╗█████╗      ██████╔╝██║██╔██╗ ██║█████╗  
    ${RP_IRIS}██╔══██╗██║   ██║╚════██║██╔══╝      ██╔═══╝ ██║██║╚██╗██║██╔══╝  
    ${RP_IRIS}██║  ██║╚██████╔╝███████║███████╗    ██║     ██║██║ ╚████║███████╗
    ${RP_IRIS}╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═══╝╚══════╝
    ${RP_MUTED}                                         a ${RP_LOVE}Rosé Pine${RP_MUTED} theme for ${RP_FOAM}Bat${RESET}
    "
}


# -----------------------------------------------------------------------------------------------------------
# Example usage
# -----------------------------------------------------------------------------------------------------------   
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_separator
    log_banner
    log "This is a normal message."
    log_dim "This is a dim message."
    log_info "This is an info message."
    log_info_dim "This is a dim info message."
    log_success "This is a success message."
    log_warning "This is a warning message."
    log_error "This is an error message."
    log_indent log_success "This is an indented message."
    log_centered "This is a centered message"
    log_separator
fi
