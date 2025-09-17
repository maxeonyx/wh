# wh - Whisper on Windows HUD

Tiny Windows HUD for fully local speech-to-text using Whisper, injecting transcribed text into the currently focused field. Design mirrors Windows built-in dictation UX while remaining fully local.

- Vision and requirements: see `docs/VISION.md`.
- Technical notes and evolving guidance: see `docs/GUIDANCE.md`.

> Status
>
> Milestone 3: on startup, the app transcribes a fixed WAV and injects the final transcript into the currently focused text area (e.g., Notepad), while keeping the HUD open. Packaging remains a single-file `wh.exe`; native DLLs load via single-file extraction.

## Quick Start

- PowerShell: `./bootstrap.ps1` then `./build.ps1` then optionally `./run.ps1`.
- Scripts require `.toolchain/env.ps1` (created by `bootstrap`). They use the local SDK at `.toolchain/dotnet/dotnet.exe` (8.0 LTS). No global installs are used.
- Executable publishes to `dist/<RID>/wh.exe`.
- Sample audio for tests lives at `assets/audio/hello.wav`.

## Behavior (M3)

- Launch: `dist/<RID>/wh.exe`.
- On startup, the app looks for `assets/audio/hello.wav` near the repo, transcribes it, and sends the resulting text to whatever control currently has focus (mirroring Windows dictation). The HUD status shows "Transcribing..." then "Ready" once done.
- First run downloads a small Whisper model to `%LOCALAPPDATA%\wh\models\` (override with `WH_MODELS_DIR`).

## Testing (E2E)

- Run `./test.ps1` to build, publish, and drive an end-to-end UI test.
- The test launches a small WinForms target app (`TextSink.exe`) with a textbox, sets focus to it, then launches `wh.exe` and asserts the injected transcript.
- Timeouts are enforced and both apps are closed by the test, even on failure.
- For stability in CI, the injector can be overridden to clipboard paste via `WH_INJECTOR=clipboard`.



## Debug Runtime
- Use `./run.ps1 -Debug` to force bundle extraction to `dist/<RID>/extract` and models/logs to `dist/<RID>/runtime`. Logs write to `dist/<RID>/runtime/logs/wh.log`.
