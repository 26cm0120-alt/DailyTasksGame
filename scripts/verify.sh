#!/bin/sh
set -eu

# 呼び出し元の作業フォルダに依存せず、パッケージの場所を決める。
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$script_dir/.." && pwd)

# テストの終了コードを、そのまま呼び出し元へ返す。
exec swift test --package-path "$repository_root/Packages/AppCore"
