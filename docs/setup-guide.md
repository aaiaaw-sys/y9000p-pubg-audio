# 设置步骤

## 先确认问题和设备

本路径适用于没有原生增强入口、或增强页为空，但已有 Realtek/OEM 和 E-APO 的相同结构设备。仅仅看到“没有 Enhancements”并不足以应用它。工具不会删除 CompositeFX 来让界面出现。

使用 3.5mm 耳机，手工设为默认播放设备。避免选择 Speakers、HDMI、Bluetooth 或 Nahimic virtual device。先确认普通播放正常、OEM 功能正常；关闭空间音效等额外处理，临时旁路 EQ/VST 以便比较。项目不会代替你改动这些设置。

本案例使用 Equalizer APO 1.4.2。请从 [官方项目](https://sourceforge.net/projects/equalizerapo/) 获取，按官方步骤为目标耳机配置；本工具要求已经存在 PRE F,5 / POST F,7 和 version-2 child 键。不要执行第三方 Clean Install / Chain Repair 来强行通过检测。

Peace 是可选界面；本案例最后只用 LEQ，`peace.txt` 没有滤波器，ReaComp 行已注释。不要把普通压缩器的效果当成 Microsoft LEQ 的验证。

## 检查和预览

1. 解压整个仓库，保留相对目录。建议放到较短且可信的本地路径。
2. 打开 64 位 Windows PowerShell 5.1，进入仓库。
3. 如需要，执行 `Set-ExecutionPolicy -Scope Process Bypass`，不修改系统级策略。
4. 运行 `scripts\Get-AudioStatus.ps1`，核对耳机名称、GUID 和 Issues。
5. 指定 GUID，运行不带 `-Apply` 的 Enable 命令。

所有检查匹配后，预览应只有 release,3、enable,3、PreMixChild 三项。已有参数、已有 child、额外 MS context、OEM 列表/顺序不同等都会阻止安装。匹配签名和 E-APO 版本在安装计划中额外检查；`ProfileMatched` 单独不代表具备写权限。

## 应用

按 README 的命令在已提升的管理员终端显式使用 `-Apply`。脚本先取得两个最小写句柄、保存备份并校验，才写注册表。访问拒绝会停止，不自动修改任何权限。

默认 release 档位 4；可在首次安装时使用 `-ReleaseCode 2` 到 `7`。数字是档位，不是秒数。第一版不提供任意参数编辑或安装后 release 调整，方便保持回滚边界。

脚本打印 `BackupDirectory`。其中 `backup.json` 与 SHA256 保存不可覆盖的原状态，`ownership.json` 记录本工具最后写入/待完成的 ON/OFF 状态。两者都要保留。不要手工编辑 ownership 来绕过冲突检查。

手工重启后进行[验证](verification-and-pubg-notes.md)。写入成功不等于增强页、某个工具的 Active 标签或 PUBG 听感已经成功。

## 可选桌面快捷方式

成功配置并保存备份后：

```powershell
$backup = '本次安装的 BackupDirectory'
.\scripts\Install-LeqShortcuts.ps1 -BackupDirectory $backup
.\scripts\Install-LeqShortcuts.ps1 -BackupDirectory $backup -Apply
```

会创建 `Y9000P LEQ Toggle` 和 `Y9000P Audio Status` 两个快捷方式。Toggle 每次通过正常 UAC 请求提升，完成/失败均有提示；不创建 SYSTEM 或最高权限计划任务，不重启 Audiosrv。保持仓库和备份路径不变，只运行你信任且未被修改的源码。

删除这两个桌面 `.lnk` 文件即可卸载快捷方式。**这不会关闭或撤销 LEQ**；完整撤销需要 Restore 命令与原备份。
