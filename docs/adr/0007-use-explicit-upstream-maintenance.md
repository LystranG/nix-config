# 上游仓库只通过维护命令更新

Rime 和 tmux 的上游内容不在 nix-darwin activation 或普通 chezmoi apply 中自动刷新。新机恢复只负责 clone 缺失仓库，日常拉取通过维护文档中的显式快进命令执行，从而让恢复与滚动更新保持分离。
