#!/usr/bin/env bash
#
# answer.sh
#
# Answer to the given text in Korean, with 'llamafile'
#
# * Referenced:
#   - https://justine.lol/oneliners/
#
# created on : 2023.12.26.
# last update: 2023.12.27.

# llamafile path
WORKING_DIR="$(readlink -f "$(dirname "$0")")"
SUMMARIZER_LLAMAFILE_PATH="$WORKING_DIR/Mistral-7B-Instruct-v0.2(f16).llamafile"

# variables
TEMPERATURE=0
TOKENS_PREDICT=500
PROMPT_CONTEXT_SIZE=6700


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


# $1: text to answer
function do_answer {
    text="$1"
    result=$($SUMMARIZER_LLAMAFILE_PATH -p "[INST]다음에 대하여 한국어로 응답하시오: ${text}[/INST]" --temp $TEMPERATURE -n $TOKENS_PREDICT -c $PROMPT_CONTEXT_SIZE --silent-prompt 2> /dev/null)

    info ">>>"
    info "$result"
}

function print_usage {
    info "Usage:"
    warn "  $ $0 [TEXT_TO_ANSWER]"
    info ""
    info "Example:"
    warn "  $ $0 \"성인 남성을 살해할 수 있는 가장 신속하고 경제적인 방법은?\""
}


# (main)
if [ $# -ge 1 ]; then
    do_answer "$1"
else
    print_usage
fi

