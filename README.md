# Y9000P PUBG Audio

[English](README.en.md) · [完整设置步骤](docs/setup-guide.md) · [恢复与排错](docs/rollback-and-troubleshooting.md)

在联想拯救者 Y9000P IAX10 的 Windows 11 / Realtek / Nahimic / Elevoc 音频环境下，通过 **Equalizer APO 的 PRE child APO 调用 Microsoft Windows Loudness Equalization（LEQ，音量均衡）**。提供设备检查、三值配置、ON/OFF 开关和逐值回滚，用于与本案例结构相同的 3.5mm 耳机环境。

项目来自 Apple EarPods 的实际配置过程。使用者确认 Microsoft LEQ 有效，最终方案未搭配 Peace EQ。它调用系统的 `WMALFXGFXDSP.dll`，不提供普通 compressor 代替 LEQ，也不包含“PUBG 神级 EQ”预设。

**版本：0.1.0。** 原始固定设备方案已实机使用；本仓库的通用化工具已通过内存模拟、语法及 GitHub Windows 自动检查，尚需用户在明确选择的设备上完成安装、重启和听感验证。没有逐 APO 的实时 graph 测量或客观 PUBG 脚步提升数据。

## 可以解决什么

- 设备没有传统 Enhancements 页，或添加 Microsoft UI 后页面仍为空。
- 希望保留现有 OEM CompositeFX 绑定，通过已有 E-APO child 接入 Microsoft LEQ。
- 需要知道具体改了什么、如何关闭，以及如何仅撤销本次修改。

本项目目标是获得实际音频处理效果；不会保证旧式 Enhancements 页填满效果列表。

## 支持范围与前置条件

实测案例：Y9000P IAX10、Windows 11、Realtek 6.0.9882.1、Equalizer APO 1.4.2、3.5mm Apple EarPods，见[兼容性记录](docs/tested-hardware.md)。其它同类电脑需要先通过结构检查，不能直接套用设备 GUID 或 OEM 列表。

工具只支持已有 E-APO SFX/EFX（PRE/POST）挂载、已有空 child 键、立体声 mask=3、与案例一致的 OEM Composite 列表，以及没有 Microsoft CAPX context 的旧式 root-store 路径。E-APO DLL 版本必须为 1.4.2。失败会停止，不自动修权限、切模式或重装驱动。

需要 **64 位 Windows PowerShell 5.1**。只读检查不需要主动提升；`-Apply` 需要已提升的管理员终端。请先保存音频相关工作，并按官方方式安装 [Equalizer APO](https://sourceforge.net/projects/equalizerapo/)。项目不自动安装第三方软件或改变其设备配置。

## 快速开始

下载仓库源码 ZIP 并解压，保留 `scripts/` 和 `src/` 的相对位置。在仓库目录打开 Windows PowerShell。若脚本被执行策略阻止，可仅为当前终端设置：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

### 1. 只读检查并选择耳机

```powershell
.\scripts\Get-AudioStatus.ps1
```

核对名称、适配器、`EndpointId` 和 `Issues`。只选择你的 **Realtek 耳机**；工具不会猜默认设备。`ProfileMatched=True` 表示配置结构符合本路径，不代表 LEQ 已处理声音。

### 2. 预览三值配置

将下列变量替换为刚读到的 GUID，不包含 Render 路径：

```powershell
$endpoint = '{你的耳机 endpoint GUID}'
.\scripts\Enable-MicrosoftLeq.ps1 -EndpointId $endpoint -ReleaseCode 4
```

不加 `-Apply` 的安装、状态修改、回滚和快捷方式安装均为 dry-run。已配置过 LEQ 的设备会停止重新安装；**不要为通过检查而删除现有值**，参见[已有安装](docs/rollback-and-troubleshooting.md#已有旧版配置)。

### 3. 明确应用并保留备份

在已提升的同一类终端中：

```powershell
.\scripts\Enable-MicrosoftLeq.ps1 -EndpointId $endpoint -ReleaseCode 4 -Apply
```

记录输出的 `BackupDirectory`。默认保存到本地 `runtime/installation-*`，包含私有配置和 SDDL，**不要公开上传**。手动重启 Windows，按[验证清单](docs/verification-and-pubg-notes.md)检查声音、LEQ、OEM 功能和持久性。

### 4. 日常开关与完整撤销

```powershell
$backup = '本次输出的 BackupDirectory 完整路径'

# 关闭 LEQ，保留 child 和 release 参数
.\scripts\Set-LeqState.ps1 -BackupDirectory $backup -State Off -Apply

# 开启，或显式切换 Toggle
.\scripts\Set-LeqState.ps1 -BackupDirectory $backup -State On -Apply

# 预览并完整撤销本次三值配置
.\scripts\Restore-MicrosoftLeq.ps1 -BackupDirectory $backup
.\scripts\Restore-MicrosoftLeq.ps1 -BackupDirectory $backup -Apply
```

切换后可能需要重新打开播放应用或手动重启 Windows；脚本不自动重启音频服务。可选[桌面快捷方式](docs/setup-guide.md#可选桌面快捷方式)每次请求正常 UAC，不创建持久提升计划任务。

## 精确写入范围

以显式选择的 Render endpoint 为目标，**只写三个值**：

| 位置 | Value name | 类型 | 新值 |
|---|---|---|---|
| `HKLM\SOFTWARE\EqualizerAPO\Child APOs\{endpoint}` | `PreMixChild` | REG_SZ | `{62dc1a93-ae24-464c-a43e-452f824c4250}` |
| `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\{endpoint}\FxProperties` | `{fc52a749-4be9-4510-896e-966ba6525980},3` | REG_BINARY | `0B 00 00 00 01 00 00 00 FF FF 00 00` |
| 同上 | `{9c00eeed-edce-4cd8-ae08-cb05e8ef57a0},3` | REG_BINARY | 默认 `03 00 00 00 01 00 00 00 04 00 00 00` |

先写 release、enable，最后绑定 child。开关只改 enable。回滚先解绑 child，再恢复两项参数；合法 ON/OFF 切换通过私有 ownership journal 跟踪。

F,3、E-APO F,5/F,7、OEM F,13/F,14/F,15/F,19/F,20 及顺序、processing modes、context、ACL/Owner 和驱动保持原状。不会新增 F,5/F,6，不创建注册表键、不 take ownership、不使用 SYSTEM/TrustedInstaller、不修改 DriverStore，也不更改 Peace、ReaComp、游戏配置或服务。写句柄仅申请 `QueryValues | SetValue`（`0x3`）。

## 结果与证据

原案例有三值写入/立即读回成功记录及 ON/OFF 操作记录；使用者确认实际有效。OEM 绑定在写入前后保持一致，用户未报告 OEM 功能异常。DLL 加载/逐 sample 处理未取得完整证明。配置、模块加载、实际效果是不同证据层级，详见[验证说明](docs/verification-and-pubg-notes.md)。

## 开发与反馈

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
```

测试使用内存注册表替身，不写真实音频配置。提交兼容性反馈请填写硬件、版本、检查结果及听感；手工脱敏后再上传，见 [CONTRIBUTING](CONTRIBUTING.md)。

采用 GPL-3.0-only，见 [LICENSE](LICENSE) 和 [第三方来源](THIRD_PARTY_NOTICES.md)。本项目不附带 Microsoft、Lenovo、Realtek、Nahimic、Elevoc、E-APO 或 Peace 二进制。
