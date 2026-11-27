# 贡献与反馈

先运行只读状态检查。型号、Windows build、Realtek/E-APO 版本、耳机型号、ProfileMatched 与 Issues、重启及 A/B 体验有助于判断。没有匹配的设备不要通过修改 OEM 值或放宽检查来“适配”。

公开前手工删除用户名、本机绝对路径、SID、endpoint 实例 GUID、机器名。不要提交 runtime、完整备份、registry 导出、音频录音或私有游戏录像。公共 APO CLSID 和脱敏的 value 类型/参数可保留。

新增 profile 需要明确结构证据、匹配失败测试、逐值回滚测试与独立设备反馈。生产代码不得新增 CreateSubKey、ACL/Owner 修改、SYSTEM/TrustedInstaller、驱动/服务变更或未知 CLSID 写入。

测试：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1`。测试所有生产 registry 事务都必须使用内存替身，不在 CI 或贡献者电脑上操作真实音频配置。不要上传测试生成的 runtime 数据。

贡献代码和文档须按本仓库 GPL-3.0-only 许可提供，并记录上游来源。
