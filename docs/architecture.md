# 原理与修改边界

## 现有父 APO 和 child

Windows 当前通过 FxProperties 的 F,5 调用 E-APO PRE，通过 F,7 调用 E-APO POST。E-APO 自己按 endpoint GUID 读取 `HKLM\SOFTWARE\EqualizerAPO\Child APOs\{guid}` 的 PreMixChild/PostMixChild，并通过 COM 创建 child。

此方案只将 PreMixChild 从空字符串改为 WM LFX CLSID `{62dc1a93-ae24-464c-a43e-452f824c4250}`。WM LFX 使用系统注册的 `WMALFXGFXDSP.dll`，承载 LEQ 等效果；不是仅实现 LEQ 的独立第三方 DLL。PostMixChild 保持为空，不添加 Microsoft GFX。

E-APO 1.4.2 的实现将初始化数据直接传给 child，并在自身处理前调用 child。若创建/初始化失败，它可以继续自身处理；所以“正常出声”不能单独证明 Microsoft child 成功。

本仓库不会更换 Windows 的 F,5/F,7 为 Microsoft CLSID。也不会把 Microsoft 追加到 OEM F,13，或把多项 Composite 列表拼到一个 child 字符串中。

## 参数与 context

只向已有 FxProperties 根写 stereo `,3` enable/release 参数。12-byte enable 记录的 payload 是 VARIANT_BOOL -1/0，release payload 是 little-endian 32-bit 档位；共同中间 DWORD 1 按已验证编码保留，不推断为秒数或未证实的格式语义。

本地历史 Microsoft endpoint 的 B134\User 中出现过同样的 enable 编码与 release=3。标准 hdaudio.inf 采用 modern Microsoft context 布局；这不代表 legacy child 必须创建同样 context。旧式 APOInitSystemEffects 传递 endpoint/effects property-store 指针，E-APO 走相同参数转发路径。源码和官方接口支持此实验方向，原案例也有用户效果反馈；其它机器仍需逐台验证。

Microsoft context 缺失时不 CreateSubKey；存在时本 profile 会停止，避免混用不同配置存储。`,1599` 对应另一个声道掩码，本立体声路径不写它。SysFxUI 和 Properties 中的 UI 通知值不作为本方案的必要 DSP 参数。

## 共存限制

F,5 与 Composite F,13 属于同一个 SFX 插入位置的两种表达。保留所有 registry 列表不能单凭静态配置保证 Windows 同时执行全部 APO。原案例保留绑定且用户没有报告 OEM 功能损坏；本项目要求新设备验证 OEM 行为，未作“每 sample 均共同处理”的承诺。

## 来源

- [Microsoft Combine custom and Windows APOs](https://learn.microsoft.com/en-us/windows-hardware/drivers/audio/combine-custom-and-windows-apos)：包装、初始化及 channel-mask 参数原则。
- [APOInitSystemEffects](https://learn.microsoft.com/en-us/windows/win32/api/audioenginebaseapo/ns-audioenginebaseapo-apoinitsystemeffects)：初始化结构。
- [Composite SFX](https://learn.microsoft.com/en-us/windows-hardware/drivers/audio/pkey-compositefx-streameffectclsid)：同一位置的多项形式。
- [Equalizer APO 1.4.2 运行实现](https://sourceforge.net/p/equalizerapo/code/ci/1.4.2/tree/EqualizerAPO/EqualizerAPO.cpp) 与 [设备配置实现](https://sourceforge.net/p/equalizerapo/code/ci/1.4.2/tree/DeviceAPOInfo.cpp)。
- [LEQControlPanel](https://github.com/ArtIsWar/LEQControlPanel)：本案例审计过 v1.0.1 的参数与安装行为；此仓库不调用其安装引擎。

以上公开资料用于解释机制。具体本机参数匹配、用户报告和未取得的运行时证据以兼容性与验证文档为准。
