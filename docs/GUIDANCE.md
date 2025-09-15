# GUIDANCE.md (Technical Guidance / Implementation Notes)

Advisory, not prescriptive. Keep this file up to date as implementation details evolve. `VISION.md` remains the source of truth.

## Repository and Docs Hygiene

- Maintain directories:
  - `ui/` - WPF app (Windows 11 styling, dark mode, blue Record button).
  - `native/` - Native library used by the UI for Whisper integration.
  - `docs/` - `VISION.md` and ongoing design notes.
- Top-level docs at repo root: `README.md` and `AGENTS.md`.
- App name is lowercase `wh` across code, scripts, and docs.

## Bootstrapping and Tooling

- `bootstrap.ps1`
  - Validate early; fail fast with actionable errors.
  - Check PATH for: Portable Git, Windows C++ compiler (MSVC or MinGW), .NET SDK.
  - If missing, install locally to `.toolchain`; deleting `.toolchain` removes them.
- `build.ps1`
  - Build `native/` first, then `ui/`, then produce a single-file `.exe`.
  - Include integrity checks (e.g., verify embedded resources, version stamping).
- `run.ps1`
  - Convenience wrapper to launch the built app.
- `test.ps1`
  - Drive public API only (CLI and UI). Prefer end-to-end UI automation for WPF.

## Packaging Pattern

- Ship one `.exe`.
- First-run behavior:
  - Create or reuse a user-space directory (under `AppData\\Local\\wh`).
  - Download the Whisper model on first run.
  - Load the native DLL and model from this location thereafter.

## Runtime Behavior

- HUD placement: Center on the display containing the cursor at time of display.
- Recording lifecycle: Auto-start recording with an audible chime; allow toggle off.
- Tray: Keep a tray icon for quick reactivation; reset transcription buffer on minimize and on reopen.
- Text injection: Send transcribed text to the currently focused control. Keep the injection behind an abstraction seam.

## CI/CD Guidance

- GitHub Actions matrix:
  - x64 Windows MSVC
  - arm64 Windows MSVC
  - x64 Windows MinGW
  - arm64 Windows MinGW
- Run `bootstrap`, `build`, and `test` on all matrix targets.
- Prefer explicit, auditable steps; cache where safe.

## Coding Principles

- Validate early, fail fast (app and scripts).
- Be robust to user input; do not be robust to problematic code. Crash with clear errors.
- Treat errors and logs as developer documentation (high-signal, structured logging).

## Testing Guidance

- Focus on user-observable outcomes and stability.
- Keep fixtures minimal and deterministic.
- UI automation should assert the displayed transcription and key HUD behaviors.

## Maintenance

- Keep this guidance in sync with reality as implementation evolves.
- If pieces are no longer needed, delete them. If there are new patterns, rules or advice that would be helpful to future developers, add them.

