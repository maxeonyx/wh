# wh — Whisper on Windows H

Tiny Windows HUD for fully local speech‑to‑text using Whisper, injecting transcribed text into the currently focused field. Design mirrors Windows’ built‑in dictation UX while remaining fully local.

- Project vision and requirements: see `docs/VISION.md`.
- Technical notes and evolving guidance: see `docs/GUIDANCE.md`.

> **Status**
>
> Milestone 1 cleanup complete: normalized naming to lowercase `wh`, updated scripts/docs/paths, and moved sample audio to `assets/audio/hello.wav`. Single-file builds now output `ui/wh/publish/<RID>/wh.exe`.

## Quick Start

- PowerShell: `./bootstrap.ps1` then `./build.ps1` then optionally `./run.ps1`.
- Executable is at `ui/wh/publish/<RID>/wh.exe`.
- Sample audio for tests lives at `assets/audio/hello.wav`.
