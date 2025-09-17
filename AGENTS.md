# AGENTS.md --- AI/Automation Entry

Read and adhere to `docs/VISION.md` first. Treat it as the source of truth. Use `docs/GUIDANCE.md` for evolving implementation notes.

Primary goals

- Build a single-file Windows HUD using Whisper for local ASR.
- Behave like Windows dictation (UX), but fully offline.

Repo layout

- `wh/`
  - `ui/` --- WPF app (Windows 11 styling, dark mode, blue Record button).
  - `native/` --- Native library stub (to be wired to Whisper later).
  - `docs/`
    - `VISION.md`
    - `GUIDANCE.md`
  - scripts.
  - `README.md` - Docs entrypoint for users and developers.
  - `AGENTS.md` - Docs entrypoint for AI assistants.

Scripts

- `bootstrap.ps1` --- Ensure tools. Installs to `.toolchain` if missing (PortableGit, .NET SDK, MinGW when needed). Deleting `.toolchain` uninstalls.
- `build.ps1` --- Build native first, then UI, produce single-file `.exe` per RID.
- `run.ps1` --- Launch the built app for the current RID.
- `test.ps1` --- CI E2E test: builds, runs HUD, asserts transcript.

CI

- GitHub Actions matrix: x64/arm64 -- MSVC/MinGW. Runs `bootstrap`, `build`, `test`.

Usage (typical)

1) `./bootstrap.ps1`
2) `./build.ps1 -Arch x64 -Compiler mingw` (or `-Compiler msvc`)
3) `./run.ps1`

Notes for Agents

- Keep changes minimal and focused. Prefer replacing code and docs rather than appending. Keep documentation up to date.
- When writing human-facing text (Readme, UI, error messages), prefer natural language and smooth paragraphs over dense wording.
- Prefer PowerShell only for scripts. Avoid global installs; use `.toolchain`.
- Do not use non-ascii chars in messages or source code. Remove any that you find.

Precision mindset

- Treat the build like a well designed machine with tight tolerances: when inputs are correct, the process is minimal and perfect; when something is off, detect it early and stop with a clear, actionable error. Avoid “best-effort” or silent fallbacks in critical paths.

## Getting set up

Immediately run ./bootstrap.ps1 so that tools are available including Git - which is already configured, just not on PATH by default.
