# `wh`

**wh**isper on **w**in+**h**

## Summary

A replacement for the Windows 11 built‑in dictation tool, made to match it in style but use local Whisper under the hood.

The project aims for a minimal, self‑contained build:

- Tooling installs into the repository's `.toolchain/` folder via PowerShell scripts.
- Default hotkey is `Win+H`; `scripts/hotkey-helper.ps1` assists in remapping if needed.
- Models download automatically on first use into `%LOCALAPPDATA%/wh/models`.

See [docs/windows-dictation-research.md](docs/windows-dictation-research.md) for notes on the stock Windows experience.

## Building

Run `scripts/bootstrap.ps1` to fetch a local toolchain (CMake, Ninja, .NET SDK, etc.) into `.toolchain/`. Then run `scripts/build.ps1` which builds whisper.cpp and publishes a single-file `wh.exe` to the `dist/` folder.

`clean-toolchain.ps1` removes the entire `.toolchain/` directory, and `hotkey-helper.ps1` guides users through remapping `Win+H` using PowerToys.

## Runtime dependencies

`wh.exe` is a single self-contained executable with no external runtime dependencies.

## References

- External reference: [OpenWhispr](https://github.com/HeroTools/open-whispr) for UX ideas only.

See [VISION.md](VISION.md) for project goals and [PLAN.md](PLAN.md) for the current implementation plan.
