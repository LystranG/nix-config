# 系统配置与 dotfiles 使用独立仓库

系统配置仓库独立管理 Nix、nix-darwin、Home Manager 和软件清单，chezmoi 仓库不再包含 `.flake`。两类配置的生命周期、适用主机和恢复顺序不同，拆分后可以独立演进，也避免嵌套仓库和双重提交来源。
