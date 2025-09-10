# wh Agent Guide

This repository hosts a native Windows dictation mini-app powered by whisper.cpp. The runtime ships as a single `wh.exe` and downloads models on demand.

- No Python or Node.js dependencies
- Toolchain installed locally under `.toolchain/` via PowerShell scripts
- Default global hotkey: `Win+H`
- Models stored in `%LOCALAPPDATA%/wh/models`

For project goals see [VISION.md](VISION.md). For architecture and implementation details see [PLAN.md](PLAN.md).

## Getting Started
- `scripts/bootstrap.ps1` – download portable CMake, Ninja, .NET SDK into `.toolchain/` and fetch whisper.cpp
- `scripts/build.ps1` – build whisper.cpp and publish a single-file executable to `dist/`
- `scripts/clean-toolchain.ps1` – remove the `.toolchain/` directory
- `scripts/hotkey-helper.ps1` – assist in remapping `Win+H` via PowerToys

## Repository Layout
- `engine/` – native whisper.cpp build
- `ui/` – WPF front end
- `scripts/` – PowerShell automation
- `third_party/` – external sources
- `docs/` – research notes and planning docs
- `dist/` – build output

Consult `docs/open-whispr-notes.md` and the [OpenWhispr](https://github.com/HeroTools/open-whispr) repository for UX and model-management ideas without adopting its technology stack.
