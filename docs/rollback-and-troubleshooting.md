# 回滚与排错

## 关闭与撤销的区别

`Set-LeqState -State Off` 只写 enable 的 OFF 字节，保留 child/release。`Restore-MicrosoftLeq` 使用这次安装保存的原状态，恢复 PreMixChild 原空字符串并删除两项原本不存在的参数。

恢复前先不加 `-Apply` 查看计划。恢复期间若某个值变成未知第三值或类型，整个三值预检会在写入前停止；不会用整树导入把问题盖过去。实际写入间若发生并发变化，也会停止；跨两个 registry key 不具有系统事务原子性。

## 备份与开关日志

`backup.json` / `backup.sha256` 记录原状态和固定三值白名单；`ownership.json` 跟踪当前由本工具写入的 ON/OFF 状态。开关不会覆盖原值备份。中途退出时 Pending 记录允许有边界地恢复，而新的 Toggle 会停止。

备份是私有的本机文件，SHA256 用于发现意外损坏，不是防篡改签名。只用自己的可信备份，不下载他人的备份恢复。本地可修改脚本/备份的管理员仍是信任边界。

## 已有旧版配置

若已经使用原固定设备脚本或其它工具启用 LEQ，新的 Enable 会识别已有配置并停止。第一版不猜测你的原状态，也不接管旧备份。继续使用原配套回滚与开关；如需迁移，先独立核实旧备份、明确恢复，再重新规划。不要为了“Fresh”状态盲目删键。

本仓库的 Restore 仅接受本仓库 schema/profile 的备份，不接受早期试验备份或完整 MMDevices 导出。

## 常见停止原因

| 信息 | 处理 |
|---|---|
| E-APO F,5/F,7 缺失 | 回到 E-APO 官方设备配置检查；本工具不修复链 |
| OEM 列表或顺序不同 | 提交脱敏的兼容性报告；不要覆盖 OEM |
| Access denied | 停止；不 takeown、WRITE_DAC、SYSTEM、FullControl 或改 ACL |
| context/其它 LEQ 参数已存在 | 该配置不在此 profile 支持范围 |
| 不是 stereo mask 3 | 不写 ,1599 等其它 mask，另行研究适配 |
| DLL 签名校验失败 | 停止，检查系统组件状态；不自行注册替代 DLL |
| 非 E-APO 1.4.2 | 该版本尚未进入本项目验证范围，不自动降级或升级 |
| backup hash 不匹配 | 保留原文件排查，不重算 hash 来绕过检查 |
| Unknown third state | 不覆盖；先只读比较原值、试验值与现值 |
| pending switch | 停止新开关，预览 guarded Restore；不要编辑 ownership |

## 快捷方式卸载

删除本项目创建的两个 `.lnk` 即可。不会卸载 E-APO、改变 LEQ 开关或恢复音频注册表。没有计划任务需要删除；旧版 LEQToggle 的任务由它自己的卸载器管理，本项目不触碰。
