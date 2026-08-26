#!/usr/bin/env bash

set -euo pipefail

# 定位 Flake 根目录，允许从任意工作目录运行脚本
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "${script_dir}/.." && pwd)
flake_ref="${repo_root}#personal-mac"

cd "${repo_root}"

update_repository() {
  local name="$1"
  local path="$2"
  local remote_url="$3"
  local branch="$4"
  local answer

  printf '\n是否更新 %s（%s）？[y/N] ' "${name}" "${path}"
  read -r answer
  case "${answer}" in
    y|Y|yes|YES)
      ;;
    *)
      printf '已跳过 %s\n' "${name}"
      return 0
      ;;
  esac

  if [[ ! -e "${path}" ]]; then
    printf '目录不存在，正在 clone %s...\n' "${name}"
    mkdir -p "$(dirname -- "${path}")"
    git clone --branch "${branch}" "${remote_url}" "${path}"
    printf '%s clone 完成\n' "${name}"
    return 0
  fi

  if [[ ! -d "${path}/.git" ]]; then
    printf '跳过 %s：目标路径存在，但不是 Git 仓库：%s\n' "${name}" "${path}" >&2
    return 0
  fi

  if ! git -C "${path}" remote get-url origin >/dev/null 2>&1; then
    printf '跳过 %s：仓库没有 origin，请先人工配置远程地址：%s\n' "${name}" "${path}" >&2
    return 0
  fi

  if [[ -n "$(git -C "${path}" status --short)" ]]; then
    printf '跳过 %s：仓库有未提交或未跟踪的本地修改\n' "${name}" >&2
    return 0
  fi

  printf '正在快进更新 %s...\n' "${name}"
  if git -C "${path}" pull --ff-only origin "${branch}"; then
    printf '%s 更新完成\n' "${name}"
  else
    printf '更新 %s 失败：未修改本地仓库，请人工检查\n' "${name}" >&2
  fi
}

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

printf '\n系统配置同步完成，现在处理可选的上游仓库更新。\n'
update_repository \
  'Rime' \
  "${HOME}/Library/Rime" \
  'https://github.com/Mintimate/oh-my-rime.git' \
  'main'
update_repository \
  'tmux' \
  "${HOME}/.tmux" \
  'https://github.com/gpakosz/.tmux.git' \
  'master'

cat <<'EOF'

系统配置已应用

以下操作仍需人工执行：
  - chezmoi apply
  - mise install / mise upgrade
EOF
