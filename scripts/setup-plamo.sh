#!/usr/bin/env bash
#
# PLaMo 3 Translate（端末内の和訳）を動かす llama.cpp を、iOS 実機・シミュレータ向けの xcframework としてビルドし、
# Packages/LlamaFramework/llama.xcframework に置く（大きいので Git には入れない）。
# 和訳モデル本体はアプリが Hugging Face からダウンロードする（PlamoModelStore）。
#
# 公式リリースの xcframework にはシミュレータ用が含まれないため、ソースからビルドする。
# cmake が無ければ一時的な Python 仮想環境に入れて使う。
#
# usage: scripts/setup-plamo.sh            # 無ければ用意する
#        scripts/setup-plamo.sh --force    # 作り直す
set -euo pipefail

LLAMA_CPP_TAG=b11757

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCFRAMEWORK_PATH="${ROOT}/Packages/LlamaFramework/llama.xcframework"
FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

if $FORCE || [[ ! -d "$XCFRAMEWORK_PATH" ]]; then
    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"' EXIT
    echo "==> llama.cpp ${LLAMA_CPP_TAG} を iOS 実機・シミュレータ向けにビルドします（数分かかります）"
    git clone -q --depth 1 --branch "$LLAMA_CPP_TAG" https://github.com/ggml-org/llama.cpp.git "${WORK}/llama.cpp"
    if ! command -v cmake >/dev/null; then
        python3 -m venv "${WORK}/venv"
        "${WORK}/venv/bin/pip" -q install cmake
        export PATH="${WORK}/venv/bin:${PATH}"
    fi
    (cd "${WORK}/llama.cpp" && ./build-xcframework.sh ios-device ios-sim)
    rm -rf "$XCFRAMEWORK_PATH"
    cp -R "${WORK}/llama.cpp/build-apple/llama.xcframework" "$XCFRAMEWORK_PATH"
else
    echo "==> llama.xcframework は用意済みです"
fi

echo "==> 完了しました"
