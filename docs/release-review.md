# 首次发布审阅清单

## 待发布成品

- 名称：`y9000p-pubg-audio`
- 版本：`0.1.0-rc.1`
- 许可：GPL-3.0-only，含上游来源说明。
- 首页：中文，另有英文入口。
- 范围：原实测案例和匹配的 Realtek / E-APO 1.4.2 / OEM Composite stereo 结构。
- 原固定设备方案由使用者确认有效；通用化脚本仍需新的实机验收，不冒称跨机型验证。

## 上传前应确认

1. README 是否准确反映实际体验和适用边界。
2. 初版应公开为发布候选，并保持“配置状态不等于实际处理”的说明。
3. 仓库名、GitHub 账号/组织、Public 可见性和许可是否认可。
4. tests/Run-Tests.ps1 与 tests/Check-PublicFiles.ps1 均通过。
5. git diff --cached 中只有公开源码与文档，runtime、dist、个人原始项目都未暂存。
6. 不含个人路径、SID、真实 endpoint 实例标识、完整系统备份或第三方二进制。
7. 在联网 CI 中验证 Actions；本地测试通过不能冒充远端 workflow 已运行。

## 制作源码包

在仓库中暂存并审阅文件后：

```powershell
.\scripts\New-ReleaseArchive.ps1
.\scripts\New-ReleaseArchive.ps1 -Apply
```

源码包只取 Git 已跟踪/暂存的文件，包含隐藏的 GitHub workflow 和 gitignore，不包含 .git、runtime 或 dist。它不表示已经上传或发布 Release。保留输出的 SHA256 以便核对。

第一次 GitHub 创建/上传在使用者审阅具体成品并确认后进行。未配置 GitHub 账号时不猜测身份，不把 token 写入脚本或仓库。
