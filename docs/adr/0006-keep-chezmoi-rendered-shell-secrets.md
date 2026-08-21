# 保留 chezmoi 渲染的 shell 密钥

继续允许 chezmoi 从 Bitwarden 读取密钥并将部分值渲染进 `.zprofile` 等本机文件，不为减少明文驻留而引入运行时密钥加载层。该选择接受 shell 子进程继承环境变量的暴露面，以保持现有使用方式简单；Flake、Nix store 和系统配置 Git 仓库仍不得包含任何密钥值。
