# macOS 恢复

恢复只让新设备达到仓库声明的状态，不主动刷新滚动版本或上游仓库

## 人工前置

1. 创建 macOS 用户并确认可以使用 `sudo`
2. 从 Determinate Systems 官网安装 Determinate Nix
3. 按 Homebrew 官网步骤安装 Homebrew
4. 登录 Mac App Store 和 Bitwarden，并完成需要的应用授权
5. 从 Visual Studio Code 官网安装 VS Code，由厂商更新器维护
6. clone 系统配置仓库和 chezmoi dotfiles 仓库

## 声明式配置

先构建并审阅逻辑配置，不把逻辑配置名当作真实设备名：

```bash
nix flake check --no-update-lock-file --show-trace
nix build .#darwinConfigurations.personal-mac.system --no-update-lock-file --show-trace
```

确认构建结果后，由用户单独决定何时执行首次系统切换、`chezmoi apply` 和 `mise install`。先应用系统配置，再应用 chezmoi，使 mise 全局配置落盘，最后由 mise 安装工具

## 上游配置仓库

仅在目标目录不存在时 clone：

```bash
git clone https://github.com/Mintimate/oh-my-rime.git ~/Library/Rime
git clone https://github.com/gpakosz/.tmux.git ~/.tmux
```

若目标目录已经存在但不是预期仓库，先人工备份和核对，不覆盖现有内容
