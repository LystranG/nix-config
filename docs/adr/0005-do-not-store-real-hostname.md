# 系统配置不保存真实主机名

Flake 输出和主机目录使用 `personal-mac` 这一非识别性的逻辑配置名，不声明或修改 macOS 的真实 HostName、LocalHostName 与 ComputerName。这样仓库仍可选择设备配置，但提交历史不会包含真实设备名称。
