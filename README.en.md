# Y9000P PUBG Audio

[中文完整文档](README.md)

A narrowly scoped Microsoft Loudness Equalization configuration toolkit based on a Lenovo Legion Y9000P IAX10 / Windows 11 / Realtek / Nahimic / Elevoc / Apple EarPods case. It delegates to the Microsoft WM LFX APO through an existing Equalizer APO PRE child binding, preserves the OEM CompositeFX registry configuration, and provides guarded per-value rollback.

The original device-specific configuration was reported effective by its user without Peace EQ. Version 0.1.0 has passed simulation, syntax and GitHub Windows checks; its generalized installation path has not been applied to a second physical device. Registry configuration is not proof of DSP processing or measured PUBG improvement.

## Requirements

- 64-bit Windows PowerShell 5.1, Windows 11, Equalizer APO 1.4.2 already installed on the selected endpoint.
- Active Realtek headphones/headset, extensible stereo format with channel mask 3.
- Existing E-APO PRE F,5 and POST F,7 bindings; existing version-2 child key with empty PreMixChild/PostMixChild.
- OEM Composite lists matching the tested profile; no Microsoft CAPX context or competing LEQ parameters.

The tool refuses mismatches. Matching a laptop model alone is insufficient. It never installs drivers, repairs E-APO, alters ACLs, creates registry keys, or removes OEM APOs.

## Usage

Use the endpoint GUID returned by the read-only status command. No endpoint is selected automatically.

```powershell
.\scripts\Get-AudioStatus.ps1
$endpoint = '{your headphone endpoint GUID}'
.\scripts\Enable-MicrosoftLeq.ps1 -EndpointId $endpoint -ReleaseCode 4
# Review the proposed diff. Only then, in an elevated terminal:
.\scripts\Enable-MicrosoftLeq.ps1 -EndpointId $endpoint -ReleaseCode 4 -Apply
```

Keep the returned backup directory private and restart Windows manually. Validate normal audio, OEM controls, actual LEQ behavior and reboot persistence before keeping the configuration.

```powershell
$backup = 'the installation BackupDirectory'
.\scripts\Set-LeqState.ps1 -BackupDirectory $backup -State Off -Apply
.\scripts\Set-LeqState.ps1 -BackupDirectory $backup -State On -Apply
.\scripts\Restore-MicrosoftLeq.ps1 -BackupDirectory $backup
.\scripts\Restore-MicrosoftLeq.ps1 -BackupDirectory $backup -Apply
```

Without `-Apply`, these commands only preview. Install writes the release code, enable bytes and PreMixChild, in that order. Switch changes one value. Restore checks the complete set before mutation; unknown third values cause refusal, not overwrite. Existing installations cannot be adopted without their original state. Legacy backups are not compatible with this release's schema.

Optional desktop shortcuts request UAC for each toggle. No elevated scheduled task or automatic audio-service restart is installed. See the Chinese [setup guide](docs/setup-guide.md) and [recovery guide](docs/rollback-and-troubleshooting.md).

## Development

Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1`. Registry transaction tests use in-memory keys. GPL-3.0-only; attribution and dependencies are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
