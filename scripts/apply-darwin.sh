#!/usr/bin/env bash

set -euo pipefail

# 定位 Flake 根目录，允许从任意工作目录运行脚本
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "${script_dir}/.." && pwd)
flake_ref="${repo_root}#personal-mac"

cd "${repo_root}"

if ! command -v nix >/dev/null 2>&1; then
  printf '%s\n' '错误：未找到 nix，请先安装 Determinate Nix' >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  printf '%s\n' '错误：未找到 brew，请先安装 Homebrew' >&2
  exit 1
fi

printf '应用 Flake：%s\n' "${flake_ref}"

if command -v darwin-rebuild >/dev/null 2>&1; then
  sudo -H darwin-rebuild switch --flake "${flake_ref}"
else
  printf '%s\n' '未找到 darwin-rebuild，使用 nix-darwin 首次安装入口' >&2
  sudo -H nix run nix-darwin -- switch --flake "${flake_ref}"
fi

cat <<'EOF'

系统配置已应用

未自动执行以下操作：
  - chezmoi apply
  - mise install / mise upgrade
  - Rime 或 tmux 远程仓库更新
EOF
