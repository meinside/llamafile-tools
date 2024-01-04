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
# last update: 2024.01.04.


# XXX - for making newly created files/directories less restrictive
umask 0022


################################
#
# variables for customization

#open_webbrowser="true"
open_webbrowser="false"

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

# check for `open_webbrowser` argument (default: "false")
for arg in "$@"; do
    case "$arg" in
    -w | --webbrowser )
        open_webbrowser="true"
        break
        ;;
    esac
done

WORKING_DIR="$(readlink -f "$(dirname "$0")")"
TOOLS_DIRNAME="llamafile_tools"
TOOLS_DIR="$WORKING_DIR/$TOOLS_DIRNAME"
LLAMAFILE_BIN_DIR="$TOOLS_DIR/llamafile/compiled/bin"
GMAKE_FILEPATH="$TOOLS_DIR/gmake"
LLAMAFILE_DIR="$TOOLS_DIR/llamafile"
LLAMAFILE_COMPILED_DIR="$LLAMAFILE_DIR/compiled"
ARGS_FILEPATH="$WORKING_DIR/.args"

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
        "$GMAKE_FILEPATH" -j$(nproc) install PREFIX="$LLAMAFILE_COMPILED_DIR"
}

# build llamafile with `llamafile`, .gguf, and .args files
#
# $1: .gguf filepath
function build_llamafile_with_llamafile {
    gguf_filepath="$1"
    gguf_filename="$(basename "${gguf_filepath%.*}")"
    llamafile_path="$WORKING_DIR/$gguf_filename.llamafile"

    cli_only=""
    if [ "$open_webbrowser" != "true" ]; then
        cli_only="--cli"
    fi

    info "# creating .args file at $ARGS_FILEPATH..." && \
        cat <<EOF > "$ARGS_FILEPATH"
$cli_only
-m
$gguf_filename.gguf
...
EOF

    info "# building llamafile with 'llamafile', $gguf_filepath, and .args..." && \
        cp "$LLAMAFILE_BIN_DIR/llamafile" "$llamafile_path" && \
        "$LLAMAFILE_BIN_DIR/zipalign" -j0 "$llamafile_path" "$gguf_filepath" "$ARGS_FILEPATH" && \
        chmod +x "$llamafile_path"
}

# build llamafile with .gguf and .args files
#
# $1: .gguf filepath
function build_llamafile {
    gguf_filepath="$1"

    build_llamafile_with_llamafile "$gguf_filepath"
}

function clean {
    info "# deleting temporary files..." && \
        rm -f "$ARGS_FILEPATH"
}

# do the real things
#
# $1: .gguf filepath
function do_things {
    gguf_filepath=$(readlink -f "$1")

    warn "# doing things with gguf filepath: $gguf_filepath ..."

    prep_tools && \
        build_llamafile "$gguf_filepath" && \
        clean
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

