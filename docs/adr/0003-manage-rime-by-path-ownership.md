# Rime 使用路径级所有权

保留 `~/Library/Rime` 为 Oh My Rime Git 仓库：Git 只管理上游 tracked 文件，chezmoi 只管理明确列出的 untracked custom 文件，上游更新仅允许 `pull --ff-only`。若上游开始跟踪任一同名 custom 文件，维护命令必须失败并要求人工重新划分所有权，不能自动覆盖或合并。
