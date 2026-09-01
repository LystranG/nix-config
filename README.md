# macOS Flake

这是当前 macOS 主机的 nix-darwin 配置。逻辑主机名是 `personal-mac`，不等同于 macOS 的真实主机名。

## 一键应用

在仓库根目录执行：

```bash
./scripts/apply-darwin.sh
```

脚本等价于：

```bash
sudo -H darwin-rebuild switch \
  --flake '/Users/lystran/.flake#personal-mac'
```

你可能见过的 `sudo darwin switch --flake '.#personal-mac'` 不是 nix-darwin 的有效命令，正确命令是 `darwin-rebuild switch`。脚本使用绝对路径，避免 zsh 对 `#` 做通配展开。

首次安装 nix-darwin、系统中还没有 `darwin-rebuild` 时，脚本会自动回退到：

```bash
sudo -H nix run nix-darwin -- switch \
  --flake '/Users/lystran/.flake#personal-mac'
```

脚本先应用 Nix/nix-darwin 系统配置；同步成功后，会分别询问是否更新 Rime 和 tmux
上游仓库。输入 `y` 才会执行操作，其他输入都会跳过。脚本不会自动执行
`chezmoi apply`、`mise install` 或 `mise upgrade`。

## 常用校验

修改配置后，先格式化并验证：

```bash
nix fmt
nix flake check --no-update-lock-file --show-trace
nix build .#darwinConfigurations.personal-mac.system \
  --no-update-lock-file --show-trace --no-link
git diff --check
```

校验通过后执行：

```bash
./scripts/apply-darwin.sh
```

应用成功后，重新打开终端即可。通常不需要重启电脑。

## 按配置类型修改

### macOS 系统设置

编辑：

```text
modules/darwin/system-defaults.nix
```

然后运行校验和一键脚本。Dock、Finder、键盘和系统默认值会在 system activation 中应用。

### Homebrew

编辑：

```text
packages/homebrew/default.nix
modules/homebrew.nix
```

当前 activation 设置：

```nix
autoUpdate = false;
upgrade = false;
cleanup = "check";
```

因此系统切换不会主动升级 Homebrew，也不会自动卸载软件。`cleanup = "check"` 会检查本机是否有未声明的软件；如果有，activation 会中止，需要把软件加回清单或人工卸载。

如果使用 AppCleaner 先删除了 Homebrew cask，可能只删除了应用而留下 Homebrew receipt。此时可针对单个 cask 清理：

```bash
HOMEBREW_NO_AUTO_UPDATE=1 brew uninstall --cask --force <cask>
```

### mise

mise 可执行文件由 Homebrew 提供，全局配置由 chezmoi 管理。现在可以直接使用：

```bash
mise use -g node@latest
mise use -g npm:typescript@latest
```

`mise use -g` 会安装工具并修改 `~/.config/mise/config.toml`。想把修改保存到 chezmoi source：

```bash
chezmoi diff -- ~/.config/mise/config.toml
chezmoi re-add ~/.config/mise/config.toml
```

新电脑恢复 mise 配置：

```bash
chezmoi apply ~/.config/mise/config.toml
mise install
```

修改 mise 全局工具不需要重新运行 `darwin-rebuild`。

### chezmoi dotfiles

应用前先查看差异：

```bash
chezmoi diff
```

确认后再应用：

```bash
chezmoi apply
```

这一步与 nix-darwin 独立，可能会渲染 Bitwarden 内容。不要用 `sudo` 执行 chezmoi。

### Rime 与 tmux

这两个目录是独立的上游 Git 仓库。运行 `./scripts/apply-darwin.sh` 并在提示时输入 `y`
后，脚本会执行以下操作：

- 目录不存在时 clone 对应仓库
- 目录存在且是干净的 Git 仓库时执行 `git pull --ff-only`
- 目录有本地修改、不是 Git 仓库或没有 `origin` 时跳过并提示

脚本不会自动 reset、stash、覆盖本地修改或解决 Git 冲突。

Rime 更新提示之后，脚本还会询问是否更新万象模型。确认后会从
`https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram`
下载并更新 `~/Library/Rime/wanxiang-lts-zh-hans.gram`。下载完成后才会替换旧文件；
Rime 目录不存在或下载失败时不会修改已有模型。

```bash
git -C ~/Library/Rime status --short
git -C ~/.tmux status --short

git -C ~/Library/Rime pull --ff-only origin main
git -C ~/.tmux pull --ff-only origin master
```

也可以手动执行上述命令。已有本地修改时不要自动 reset、stash 或覆盖。

## Git 工作流

查看本次变更：

```bash
git status --short --branch
git diff
```

提交 Flake：

```bash
git add <本次修改的文件>
git commit -m "描述配置变更"
git push
```

chezmoi 是独立 Git 仓库，使用：

```bash
cd "$(chezmoi source-path)"
git status --short --branch
git add <本次修改的文件>
git commit -m "描述 dotfiles 变更"
git push
```

不要把 `/nix/store`、`/run/current-system`、`/etc/nix` 或任何密钥复制进仓库。

## 应用边界

- `darwin-rebuild switch`：应用系统设置、Homebrew 清单、系统级 Nix 配置
- `chezmoi apply`：应用用户 dotfiles 和 mise 配置
- `mise use -g` / `mise install`：修改或安装用户级开发工具
- `apply-darwin.sh` 中的交互式 Rime/tmux `git pull --ff-only`：可选的上游仓库维护
- Mac App Store、Bitwarden、官网安装的软件：人工登录和更新
