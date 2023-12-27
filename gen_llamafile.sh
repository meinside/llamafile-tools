#!/usr/bin/env bash
#
# gen_llamafile.sh
#
# For building llamafiles easily, repeatedly.
#
# * Tested on:
#   - macOS Sonoma + Python 3.11.7
#
# created on : 2023.12.19.
# last update: 2023.12.27.


# XXX - for making newly created files/directories less restrictive
umask 0022


################################
#
# variables for customization

#OUTTYPE="f32"
OUTTYPE="f16"
#OUTTYPE="q8_0"
#OUTTYPE="q4_0"

#BUILD_WITH_WEBSERVER="true"
BUILD_WITH_WEBSERVER="false"

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

        model_id="$1"
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
            python "$CONVERT_SCRIPT_FILEPATH" "$model_dir" --outfile "$gguf_filepath" --outtype "$OUTTYPE"
    fi
}

# build llamafile with `llamafile`, .gguf, and .args files
#
# $1: model id of HuggingFace
function build_llamafile_with_llamafile {
    model_id="$1"
    model_dir="$HF_MODELS_DIR/$(dirname "$model_id").$(basename "$model_id")"
    gguf_filename="$(dirname "$model_id").$(basename "$model_id")"
    gguf_filepath="$WORKING_DIR/$gguf_filename.gguf"
    llamafile_path="$WORKING_DIR/$gguf_filename($OUTTYPE).llamafile"

    info "# creating .args file at $ARGS_FILEPATH..." && \
        cat <<EOF > "$ARGS_FILEPATH"
-m
$gguf_filename
...
EOF

    info "# building llamafile with 'llamafile', $gguf_filename, and .args..." && \
        cp "$LLAMAFILE_BIN_DIR/llamafile" "$llamafile_path" && \
        "$LLAMAFILE_BIN_DIR/zipalign" -j0 "$llamafile_path" "$gguf_filepath" "$ARGS_FILEPATH" && \
        chmod +x "$llamafile_path"
}

# build llamafile with `llamafile-server`, .gguf, and .args files
#
# $1: model id of HuggingFace
function build_llamafile_with_llamafile_server {
    model_id="$1"
    model_dir="$HF_MODELS_DIR/$(dirname "$model_id").$(basename "$model_id")"
    gguf_filename="$(basename "$model_id").gguf"
    gguf_filepath="$WORKING_DIR/$gguf_filename"
    llamafile_path="$WORKING_DIR/$(basename "$model_id")($OUTTYPE).llamafile"

    info "# creating .args file at $ARGS_FILEPATH..." && \
        cat <<EOF > "$ARGS_FILEPATH"
-m
$gguf_filename
--host
0.0.0.0
...
EOF

    info "# building llamafile with 'llamafile-server', $gguf_filename, and .args..." && \
        cp "$LLAMAFILE_BIN_DIR/llamafile-server" "$llamafile_path" && \
        "$LLAMAFILE_BIN_DIR/zipalign" -j0 "$llamafile_path" "$gguf_filepath" "$ARGS_FILEPATH" && \
        chmod +x "$llamafile_path"
}

# build llamafile with .gguf and .args files
#
# $1: model id of HuggingFace
function build_llamafile {
    model_id="$1"

    if [ "$BUILD_WITH_WEBSERVER" == "true" ]; then
        build_llamafile_with_llamafile_server "$model_id"
    else
        build_llamafile_with_llamafile "$model_id"
    fi
}

function clean {
    info "# deleting temporary files..." && \
        rm -f "$DOWNLOAD_SCRIPT_FILEPATH" "$ARGS_FILEPATH"
}

# do the real things
#
# $1: model id of HuggingFace
function do_things {
    prep_tools && \
        download_hf_model "$1" && \
        convert_hf_model_to_gguf "$1" && \
        build_llamafile "$1" && \
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

