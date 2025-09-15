# AGENTS.md — AI/Automation Entry

Read and adhere to `docs/VISION.md` first. Treat it as the source of truth. Use `docs/GUIDANCE.md` for evolving implementation notes.

Primary goals

- Build a single‑file Windows HUD using Whisper for local ASR.
- Behave like Windows dictation (UX), but fully offline.

Repo layout

- `wh/`
  - `ui/` — WPF app (Windows 11 styling, dark mode, blue Record button).
  - `native/` — Native library stub (to be wired to Whisper later).
  - `docs/`
    - `VISION.md`
    - `GUIDANCE.md`
  - scripts.
  - `README.md` - Docs entrypoint for users & developers.
  - `AGENTS.md` - Docs entrypoint for AI assistants.

Scripts

- `bootstrap.ps1` — Ensure tools. Installs to `.toolchain` if missing (PortableGit, .NET SDK, MinGW when needed). Deleting `.toolchain` uninstalls.
- `build.ps1` — Build native first, then UI, produce single‑file `.exe` per RID.
- `run.ps1` — Launch the built app for the current RID.
- `test.ps1` — Minimal CI test: verifies build outputs exist. M2 will add E2E.

CI

- GitHub Actions matrix: x64/arm64 × MSVC/MinGW. Runs `bootstrap`, `build`, `test`.

Usage (typical)

1) `./bootstrap.ps1`
2) `./build.ps1 -Arch x64 -Compiler mingw` (or `-Compiler msvc`)
3) `./run.ps1`

Notes for Agents

- Keep changes minimal and focused. Prefer *replacing* code & docs rather than *appending*. Keep all documentation up-to-date before completing a task.
- When writing human-facing text (Readme, UI, error messages), prefer natural language, explanations, and smooth paragraphs over concise dense wording.
- Prefer PowerShell only for scripts. Avoid global installs; use `.toolchain`.
