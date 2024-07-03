#!/usr/bin/env bash
#
# gguf2llamafile.sh
#
# For building llamafiles from an existing .gguf file
#
# * Tested on:
#   - macOS Sonoma + Python 3.11.7
#
# created on : 2023.12.28.
# last update: 2024.07.03.


# XXX - for making newly created files/directories less restrictive
umask 0022


################################
#
# variables for customization

# https://github.com/Mozilla-Ocho/llamafile/releases
LLAMAFILE_VERSION="0.8.9"

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

WORKING_DIR="$(readlink -f "$(dirname "$0")")"
TOOLS_DIRNAME="llamafile_tools"
TOOLS_DIR="$WORKING_DIR/$TOOLS_DIRNAME"
LLAMAFILE_BIN_DIR="$TOOLS_DIR/llamafile/compiled/bin"
GMAKE_FILEPATH="$TOOLS_DIR/gmake"
LLAMAFILE_DIR="$TOOLS_DIR/llamafile"
LLAMAFILE_COMPILED_DIR="$LLAMAFILE_DIR/compiled"

#
################################



################################
#
# functions

# install needed tools for building llamafiles
function prep_tools {
    info "# preparing tools..." && \
        mkdir -p "$TOOLS_DIR" && \
        info "# building 'llamafile'..." && \
        wget -N "https://cosmo.zip/pub/cosmos/bin/gmake" -O "$GMAKE_FILEPATH" && \
        chmod +x "$GMAKE_FILEPATH" && \
        (git clone "https://github.com/Mozilla-Ocho/llamafile.git" "$LLAMAFILE_DIR" || true) && \
        cd "$LLAMAFILE_DIR" && \
        git checkout "$LLAMAFILE_VERSION" && \
        "$GMAKE_FILEPATH" -j$(nproc) install PREFIX="$LLAMAFILE_COMPILED_DIR"
}

# build llamafile with .gguf file
#
# $1: .gguf filepath
function build_llamafile {
    gguf_filepath="$1"

    cd "$WORKING_DIR" && \
        "$LLAMAFILE_BIN_DIR/llamafile-convert" "$gguf_filepath"
}

# do the real things
#
# $1: .gguf filepath
function do_things {
    gguf_filepath=$(readlink -f "$1")

    warn "# doing things with gguf filepath: $gguf_filepath ..."

    prep_tools && \
        build_llamafile "$gguf_filepath"
}

# print usage
function print_usage {
    info "Usage:"
    warn "  $ $0 [GGUF_FILEPATH]"
    info ""
    info "Example:"
    warn "  $ $0 ./mixtral-8x7b-instruct-v0.1.Q4_0.gguf"
}

#
################################




# (main)
if [ $# -ge 1 ]; then
    do_things "$1"
else
    print_usage
fi

