# 上游配置仓库不建立空的 Nix 模块

Rime 与 tmux 的 clone、pull 和 custom 文件不由 Nix activation 执行，因此不创建只为目录归类而存在的 `repositories.nix`。仓库地址和显式操作写入恢复与维护文档，实际 custom 文件及 tmux external 继续由 chezmoi 管理。
