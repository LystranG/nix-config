# macOS 的 mise 配置跟随当前全局配置且不提交锁文件

macOS 开发工具清单以当前全局 mise 配置为基准，并显式保留 `pnpm`、`prettier` 与 `npm:@oh-my-pi/pi-coding-agent` 三项工具。清单使用 `latest`、代际版本等语义选择器，并保留 `minimum_release_age = "0"`，但不提交全局 `mise.lock`。恢复时接受选择器随时间解析到新版本，以换取稳定且很少修改的工具清单；将来其他机器可以独立选择是否使用锁文件。
