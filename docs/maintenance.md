# macOS 维护

各类更新相互独立，执行前先检查工作区并审阅变化

## Flake

使用 `nix flake update` 更新 inputs，然后重新执行 Flake check、Darwin system 构建和 Rime CLI package 构建

## Homebrew

显式执行 Homebrew 的 update 和 upgrade，核对实际 leaves/casks 后再更新声明清单；普通系统激活不会自动 update 或 upgrade

## mise

先审阅 `mise outdated`，再由用户显式执行 `mise upgrade` 或 `mise install`；Home Manager 只生成全局配置

## Rime

```bash
git -C ~/Library/Rime status --short
git -C ~/Library/Rime pull --ff-only origin main
```

若远端名不是 `origin`，先核对其 URL，再对正确的远端执行快进更新。Oh My Rime CLI 仅供人工维护，不在 activation 中运行

## tmux

```bash
git -C ~/.tmux status --short
git -C ~/.tmux pull --ff-only origin master
```

本地修改或分叉会让 `--ff-only` 失败，此时人工处理，不自动 reset 或 stash
