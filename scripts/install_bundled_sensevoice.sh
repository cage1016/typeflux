#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <target-model-folder>" >&2
  exit 1
fi

TARGET_MODEL_FOLDER="$1"
RUNTIME_VERSION="v1.12.35"
RUNTIME_ROOT="sherpa-onnx-${RUNTIME_VERSION}-osx-universal2-shared-no-tts"
MODEL_ROOT="sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17"
RUNTIME_ARCHIVE_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/${RUNTIME_VERSION}/sherpa-onnx-${RUNTIME_VERSION}-osx-universal2-shared-no-tts.tar.bz2"
MODEL_URL="https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx"
TOKENS_URL="https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/tokens.txt"
VERSIONED_LIB="libonnxruntime.1.23.2.dylib"

MAX_RETRIES=3
RETRY_DELAY_SECONDS=5

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/typeflux-sensevoice.XXXXXX")"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

download_file() {
  local source_url="$1"
  local destination_path="$2"
  local attempt=1

  while true; do
    if curl --fail --location --silent --show-error "$source_url" --output "$destination_path"; then
      return 0
    fi

    if [[ $attempt -ge $MAX_RETRIES ]]; then
      echo "Error: failed to download ${source_url} after ${MAX_RETRIES} attempts" >&2
      return 1
    fi

    echo "Warning: download attempt ${attempt}/${MAX_RETRIES} failed for ${source_url}, retrying in ${RETRY_DELAY_SECONDS}s..." >&2
    sleep "$RETRY_DELAY_SECONDS"
    attempt=$((attempt + 1))
  done
}

prune_runtime_payload() {
  local runtime_root="$1"
  local bin_dir="${runtime_root}/bin"
  local include_dir="${runtime_root}/include"
  local lib_dir="${runtime_root}/lib"
  local versioned_lib="${lib_dir}/${VERSIONED_LIB}"
  local compatibility_lib="${lib_dir}/libonnxruntime.dylib"

  if [[ -d "$bin_dir" ]]; then
    find "$bin_dir" -mindepth 1 -maxdepth 1 ! -name "sherpa-onnx-offline" -exec rm -rf {} +
  fi

  rm -rf "$include_dir"

  if [[ -d "$lib_dir" ]]; then
    if [[ ! -e "$versioned_lib" && -e "$compatibility_lib" ]]; then
      cp "$compatibility_lib" "$versioned_lib"
    fi

    rm -f "$compatibility_lib"

    if [[ -e "$versioned_lib" ]]; then
      ln -sf "${VERSIONED_LIB}" "$compatibility_lib"
    fi

    find "$lib_dir" -mindepth 1 -maxdepth 1 \
      ! -name "libsherpa-onnx-c-api.dylib" \
      ! -name "libonnxruntime.dylib" \
      ! -name "${VERSIONED_LIB}" \
      -exec rm -rf {} +
  fi

  find "$runtime_root" -depth -type d -empty -delete
}

echo "Bundling SenseVoice into ${TARGET_MODEL_FOLDER}..."
echo "Runtime version: ${RUNTIME_VERSION}"
echo "Expected runtime directory: ${RUNTIME_ROOT}"
echo "Max download retries: ${MAX_RETRIES}"

rm -rf "$TARGET_MODEL_FOLDER"
mkdir -p "$TARGET_MODEL_FOLDER"

CACHE_DIR="${HOME}/.cache/typeflux-bundled-models"
mkdir -p "$CACHE_DIR"

RUNTIME_ARCHIVE_PATH="${CACHE_DIR}/${RUNTIME_ROOT}.tar.bz2"
if [[ ! -f "$RUNTIME_ARCHIVE_PATH" ]]; then
  download_file "$RUNTIME_ARCHIVE_URL" "$RUNTIME_ARCHIVE_PATH"
fi

tar -xjf "$RUNTIME_ARCHIVE_PATH" -C "$TARGET_MODEL_FOLDER"
prune_runtime_payload "${TARGET_MODEL_FOLDER}/${RUNTIME_ROOT}"

mkdir -p "${TARGET_MODEL_FOLDER}/${MODEL_ROOT}"

cached_model_file="${CACHE_DIR}/$(basename "$MODEL_URL")"
if [[ ! -f "$cached_model_file" ]]; then
  download_file "$MODEL_URL" "$cached_model_file"
fi
cp "$cached_model_file" "${TARGET_MODEL_FOLDER}/${MODEL_ROOT}/model.int8.onnx"

cached_tokens_file="${CACHE_DIR}/$(basename "$TOKENS_URL")"
if [[ ! -f "$cached_tokens_file" ]]; then
  download_file "$TOKENS_URL" "$cached_tokens_file"
fi
cp "$cached_tokens_file" "${TARGET_MODEL_FOLDER}/${MODEL_ROOT}/tokens.txt"

test -x "${TARGET_MODEL_FOLDER}/${RUNTIME_ROOT}/bin/sherpa-onnx-offline" || {
  echo "Error: sherpa-onnx-offline executable not found or not executable" >&2
  exit 1
}
test -f "${TARGET_MODEL_FOLDER}/${RUNTIME_ROOT}/lib/libsherpa-onnx-c-api.dylib" || {
  echo "Error: libsherpa-onnx-c-api.dylib not found" >&2
  exit 1
}
test -e "${TARGET_MODEL_FOLDER}/${RUNTIME_ROOT}/lib/libonnxruntime.dylib" || {
  echo "Error: libonnxruntime.dylib not found" >&2
  exit 1
}
test -f "${TARGET_MODEL_FOLDER}/${MODEL_ROOT}/model.int8.onnx" || {
  echo "Error: model.int8.onnx not found" >&2
  exit 1
}
test -f "${TARGET_MODEL_FOLDER}/${MODEL_ROOT}/tokens.txt" || {
  echo "Error: tokens.txt not found" >&2
  exit 1
}

echo "Bundled SenseVoice is ready at ${TARGET_MODEL_FOLDER}"
