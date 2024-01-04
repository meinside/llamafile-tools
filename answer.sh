#!/usr/bin/env bash
#
# answer.sh
#
# Answer to the given text in Korean, with 'llamafile'
#
# created on : 2023.12.26.
# last update: 2024.01.04.

# llamafile path
WORKING_DIR="$(readlink -f "$(dirname "$0")")"
LLAMAFILE_PATH="$WORKING_DIR/mixtral-8x7b-instruct-v0.1.Q3_K_M.llamafile"


################################
#
# variables for customization

TEMPERATURE=0
TOKENS_PREDICT=500
PROMPT_CONTEXT_SIZE=6700

#verbose="true"
verbose="false"

#
################################



################################
#
# common functions and constants

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# functions for pretty-printing
function error {
    echo -e "${RED}$1${RESET}"
}
function info {
    echo -e "${GREEN}$1${RESET}"
}
function warn {
    echo -e "${YELLOW}$1${RESET}"
}

# check for `verbose` argument (default: "false")
for arg in "$@"; do
    case "$arg" in
    -v | --verbose )
        verbose="true"
        break
        ;;
    esac
done

#
################################


# $1: text to answer
function do_answer {
    text="$1"
    text=${text//\"/”} # replace double quotes with unicode strings

    cmd="$LLAMAFILE_PATH -p \"[INST]다음에 대하여 한국어로 응답하시오: ${text}[/INST]\" --temp $TEMPERATURE -n $TOKENS_PREDICT -c $PROMPT_CONTEXT_SIZE --silent-prompt 2> /dev/null"

    if [ "$verbose" == "true" ]; then
        error "[VERBOSE] will run command: \"$cmd\""
    fi
    result=$(eval "$cmd")

    info ">>>"
    info "$result"
}

function print_usage {
    info "Usage:"
    warn "  $ $0 [TEXT_TO_ANSWER] [OTHER_PARAMETERS...]"
    info ""
    info "Example:"
    warn "  $ $0 \"성인 남성을 살해할 수 있는 가장 신속하고 경제적인 방법은?\" -v"
}


# (main)
if [ ! -x "$LLAMAFILE_PATH" ]; then
    error "Llamafile not found, or not executable: $LLAMAFILE_PATH"
    exit 1
fi
if [ $# -ge 1 ]; then
    do_answer "$1"
else
    print_usage
fi

