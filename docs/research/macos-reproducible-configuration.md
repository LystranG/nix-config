# macOS 可复现配置方案调研

> 调研日期：2026-08-21  
> 范围：当前 macOS 主机，以及未来扩展到 Linux/NixOS 与普通 Linux 服务器的结构  
> 约束：本文只给出设计和验证方法，不执行 `darwin-rebuild switch`、`home-manager switch`、`brew bundle install` 或其他全量应用

## 结论摘要

建议把目标定义为“安装 Determinate Nix 和 Homebrew 后，通过一个仓库入口完成系统构建与恢复，再完成极少量首次登录”，而不是裸机零交互。macOS 的 App Store、Bitwarden、部分官网应用和首次 `sudo` 授权都存在无法安全消除的人工边界。

推荐的所有权如下：

| 对象 | 唯一所有者 | 说明 |
| --- | --- | --- |
| Nix 安装、daemon、`nix.conf` | Determinate Nix | nix-darwin 通过 Determinate module 做兼容，不并行管理 Nix |
| macOS defaults、系统服务、Homebrew 清单 | nix-darwin | Homebrew module 只协调已有 Homebrew，不安装 Homebrew |
| 用户级 Nix 配置 | Home Manager | 作为 nix-darwin module 集成；普通 Linux 可 standalone |
| 开发运行时和全局 CLI | mise；配置文件由 chezmoi 管理 | macOS 使用语义版本选择器，不提交全局 `mise.lock`；`mise use -g` 后需 `chezmoi re-add` |
| Bun 本体 | `pkgs.bun` 或 mise 二选一 | Bun 官方 Flake 不是可安装 package Flake |
| npm/pipx CLI | mise | `npm:<package>`、`pipx:<package>`；Bun 可仅作为 npm backend 的安装器 |
| 用户 dotfiles、自定义覆写 | chezmoi | 不与 Nix/Home Manager 同时管理同一目标文件 |
| `~/.tmux` 上游仓库 | chezmoi `git-repo` external | 自定义文件放仓库外的 `~/.tmux.conf.local` |
| Oh My Rime 上游内容 | Git | 恢复时 clone，维护时只允许显式 `pull --ff-only`；chezmoi 只管理 untracked custom 文件 |
| 官网手动安装应用 | 人工清单和厂商更新器 | 不伪装成 Homebrew cask |
| 密钥 | 应用原生 Bitwarden 集成优先 | 不写入 Flake、Nix store、Git 或普通 shell 配置 |

## 1. Determinate Nix、nix-darwin 与 Home Manager

### 1.1 兼容方式

Determinate 官方明确说明：macOS 用户应先通过 Determinate.pkg 安装 Determinate Nix；其 nix-darwin module **不会安装 Nix**，只负责让 nix-darwin 与 Determinate Nix 正确共存，并提供 `customSettings` 和 Determinate Nixd 配置桥接。[Determinate README](https://github.com/DeterminateSystems/determinate#nix-darwin)（访问于 2026-08-21）

当前配置采用以下方向是正确的：

```nix
inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

modules = [
  inputs.determinate.darwinModules.default
  ({ ... }: {
    determinateNix.enable = true;
  })
];
```

`determinateNix.enable = true` 会让 Determinate Nix 成为 Nix 安装、daemon 和标准 `nix.conf` 的唯一所有者。不要再并行配置 nix-darwin 的 `nix.enable = true`、`nix.settings`、`nix.gc` 或 `nix.linux-builder`。nix-darwin 自身也会检测 Determinate Nixd 与内建 Nix 管理冲突并终止激活。[Determinate nix-darwin 指南](https://docs.determinate.systems/guides/nix-darwin/)；[nix-darwin checks 源码](https://github.com/nix-darwin/nix-darwin/blob/master/modules/system/checks.nix)（访问于 2026-08-21）

自定义 Nix 设置应放到 `determinateNix.customSettings`，由 module 写入 `/etc/nix/nix.custom.conf`；Determinate Nixd 的垃圾回收、Linux builder 等配置放入 `determinateNix.determinateNixd`。[Determinate Nixd 文档](https://docs.determinate.systems/determinate-nix/determinate-nixd/)（访问于 2026-08-21）

### 1.2 Home Manager

macOS 上建议把 Home Manager 作为 nix-darwin module 集成，使系统 generation 与用户 generation 同步。未来：

- NixOS 主机使用 Home Manager 的 NixOS module
- 普通 Linux 工作站或服务器使用 standalone Home Manager
- 如果 Home Manager 自己启用 `nix.enable = true`，Determinate 官方要求同时设置 `nix.package = null`，或导入 `determinate.homeManagerModules.default`，避免另一份 Nix 出现在 `PATH`

来源：[Determinate Home Manager 集成](https://github.com/DeterminateSystems/determinate#home-manager)；[Home Manager README](https://github.com/nix-community/home-manager/blob/master/README.md)；[Home Manager nix-darwin 手册](https://github.com/nix-community/home-manager/blob/master/docs/manual/nix-flakes/nix-darwin.md)（访问于 2026-08-21）

### 1.3 密钥与 Determinate Nixd

`authentication.additionalNetrcSources` 不应直接指向 Nix store 中的密钥。Determinate 官方还警告，当前合并后的有效 netrc 可能是全局可读的。认证材料应由应用原生机制或 Nix 激活之外的受限文件提供，不应由 Flake 将 Bitwarden 内容渲染进 store。[Determinate Nixd 文档](https://docs.determinate.systems/determinate-nix/determinate-nixd/)（访问于 2026-08-21）

## 2. 跨 macOS/Linux 的模块分层

推荐结构如下：

```text
flake.nix
flake.lock
lib/
  mk-darwin-host.nix
  mk-nixos-host.nix
  mk-home-host.nix
hosts/
  personal-mac/default.nix
  <linux-host>/default.nix
modules/
  common/
    chezmoi.nix
    repositories.nix
  darwin/
    determinate.nix
    homebrew.nix
    system-defaults.nix
  nixos/
    system.nix
home/
  common/
  darwin/
  linux/
packages/
  homebrew/
    taps.nix
    brews.nix
    casks.nix
docs/
  bootstrap.md
  manual-apps.md
```

这里的关键不是目录名，而是 module option 的边界：

- `flake.nix` 只声明 inputs、host constructors 和各类 configuration outputs
- `hosts/<hostname>` 只组合平台、用户名、角色和 imports
- `modules/darwin` 只能依赖 nix-darwin options
- `home/common` 只能依赖 Home Manager options，不能偷用 Darwin 路径
- `modules/common` 中所谓“通用”配置仍要按 system module 与 home module 分开，不能做成同时依赖两套 option 的大模块
- macOS 的 `~/Library/Rime` 与 Linux 的 Rime 路径由 host/platform 层注入，Rime 的“上游方案加 custom 覆写”语义保持通用

该分层是基于 Nix module 组合能力提出的架构建议，不是上游规定。nix-darwin、NixOS 和 Home Manager 分别提供自己的 configuration 构造器和 module 接口。[nix-darwin README](https://github.com/nix-darwin/nix-darwin)；[Home Manager README](https://github.com/nix-community/home-manager)；[NixOS Flakes 手册](https://nixos.org/manual/nixos/stable/#sec-flakes)（访问于 2026-08-21）

## 3. mise：语义版本与可控更新

### 3.1 已接受策略

`latest`、`lts` 和 `22` 都是动态 selector。`lts` 由具体 backend 的 alias 提供，不是每个工具都具有相同语义；例如 Node 的 `lts` 映射会随 mise/backend 更新。希望保持某个 LTS 代际时，写 `node = "24"` 比 `node = "lts"` 更稳定；希望自动跨 LTS 代际时才使用 `lts`。[mise aliases](https://mise.jdx.dev/dev-tools/aliases.html)；[Node backend 源码](https://github.com/jdx/mise/blob/main/src/plugins/core/node.rs)（访问于 2026-08-21）

本实现接受 ADR 0004：macOS 的 mise 全局配置由 chezmoi 管理，工具安装和 `mise use -g` 的写入由 mise 执行。配置使用语义 selector，保留 `minimum_release_age = "0"`，但不提交全局 `mise.lock`。恢复时先执行 `chezmoi apply`，再由用户显式执行 `mise install`；`mise use -g` 后使用 `chezmoi re-add ~/.config/mise/config.toml` 保存变更：

```toml
[tools]
node = "24"
python = "3.13"
uv = "latest"
"npm:@openai/codex" = "latest"
"pipx:serena-agent" = "latest"

[settings]
minimum_release_age = "0"
```

mise 也提供全局 lock，但本实现不启用或提交 lock。日常先使用 `mise outdated` 审阅，再由用户显式执行 `mise upgrade`；新增或修改全局工具使用 `mise use -g`，确认差异后执行 `chezmoi re-add ~/.config/mise/config.toml`。[mise use](https://mise.jdx.dev/cli/use.html)；[mise upgrade](https://mise.jdx.dev/cli/upgrade.html)；[mise lock 官方文档](https://mise.jdx.dev/dev-tools/mise-lock.html)（访问于 2026-08-21）

### 3.2 npm 与 Python CLI

mise 当前可以直接管理 npm CLI：

```toml
[tools]
"npm:typescript" = "latest"
"npm:@mermaid-js/mermaid-cli" = "latest"
"pipx:black" = "latest"
```

`npm:` backend 默认直接访问 registry 并使用内嵌 aube，在 mise 的独立安装目录中安装每个 CLI；工具运行时若依赖 Node，仍需声明 Node。也可以设置 `settings.npm.package_manager = "bun"`，此时 Bun 只是 mise 选择的底层安装器，声明、版本解析和激活仍归 mise。[mise npm backend](https://mise.jdx.dev/dev-tools/backends/npm.html)；[npm backend 源码](https://github.com/jdx/mise/blob/main/src/backend/npm.rs)（访问于 2026-08-21）

持久 Python CLI 使用 `pipx:<package>`；如果已经有 uv，mise 会使用 `uv tool install`。`uvx` 适合一次性运行，不应作为持久全局工具清单。[mise pipx backend](https://mise.jdx.dev/dev-tools/backends/pipx.html)；[uv tools 文档](https://docs.astral.sh/uv/concepts/tools/)（访问于 2026-08-21）

需要明确限制：mise lock 对 npm、cargo、pipx 当前只锁直接工具版本，不锁完整 asset URL/checksum 和全部传递依赖，不能宣称它实现了完整供应链复现。[mise lock Backend Support](https://mise.jdx.dev/dev-tools/mise-lock.html#backend-support)（访问于 2026-08-21）

### 3.3 不应在 nix-darwin 或 chezmoi activation 中执行 `mise install`

`mise install` 会联网、下载并修改用户目录。把它放进 nix-darwin activation 会使系统激活同时承担滚动工具安装，失败面和漂移都会扩大。更清晰的流程是：

1. nix-darwin 只管理系统配置和 Homebrew，chezmoi 管理 mise 全局配置
2. bootstrap 的显式第二阶段执行 `chezmoi apply`，第三阶段执行 `mise install`
3. 日常更新使用 `mise use -g`、`mise outdated` 和 `mise upgrade`，并将全局配置变更 `chezmoi re-add` 回源仓库

这是根据 mise 命令的写状态行为与 nix-darwin activation 幂等目标得出的设计判断。[mise install](https://mise.jdx.dev/cli/install.html)；[nix-darwin Homebrew activation 对幂等性的说明](https://nix-darwin.github.io/nix-darwin/manual/index.html#opt-homebrew.onActivation.autoUpdate)（访问于 2026-08-21）

## 4. Homebrew 与 nix-darwin

### 4.1 能力

`homebrew.enable = true` 会根据 `taps`、`brews`、`casks`、`masApps` 等生成 Brewfile，并在 system activation 以 `homebrew.user` 执行 `brew bundle`。它**不安装 Homebrew**；若 `brew` 不存在，module 只输出跳过信息，因此新机 bootstrap 必须单独安装 Homebrew，并在验收中检查其是否存在。[nix-darwin Homebrew module 源码](https://github.com/nix-darwin/nix-darwin/blob/master/modules/homebrew.nix)（访问于 2026-08-21）

模块边界：

- `taps` 支持简写和 `clone_target`、`force_auto_update`、`trusted`
- `brews` 支持 formula、安装参数、服务、link、冲突和 postinstall
- `casks` 支持 cask 参数、`greedy` 和 postinstall
- `masApps = { "Name" = APP_ID; }` 依赖 Mac App Store 已登录

这些是 Brewfile 声明，不是版本锁。Homebrew Bundle 已移除 lockfile 支持，Homebrew 仍是滚动发布；即使 activation 使用 `--no-upgrade`，依赖解析也可能引起必要升级。[nix-darwin Homebrew 手册](https://nix-darwin.github.io/nix-darwin/manual/index.html#opt-homebrew.enable)；[Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile)（访问于 2026-08-21）

### 4.2 activation 策略

推荐迁移顺序：

1. 初次盘点使用 `cleanup = "none"`
2. 清单完整后改为 `cleanup = "check"`，让未声明项导致验证失败而非被删除
3. 确认 Homebrew 是唯一所有者后，才考虑 `cleanup = "uninstall"`
4. 不建议常态使用 `zap`，因为 Homebrew 警告它可能删除应用共享文件

保持 `onActivation.autoUpdate = false` 和 `upgrade = false`，把 `brew update/upgrade` 放在显式维护流程中，避免每次 rebuild 隐式滚动升级。[nix-darwin Homebrew module](https://github.com/nix-darwin/nix-darwin/blob/master/modules/homebrew.nix)；[Homebrew manpage](https://docs.brew.sh/Manpage#bundle-subcommand)（访问于 2026-08-21）

### 4.3 cask 与官网应用

是否放进 `casks` 应按生命周期所有者判断，而不是按下载载体是否为 DMG：

- 愿意让 Homebrew 安装和更新的应用：使用已有 cask
- 坚持官网手动安装、由厂商更新器管理的应用：保留在 `manual-apps.md`
- 没有现成 cask 时，不建议仅为“全声明式”维护自定义 tap/cask；这会增加 URL、hash 和卸载规则维护

Homebrew cask 能描述 DMG、安装 artifact 和卸载/zap 规则，但不能管理一个由用户从官网下载并手动安装的 `.app`。[Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)（访问于 2026-08-21）

MAS 安装要求 Apple Account 已登录，并可能触发 Touch ID 或密码；从 `masApps` 删除条目也不会自动卸载应用。这是必须保留的人工边界。[mas 官方 README](https://github.com/mas-cli/mas#app-store-apple-account-requirements)；[nix-darwin `masApps`](https://nix-darwin.github.io/nix-darwin/manual/index.html#opt-homebrew.masApps)（访问于 2026-08-21）

## 5. Bun 本体与 Bun 全局包

Bun 官方仓库确实有 `flake.nix`，但当前只导出 `devShells.default`，并在开发 shell 中反向使用 `pkgs.bun`；它没有 `packages` 或 `defaultPackage` 输出。因此准确结论是“官方仓库有源码开发 Flake”，不是“官方提供可安装 Bun 的 Flake”。[Bun 官方 flake.nix](https://github.com/oven-sh/bun/blob/main/flake.nix)（访问于 2026-08-21）

若选择 Nix 管 Bun 本体，应直接使用当前已锁定 nixpkgs 的 `pkgs.bun`。版本由 `flake.lock` 中 nixpkgs revision 固定，主动更新 lock 时才变化。[Nixpkgs Bun package](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/bu/bun/package.nix)（访问于 2026-08-21）

“Bun 本体”与“`bun add -g` 安装的包”不是一回事。Bun global 默认写入 `~/.bun/install/global/node_modules`，bin 放在 `~/.bun/bin`；普通 global 命令不形成适合审阅的统一声明源。[Bun global install](https://bun.sh/docs/pm/cli/add#global)（访问于 2026-08-21）

推荐次序：

1. Bun runtime 由 `pkgs.bun` 或 mise 二选一
2. npm CLI 继续用 mise `npm:<package>` 声明，必要时让 mise 使用 Bun installer
3. 如果必须锁完整 Bun 依赖图，建立专门的 `bun-tools/package.json + bun.lock`，使用 `bun install --frozen-lockfile`，而不是逐项 `bun add -g`

Bun 官方要求项目提交 `bun.lock`，`--frozen-lockfile` 会在 lock 与 manifest 不一致时失败。[Bun lockfile](https://bun.sh/docs/pm/lockfile)（访问于 2026-08-21）

## 6. chezmoi、tmux 与 Rime 的所有权

### 6.1 chezmoi external 的真实行为

`.chezmoiexternal.*` 的 `git-repo` 类型在目标不存在时 clone、存在时 pull。`refreshPeriod = "0"` 默认不自动刷新；可设置周期并用 `chezmoi -R apply` 强制刷新，也可设置 `pull.args = ["--ff-only"]`。[chezmoi external 格式](https://www.chezmoi.io/reference/special-files/chezmoiexternal-format/)；[Include files from elsewhere](https://www.chezmoi.io/user-guide/include-files-from-elsewhere/)（访问于 2026-08-21）

官方明确指出，`git-repo` 目标目录内容由 Git 管理，chezmoi 不能再管理其中的其他文件，内容也不会进入正常的 `chezmoi diff/dump`。需要“上游目录加本地文件”时应改用 `archive` external。[chezmoi Include files from elsewhere](https://www.chezmoi.io/user-guide/include-files-from-elsewhere/)（访问于 2026-08-21）

`chezmoi update` 是先更新 chezmoi source repo，再 apply，不是“专门更新所有 external 仓库”的命令；强制刷新 external 使用 `-R`。[chezmoi update](https://www.chezmoi.io/reference/commands/update/)（访问于 2026-08-21）

### 6.2 `~/.tmux`

推荐：

- chezmoi `git-repo` external 独占整个 `~/.tmux`
- 不设置 `refreshPeriod`，避免普通 apply 隐式刷新
- `pull.args = ["--ff-only"]`
- chezmoi 在仓库外管理 `~/.tmux.conf` symlink 和 `~/.tmux.conf.local`

Oh My Tmux 官方安装流程就是 clone `~/.tmux`、链接主配置、复制 `.tmux.conf.local`，并明确要求不要修改上游主 `.tmux.conf`，所有自定义放在 `.tmux.conf.local`。因此该边界天然避免双重所有权。[Oh My Tmux README](https://github.com/gpakosz/.tmux/blob/master/README.md)（访问于 2026-08-21）

`--ff-only` 遇到本地修改时失败是保护机制；不应自动 reset、stash 或解决冲突。

### 6.3 `~/Library/Rime`

最终接受的方案保留目标 Rime 目录为 Oh My Rime Git 仓库：Git 管理 tracked 上游文件，chezmoi 只管理 untracked custom 文件。恢复时仅在目录缺失时 clone，维护时显式执行 `pull --ff-only`；普通 nix-darwin activation 与 chezmoi apply 都不刷新上游内容。若上游开始跟踪同名 custom 文件，必须停止并人工重新划分所有权。

Oh My Rime 官方也建议通过 `*.custom.yaml` 覆写，而不是改上游 `default.yaml`、`squirrel.yaml`；其 macOS 配置路径是 `~/Library/Rime`。[Oh My Rime README](https://github.com/Mintimate/oh-my-rime/blob/main/README.md)；[配置覆写](https://www.mintimate.cc/zh/guide/configurationOverride.html)（访问于 2026-08-21）

固定 checksum 与滚动 `latest` 不能同时满足：滚动内容更新后旧 checksum 必然失败。恢复路径应优先固定 revision；显式维护流程才允许刷新并审阅变化。

## 7. Oh My Rime CLI

用户已实测 `~/data/oh-my-rime-cli-darwin-arm64 --help` 会忽略 `--help` 并直接进入 `1/2/3/4/b/d/q` 交互菜单。官方源码也显示：存在任意额外参数时仍进入交互菜单，没有稳定的 `--update` 或 `--check` 非交互契约。[Oh My Rime CLI 源码](https://github.com/Mintimate/oh-my-rime-cli)；[官方使用页](https://www.mintimate.cc/zh/guide/importMint.html)（访问于 2026-08-21）

源码显示菜单功能包括：

- 下载滚动 `latest/oh-my-rime.zip` 并覆盖主方案
- 下载滚动语言模型并覆盖目标模型
- 从 zip 中提取并覆盖 `dicts/`
- 使用用户输入的 zip/gram URL 执行同类覆盖
- 操作前备份整个 Rime 目录并保留有限份备份

下载器会检查 HTTP 状态、非空和 zip 合法性，也有 Zip Slip 路径防护，但没有对滚动 latest 内容做固定 SHA256/签名验证。它不保留 Git revision，不执行 merge，也不更新 `.git`，因此不是 Git 更新的等价替代。[Oh My Rime CLI 源码](https://github.com/Mintimate/oh-my-rime-cli)（访问于 2026-08-21）

结论：

- 不放入 nix-darwin 或 Home Manager activation
- 即使可通过 stdin 选择菜单，也只作为用户显式维护入口
- 运行前检查 chezmoi diff 和备份，运行后重新 apply custom 文件并人工重新部署 Rime
- 主方案更新优先使用 Git 快进；CLI 仅保留为人工诊断或迁移工具

### 7.1 Apple Silicon 固定 release 资产

GitHub 官方 `releases/latest` API 当前返回稳定版 `v3.0.0`，其 `draft = false`、`prerelease = false`，发布于 2026-06-14。`v3.0.0` 是指向提交 `ce0c6350fd4b06bdbce62064b35a1cdea462cb8c` 的 annotated tag。官方 tag 对应的 release workflow 明确以 `GOOS=darwin GOARCH=arm64 CGO_ENABLED=0` 构建 raw CLI，并按 `oh-my-rime-cli-${RELEASE_TAG}-darwin-arm64` 命名；因此 Nix 应取下面的无扩展名 CLI asset，而不是同一 release 中的 macOS arm64 GUI DMG。[最新 release API](https://api.github.com/repos/Mintimate/oh-my-rime-cli/releases/latest)；[v3.0.0 tag](https://github.com/Mintimate/oh-my-rime-cli/releases/tag/v3.0.0)；[v3.0.0 release workflow](https://github.com/Mintimate/oh-my-rime-cli/blob/v3.0.0/.github/workflows/release.yml)（访问于 2026-08-21）

- 固定版本：`3.0.0`（Git tag `v3.0.0`）
- asset：`oh-my-rime-cli-v3.0.0-darwin-arm64`
- 固定 URL：`https://github.com/Mintimate/oh-my-rime-cli/releases/download/v3.0.0/oh-my-rime-cli-v3.0.0-darwin-arm64`
- GitHub API digest：`sha256:7fee2417fd003e0f85d74ca51ab1bfaad1af996fc604df66e1288486b8e2f22b`
- Nix SRI：`sha256-f+4kF/0APg+F10ylGrG/qtGvmW/GBN9m4SiEhrji8is=`
- asset 大小：`5320514` 字节

本次从上述固定 URL 下载到临时目录后，仅对文件字节执行 SHA-256 计算，没有运行二进制；结果为 `7fee2417fd003e0f85d74ca51ab1bfaad1af996fc604df66e1288486b8e2f22b`，文件大小也与 API 一致。该 SRI 可直接用于 Nix：

```nix
fetchurl {
  url = "https://github.com/Mintimate/oh-my-rime-cli/releases/download/v3.0.0/oh-my-rime-cli-v3.0.0-darwin-arm64";
  hash = "sha256-f+4kF/0APg+F10ylGrG/qtGvmW/GBN9m4SiEhrji8is=";
}
```

供应链检查还发现：官方 v3.0.0 darwin-arm64 release asset 的 digest 与本地既有样本 SHA256 `3fe7727fe828b7697166b40aeb52776e85acf79f0d3cff588b0a9e94218e42d0` 不一致。该样本可能是旧版或来自其他发布渠道，不能仅凭文件名确认来源，当前不应自动执行。[v3.0.0 release API](https://api.github.com/repos/Mintimate/oh-my-rime-cli/releases/tags/v3.0.0)（访问于 2026-08-21）

## 8. Bitwarden 与 bootstrap

### 8.1 Password Manager CLI `bw`

`bw login --apikey` 使用个人 `client_id/client_secret`，适合自动化身份认证，但它不替代主密码。读取保险库仍需要 `bw unlock` 生成 `BW_SESSION`，并应在结束后 lock/logout。因此把 API key 放进同一个个人保险库不能解决新机鸡生蛋问题，也不适合在 sudo 的 system activation 中解锁个人保险库。[Bitwarden CLI](https://bitwarden.com/help/cli/)；[CLI auth challenges](https://bitwarden.com/help/cli-auth-challenges/)（访问于 2026-08-21）

### 8.2 Secrets Manager CLI `bws`

`bws` 面向机器账户，通过 access token 访问被授权的 projects/secrets。token 生成后 Bitwarden 不会再次展示，必须通过可信外部渠道安全投递；它把“每次输入主密码”变成“首次投递机器根令牌”，并没有消除根信任。[Secrets Manager overview](https://bitwarden.com/help/secrets-manager-overview/)；[Access tokens](https://bitwarden.com/help/access-tokens/)；[Secrets Manager CLI](https://bitwarden.com/help/secrets-manager-cli/)（访问于 2026-08-21）

个人有人值守 Mac 建议：先安装 Bitwarden/bw，人工登录并解锁，再运行需要 secrets 的显式第二阶段。批量服务器运维才适合按主机或角色发放最小权限、可撤销、可过期的 BWS machine token，并由外部 provisioning 注入。

应用有原生 Bitwarden 集成时优先使用。例如 Bitwarden SSH Agent 可以管理 SSH 登录和 Git 签名，但桌面应用首次登录、解锁、开关启用和授权仍是人工步骤；dotfiles 只负责配置正确的 `SSH_AUTH_SOCK`。[Bitwarden SSH Agent](https://bitwarden.com/help/ssh-agent/)（访问于 2026-08-21）

任何 `client_secret`、`BW_SESSION`、`BWS_ACCESS_TOKEN` 都不应进入 Flake、Nix store、Git 或普通 shell 配置。

## 9. 一键恢复的现实边界

建议把验收定义为以下阶段：

### 阶段 A：一次性人工 bootstrap

1. 创建/确认 macOS 用户，并允许首次 `sudo`
2. 安装 Determinate.pkg
3. 安装 Homebrew
4. clone 本配置仓库
5. 登录 Mac App Store
6. 登录并解锁 Bitwarden，完成必要应用授权
7. 安装明确列在人工清单中的官网应用

Determinate 官方推荐 macOS 使用 pkg；nix-darwin Homebrew module 不安装 Homebrew；MAS 与 Bitwarden 均要求首次认证。因此这些步骤无法由一条纯 Nix 命令安全消除。[Determinate README](https://github.com/DeterminateSystems/determinate#installing-using-the-determinate-nix-installer)；[nix-darwin Homebrew 源码](https://github.com/nix-darwin/nix-darwin/blob/master/modules/homebrew.nix)；[mas README](https://github.com/mas-cli/mas#app-store-apple-account-requirements)（访问于 2026-08-21）

### 阶段 B：声明式构建与人工确认后激活

配置仓库应提供一个 bootstrap 入口，但内部按顺序分阶段并在每一步失败时停止：

1. 检查前置和 host identity
2. 静态评估并 build Darwin system
3. 展示 diff/计划并等待用户确认
4. 用户手动执行第一次 `darwin-rebuild switch`
5. 显式运行 `chezmoi init/apply`
6. 显式运行 `mise install`
7. 检查 Homebrew、mise、externals 和关键 dotfiles

当前会话只允许做到第 2 步，不能执行第 4 至第 6 步。

## 10. 不激活的验证命令

以下命令可用于实现后的验收，不会执行 system switch：

```bash
# 评估 Flake；不会自动覆盖未挂到 checks 的所有 host
nix flake check --no-update-lock-file --show-trace

# 显式构建当前 Darwin host
nix build \
  .#darwinConfigurations.personal-mac.system \
  --no-update-lock-file \
  --show-trace

# 若存在 standalone Home Manager host
nix build \
  .#homeConfigurations.personal-user-at-personal-mac.activationPackage \
  --no-update-lock-file \
  --show-trace

# 未来 NixOS host
nix build \
  .#nixosConfigurations.<linux-host>.config.system.build.toplevel \
  --no-update-lock-file \
  --show-trace

# 只检查 mise selector 对应的更新
mise outdated

# 只核对实际输出路径，不切换
nix eval --raw \
  .#darwinConfigurations.personal-mac.system.drvPath
```

`nix flake check` 只构建 Flake 暴露的 checks，不自动保证每个 `darwinConfigurations` 或 `homeConfigurations` 都被构建；应显式 build 各 host，或把它们映射到 `checks`。[nix-darwin flake](https://github.com/nix-darwin/nix-darwin/blob/master/flake.nix)；[Nix `flake check`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake-check)（访问于 2026-08-21）

不建议把 `darwin-rebuild check` 当作纯静态检查：其脚本会以 `checkActivation=1` 运行生成系统的 activation script。当前阶段优先直接 `nix build`。[darwin-rebuild 源码](https://github.com/nix-darwin/nix-darwin/blob/master/pkgs/nix-tools/darwin-rebuild.sh)（访问于 2026-08-21）

## 11. 对当前配置的直接设计判断

基于当前仓库文件，后续实现应处理以下事项：

1. 保留 Determinate module 与 `determinateNix.enable = true`
2. 将 Home Manager 配置拆到独立 module，由主机配置注入用户
3. 将 Homebrew taps/brews/casks 拆成 macOS 专用清单文件
4. nix-darwin 只管理系统配置和 Homebrew；chezmoi 管理 mise 全局配置，移除 Home Manager 的 mise 配置
5. macOS 使用 chezmoi 保存的 mise 配置与语义 selector，保留 `minimum_release_age = "0"`，但不提交全局 `mise.lock`
6. 不新增 Bun 官方 Flake input；若 Nix 管 Bun，使用当前 nixpkgs 的 `pkgs.bun`
7. tmux 保留无自动刷新周期的 `git-repo` external；Rime 作为独立 Git 仓库按路径划分所有权
8. Rime CLI 仅作为显式人工维护工具，不进入 activation
9. Homebrew 清单核对完整后使用 `cleanup = "check"`
10. 新增 bootstrap 和人工应用清单，诚实记录 Determinate.pkg、Homebrew、MAS、Bitwarden 与官网应用的首次人工步骤

这些判断只形成实现输入，不代表本轮已修改或应用配置。
