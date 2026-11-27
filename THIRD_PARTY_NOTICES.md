# 来源、许可与外部组件

本仓库的脚本和文档以 GPL-3.0-only 发布，完整许可见 LICENSE。Copyright (C) 2026 Y9000P PUBG Audio contributors。

## LEQControlPanel 与先前工作

本项目的参数研究参考 ArtIsWar/LEQControlPanel v1.0.1（审计 commit `1207e2f439250cf298c858d80783e8c3bbb214b3`）。该项目提供 GPLv3 许可，其 NOTICE 为：

> LEQ Control Panel
> Copyright (C) 2025-2026 ArtIsWar LLC
> Based on enable-loudness-equalisation by Falcosc
> https://github.com/Falcosc/enable-loudness-equalisation

来源：[ArtIsWar/LEQControlPanel](https://github.com/ArtIsWar/LEQControlPanel)、[Falcosc/enable-loudness-equalisation](https://github.com/Falcosc/enable-loudness-equalisation)。本仓库不打包上游 EXE 或完整引擎，不调用其 Clean Install/Fix/Repair；保留来源说明，并为此前本地脚本的参数化与回滚逻辑使用兼容的 GPL-3.0-only 许可。

## Equalizer APO

Equalizer APO 是独立安装的外部依赖，作者 Jonas Thedering 及其贡献者，许可依其上游文件。本案例使用 1.4.2 的 child 机制。本仓库不包含 E-APO 源码、DLL、安装器或 Peace 文件。

官方项目：https://sourceforge.net/projects/equalizerapo/

## Microsoft 与 OEM

Windows 的 WMALFXGFXDSP.dll、SysFxUI.dll 和 Lenovo/Realtek/Nahimic/Elevoc 组件由各自提供者发布。本仓库只检查已有组件或保存其配置快照，不复制、下载、修改这些二进制，不授予其再分发许可。

Lenovo、Legion、Realtek、Nahimic、Elevoc、Microsoft、Windows、Apple、PUBG 等名称用于说明设备、依赖或场景，不表示官方合作或背书。
