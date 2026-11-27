# 从增强页到 Microsoft child 的研究记录

以下是本案例的实际路径，失败实验仅作说明，不提供批量复现危险写入的入口。

| 阶段 | 观察 | 结论 |
|---|---|---|
| Disable_SysFx 1→0 | 重启保持，耳机有声，仍无 Enhancements | 开启 SysFx 本身不够 |
| 加入 Microsoft SysFxUI F,3 | 出现 Enhancements 标签，但列表为空 | UI 出现不等于 DSP 有效 |
| F,13 追加 Microsoft SFX | 重启有声，列表仍空 | 已精确回滚，不纳入发布工具 |
| CAPX context 探索 | 管理员创建/权限检查受阻 | 停止权限扩张；没有作为成功方案 |
| 审计 LEQControlPanel v1.0.1 | 当时安装路径会清理当前 OEM Composite，写入失败备用路径会尝试扩大权限；卸载不保留本机完整原状态 | 不对本机部署该原版安装/repair 路径；这是版本与设备限定判断 |
| E-APO child 三值方案 | 原固定 GUID 实验日志记录三值 readback 成功、其它值/SDDL 无变化，随后有 ON/OFF 日志 | 形成最小实验基础 |
| 使用者反馈 | Microsoft LEQ 实际有效，最终未搭配 EQ | 本仓库围绕这条实际使用路径整理 |

原一键开关 v2 使用最小 QueryValues|SetValue 权限。它的快捷方式通过提升计划任务调用，并默认刷新 Audiosrv。本仓库改为用户显式 UAC 的可选快捷方式，既不创建该计划任务，也不自动重启服务。

原正式整机音频基线和早期实验日志仍由使用者本地保管。本仓库没有复制那些备份、SID 或设备实例 GUID；也不使用它们作为其它电脑的恢复模板。
