# 系统配置仓库只提交可恢复配置

系统配置仓库只提交 Flake、Nix 模块、软件清单、必要脚本与操作文档；`.agents`、`.serena`、`skills-lock.json`、Nix 构建结果和其他代理本地状态全部忽略。chezmoi 的改动在其独立仓库单独提交，两个仓库都不自动推送。
