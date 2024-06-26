#!/usr/bin/env bash
#
# summarize.sh
#
# Summarizes given text in Korean, with 'llamafile'
#
# created on : 2023.12.20.
# last update: 2024.04.25.

# llamafile path
WORKING_DIR="$(readlink -f "$(dirname "$0")")"
LLAMAFILE_PATH="$WORKING_DIR/Meta-Llama-3-8B-Instruct.Q5_K_M.llamafile"


################################
#
# variables for customization

# variables
TEMPERATURE=0
TOKENS_PREDICT=500
PROMPT_CONTEXT_SIZE=6700

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


# $1: text to summarize
function do_summarization {
    text="$1"

    # replace double quotes with unicode strings
    text=${text//\"/”}

    cmd="$LLAMAFILE_PATH -p \"User: 다음을 한국어로만 짧고 간단하게, 부연설명 없이 요약해 주세요: ${text}\nAssistant:\" --temp $TEMPERATURE -n $TOKENS_PREDICT -c $PROMPT_CONTEXT_SIZE --silent-prompt 2> /dev/null"
    # escape parenthesis before `eval`
    cmd=${cmd//\(/\\(}
    cmd=${cmd//\)/\\)}

    if [ "$verbose" == "true" ]; then
        error "[VERBOSE] will run command: \"$cmd\""
    fi
    result=$(eval "$cmd")

    info ">>>"
    info "$result"
}

function print_usage {
    info "Usage:"
    warn "  $ $0 [TEXT_TO_SUMMARIZE] [OTHER_PARAMETERS...]"
    info ""
    info "Example:"
    warn "  $ $0 \"파이트 클럽 규칙:
제1조: 파이트 클럽에 대해 말하지 않는다.
제2조: 파이트 클럽에 대해 말하지 않는다.
제3조: 누군가 '그만' 이라고 외치거나, 움직이지 못하거나, 땅을 치면 그만둔다.
제4조: 싸움은 1대 1로만 한다.
제5조: 한 번에 한 판만 벌인다.
제6조: 상의와 신발은 벗는다.
제7조: 싸울 수 있을 때까지 싸운다.
제8조: 여기 처음 온 사람은 반드시 싸운다.\" -v"
}


# (main)
if [ ! -x "$LLAMAFILE_PATH" ]; then
    error "Llamafile not found, or not executable: $LLAMAFILE_PATH"
    exit 1
fi
if [ $# -ge 1 ]; then
    do_summarization "$1"
else
    print_usage
fi

