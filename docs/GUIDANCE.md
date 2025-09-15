# GUIDANCE.md (Technical Guidance / Implementation Notes — Non-Binding, Evergreen)

> **Advisory, not prescriptive.** Keep this file up to date as implementation details evolve. `VISION.md` remains the source of truth.

## Repository & Docs Hygiene

- Maintain directories:
  - `/ui` — WPF app (Windows 11 styling, dark mode, blue Record button).
  - `/native` — Native library used by the UI for Whisper integration.
  - `/docs` — `README.md`, `AGENTS.md`, `VISION.md`, plus any additional design notes.
- `AGENTS.md`: **AI-oriented** documentation entrypoint. Contains build/run/test instructions, short project overview, and instructions for how to interact with the developer.
- `README.md`: Human entry point. Project elevator pitch, installation instructions, notes on latest version.
- `

## Bootstrapping & Tooling

- **`bootstrap` script**
  - Validate early; fail fast with actionable errors.
  - Check PATH for:
    - **git portable from git-scm.com**
    - Windows C++ compiler (MSVC and/or MinGW per CI targets)
    - .NET SDK
  - If missing, install locally to `.toolchain`; deleting `.toolchain` removes them.
- **`build` script**
  - Build `/native` first, then `/ui`, then produce a **single-file** `.exe`.
  - Include integrity checks (e.g., verify embedded resources, version stamping).
- **`run` script (optional)**
  - Convenience wrapper to launch the built app.
- **`test` script**
  - Drive **public API** only (CLI and/or UI).
  - Prefer **end-to-end UI** automation for WPF (Selenium-like driver).

## Packaging Pattern

- Ship one `.exe`.
- **First-run behavior**:
  - Create or reuse a user-space directory (e.g., under `AppData\Local\...`).
  - Download the **Whisper model** on first run.
  - Unpack/load any required UI/runtime assets and native components from the single executable into that directory as needed.
  - Load the native DLL and model from this location thereafter.

## Runtime Behavior (Implementation Notes)

- **HUD placement**: Center on the display containing the cursor at time of display.
- **Recording lifecycle**: Auto-start recording with an audible **chime**; allow toggle off.
- **Tray**: Keep a tray icon for quick reactivation; **reset transcription buffer** on minimize and on reopen.
- **Text injection**: Send transcribed text to the **currently focused** control. Keep the injection mechanism behind an abstraction seam to allow strategy changes without touching product logic.

## CI/CD Guidance

- GitHub Actions matrix:
  - x64 Windows **MSVC**
  - arm64 Windows **MSVC**
  - x64 Windows **MinGW**
  - arm64 Windows **MinGW**
- Run `bootstrap`, `build`, and `test` on all matrix targets.
- Prefer explicit, auditable steps; cache where safe.

## Coding Principles

- **Validate early, fail fast** (app and scripts).
- Be **robust to user input**; **do not** be robust to problematic code—**crash with clear errors**.
- Treat **errors and logs as developer documentation** (high-signal, structured logging).

## Testing Guidance

- Focus on user-observable outcomes and stability.
- Keep fixtures minimal and deterministic.
- UI automation should assert the displayed transcription and key HUD behaviors (auto-recording, chime, tray transitions, buffer reset).

## Maintenance

- Keep this guidance in sync with reality as implementation evolves.
- If pieces are no longer needed, delete them. If there are new patterns, rules or advice that would be helpful to future developers, add them.
