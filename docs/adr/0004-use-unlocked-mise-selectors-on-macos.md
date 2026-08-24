# macOS 的 mise 全局配置由 chezmoi 管理且不提交锁文件

macOS 的 mise 可执行文件由 Homebrew 提供，全局配置文件 `~/.config/mise/config.toml` 由 chezmoi 管理，工具安装和 `mise use -g` 的修改由 mise 自己执行。配置使用 `latest`、代际版本等语义选择器，保留 `minimum_release_age = "0"`，但不提交全局 `mise.lock`。执行 `mise use -g` 后，应使用 `chezmoi re-add ~/.config/mise/config.toml` 将变更写回 dotfiles 仓库；恢复时先执行 `chezmoi apply`，再由用户显式执行 `mise install`。
