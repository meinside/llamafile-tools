#!/usr/bin/env bash
#
# hf2llamafile.sh
#
# For building llamafiles from HuggingFace model id
#
# * Tested on:
#   - macOS Sonoma + Python 3.11.7
#
# created on : 2023.12.19.
# last update: 2024.01.04.


# XXX - for making newly created files/directories less restrictive
umask 0022


################################
#
# variables for customization

#outtype="f32"
outtype="f16"
#outtype="q8_0"
#outtype="q4_0"

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

# check for outtype argument (default: "f16")
for arg in "$@"; do
    case "$arg" in
    -f32 | --f32 )
        outtype="f32"
        break
        ;;
    -q80 | --q8_0 )
        outtype="q8_0"
        break
        ;;
    -q40 | --q4_0 )
        outtype="q4_0"
        break
        ;;
    esac
done

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
HF_MODELS_DIRNAME="hf_models"
TOOLS_DIR="$WORKING_DIR/$TOOLS_DIRNAME"
HF_MODELS_DIR="$WORKING_DIR/$HF_MODELS_DIRNAME"
DOWNLOAD_SCRIPT_FILEPATH="$WORKING_DIR/download.py"
LLAMACPP_DIR="$TOOLS_DIR/llama.cpp"
LLAMAFILE_BIN_DIR="$TOOLS_DIR/llamafile/compiled/bin"
GMAKE_FILEPATH="$TOOLS_DIR/gmake"
CONVERT_SCRIPT_FILEPATH="$TOOLS_DIR/llama.cpp/convert.py"
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
        info "# cloning 'llama.cpp'..." && \
        (git clone "https://github.com/ggerganov/llama.cpp.git" "$LLAMACPP_DIR" || true) && \
        pip install -r "$LLAMACPP_DIR/requirements.txt" && \
        info "# building 'llamafile'..." && \
        wget -N "https://cosmo.zip/pub/cosmos/bin/gmake" -O "$GMAKE_FILEPATH" && \
        chmod +x "$GMAKE_FILEPATH" && \
        (git clone "https://github.com/Mozilla-Ocho/llamafile.git" "$LLAMAFILE_DIR" || true) && \
        cd "$LLAMAFILE_DIR" && \
        "$GMAKE_FILEPATH" -j$(nproc) install PREFIX="$LLAMAFILE_COMPILED_DIR"
}

# download HuggingFace model files
#
# $1: model id of HuggingFace
function download_hf_model {
    model_id="$1"
    gguf_filename="$(dirname "$model_id").$(basename "$model_id")"
    gguf_filepath="$WORKING_DIR/$gguf_filename.gguf"

    if [ -f "$gguf_filepath" ]; then
        warn "# reusing already-converted gguf file: $gguf_filepath, skipping downloading..."
    else
        mkdir -p "$HF_MODELS_DIR"

        model_dir="$HF_MODELS_DIR/$gguf_filename"

        info "# creating $DOWNLOAD_SCRIPT_FILEPATH with model id: ${model_id}, dir: ${model_dir}..." && \
            cat <<EOF > "$DOWNLOAD_SCRIPT_FILEPATH"
from huggingface_hub import snapshot_download

model_id="$model_id"
dir="$model_dir"

snapshot_download(repo_id=model_id, local_dir=dir,
                  local_dir_use_symlinks=False, revision="main")
EOF

        info "# executing $DOWNLOAD_SCRIPT_FILEPATH..." && \
            python "$DOWNLOAD_SCRIPT_FILEPATH"
    fi
}

# convert downloaded HuggingFace model files to .gguf format
#
# $1: model id of HuggingFace
function convert_hf_model_to_gguf {
    model_id="$1"
    gguf_filename="$(dirname "$model_id").$(basename "$model_id")"
    gguf_filepath="$WORKING_DIR/$gguf_filename.gguf"

    if [ -f "$gguf_filepath" ]; then
        warn "# reusing already-converted gguf file: $gguf_filepath, skipping converting..."
    else
        model_dir="$HF_MODELS_DIR/$gguf_filename"

        info "# converting HuggingFace model files at $model_dir..." && \
            python "$CONVERT_SCRIPT_FILEPATH" "$model_dir" --outfile "$gguf_filepath" --outtype "$outtype"
    fi
}

# build llamafile with `llamafile`, .gguf, and .args files
#
# $1: model id of HuggingFace
function build_llamafile_with_llamafile {
    model_id="$1"
    gguf_filename="$(dirname "$model_id").$(basename "$model_id")"
    gguf_filepath="$WORKING_DIR/$gguf_filename.gguf"
    llamafile_path="$WORKING_DIR/$gguf_filename($outtype).llamafile"

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

    info "# building llamafile with 'llamafile', $gguf_filename, and .args..." && \
        cp "$LLAMAFILE_BIN_DIR/llamafile" "$llamafile_path" && \
        "$LLAMAFILE_BIN_DIR/zipalign" -j0 "$llamafile_path" "$gguf_filepath" "$ARGS_FILEPATH" && \
        chmod +x "$llamafile_path"
}

# build llamafile with .gguf and .args files
#
# $1: model id of HuggingFace
function build_llamafile {
    model_id="$1"

    build_llamafile_with_llamafile "$model_id"
}

function clean {
    info "# deleting temporary files..." && \
        rm -f "$DOWNLOAD_SCRIPT_FILEPATH" "$ARGS_FILEPATH"
}

# do the real things
#
# $1: model id of HuggingFace
function do_things {
    model_id="$1"

    warn "# doing things with HuggingFace model id: $model_id ..."

    prep_tools && \
        download_hf_model "$model_id" && \
        convert_hf_model_to_gguf "$model_id" && \
        build_llamafile "$model_id" && \
        clean
}

# print usage
function print_usage {
    info "Usage:"
    warn "  $ $0 [HUGGING_FACE_MODEL_ID]"
    info ""
    info "Example:"
    warn "  $ $0 meta-llama/Llama-2-7b"
}

#
################################




# (main)
if [ $# -ge 1 ]; then
    do_things "$1"
else
    print_usage
fi

