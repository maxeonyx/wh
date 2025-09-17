# wh - Whisper on Windows HUD

Tiny Windows HUD for fully local speech-to-text using Whisper, injecting transcribed text into the currently focused field. Design mirrors Windows built-in dictation UX while remaining fully local.

- Vision and requirements: see `docs/VISION.md`.
- Technical notes and evolving guidance: see `docs/GUIDANCE.md`.

> Status
>
> Milestone 2 focuses on a true single-file executable and an end-to-end startup transcription of a fixed WAV file with a black-box UI test. Single-file builds output to `dist/<RID>/wh.exe`. Native DLLs load via single-file extraction.

## Quick Start

- PowerShell: `./bootstrap.ps1` then `./build.ps1` then optionally `./run.ps1`.
- Scripts require `.toolchain/env.ps1` (created by `bootstrap`). They use the local SDK at `.toolchain/dotnet/dotnet.exe` (8.0 LTS). No global installs are used.
- Executable publishes to `dist/<RID>/wh.exe`.
- Sample audio for tests lives at `assets/audio/hello.wav`.

## Test Mode (M2)

- Launch: `dist/<RID>/wh.exe`.
- On startup, the app looks for `assets/audio/hello.wav` near the repo (walking up from the app folder) and transcribes it. The HUD shows "Transcribing..." then the final transcript.
- First run downloads a small Whisper model to `%LOCALAPPDATA%\wh\models\` (override with `WH_MODELS_DIR`).



## Debug Runtime
- Use `./run.ps1 -Debug` to force bundle extraction to `dist/<RID>/extract` and models/logs to `dist/<RID>/runtime`. Logs write to `dist/<RID>/runtime/logs/wh.log`.
