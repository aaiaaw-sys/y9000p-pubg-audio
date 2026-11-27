# 兼容性与实测记录

| 项目 | 原始已验证案例 |
|---|---|
| 笔记本 | Lenovo Legion Y9000P IAX10 |
| 系统 | Windows 11，具体 build 未记录，不能推断覆盖所有 build |
| 驱动 | Realtek 6.0.9882.1；原 Intel SST/OEM 架构保留 |
| OEM 效果 | Nahimic、Realtek APO、Elevoc DAPO / CompositeFX |
| 耳机 | 3.5mm Apple EarPods，Realtek Render endpoint |
| E-APO | 1.4.2，PRE F,5 / POST F,7 |
| Microsoft child | WM LFX `{62dc1a93-ae24-464c-a43e-452f824c4250}` |
| 参数 | stereo PID 3，release code 4 |
| 结果 | 三值写入/读回与开关记录；使用者确认 LEQ 有效，未搭配 EQ |

首个仓库版本于 2026-11-27 整理。原案例的固定 GUID 脚本、旧版快捷方式包与本仓库通用工具不是同一个版本；不能把前者的实机结果等同于后者已完成全流程实机验证。

当前没有其它机器的验证记录。型号相同但 OEM GUID、模式、E-APO 版本或音频格式不同，会被检查拒绝。不同型号即使结构匹配，也只能算新的待实测样本；工具没有用 SMBIOS 型号作兼容性承诺。

## 当前配置签名

F,n 表示 FxProperties 中 `{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},n`。以下是**只读匹配规则**，不要复制它们去覆盖其它设备：

| 属性 | 期望 CLSID 或有序列表 |
|---|---|
| F,5 | `{EACD2258-FCAC-4FF4-B36D-419E924A6D79}`，E-APO PRE |
| F,7 | `{EC1CC9CE-FAED-4822-828A-82A81A6F018F}`，E-APO POST |
| F,13 | `{670173E3-78CF-11E5-A837-0800200C9A66}` |
| F,14 | `{670173E4-78CF-11E5-A837-0800200C9A66}` → `{A296D363-EE83-4AF9-9BE7-729C1296150A}` → `{001897D5-ADD1-4C31-90FD-34B06B8E7EE4}` → `{670173E5-78CF-11E5-A837-0800200C9A66}` |
| F,15 | `{A29EB043-6CE2-4EE2-B38C-F58719E0D88F}` |
| F,19 | `{670173E3-78CF-11E5-A837-0800200C9A66}` |
| F,20 | `{670173E4-78CF-11E5-A837-0800200C9A66}` → `{670173E5-78CF-11E5-A837-0800200C9A66}` |

F,1/F,2/F,6 不存在；Disable_SysFx 不存在或为 DWORD 0；PostMixChild 为 REG_SZ 空字符串；B134 Microsoft context 不存在。F,3 可以已有或缺失，工具始终不写它。脚本匹配 GUID 时忽略大小写，写入前后保护检查则保存原始类型、数据、顺序和 SDDL。

新的设备适配应先收集脱敏检查结果和实测反馈，再独立增加 profile 和测试；不要放宽现有 profile 去“容忍一切”。
