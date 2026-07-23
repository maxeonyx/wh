# wh Rewrite Requirements

Status: durable rewrite brief extracted from the September 2025 `wh` and `wh1` prototypes before their intentional deletion during the Windows profile migration.

This document preserves product intent, validated lessons, and unresolved decisions. It does not preserve the old implementation as an architectural mandate. A new repository should be created only when the rewrite starts.

## Product Purpose

`wh` is a small Windows dictation HUD for private, local speech-to-text in whichever Windows text field the user is actively using. It should feel as immediate as Windows voice typing while performing speech recognition on-device with Whisper. Normal dictation must not upload microphone audio or transcripts.

## Existing Alternative: Handy

Before implementing a greenfield rewrite, evaluate [cjpais/Handy](https://github.com/cjpais/handy) as both a working comparison and a possible fork base. Handy is an actively developed, offline, open-source dictation application for Windows, macOS, and Linux. It already covers configurable shortcuts, push-to-talk/toggle recording, local Whisper and Parakeet models, voice activity detection, GPU acceleration where available, system-tray operation, and insertion into the active application.

The first rewrite decision is therefore not "how should the old prototype be rebuilt?" but:

1. Can stock Handy satisfy the driving requirements through configuration?
2. If not, can a focused Handy fork satisfy them with less code and maintenance than a new application?
3. Only if neither path fits should `wh` proceed as a greenfield rewrite.

Any Handy fork or redistribution must retain the applicable MIT-licensed source obligations while using independent branding; Handy's name, logo, icon, and brand assets are explicitly excluded from its open-source grant.

## Core User Experience

1. The user invokes `wh` while a target text field has focus.
2. A small HUD appears on the monitor containing the cursor without taking focus from the target application.
3. Recording starts by default and an audible chime confirms it.
4. The HUD clearly distinguishes listening, processing, ready, paused, model-download, and error states.
5. Speech is transcribed locally and inserted at the target caret with full Unicode support.
6. The prominent microphone control pauses or resumes recording.
7. Closing or minimizing the HUD returns it to the system tray for quick reopening; an explicit Exit command terminates the resident process.
8. Minimizing to the tray and reopening reset any in-progress transcription buffer.

## Functional Requirements

### Activation and focus

- Provide a global activation shortcut. The intended default is `Win+H`.
- If Windows or another application owns the shortcut, explain the conflict and offer a usable alternative or remapping path.
- Do not make PowerToys a required dependency; it was only a prototype workaround.
- The HUD must be topmost and non-activating. Showing, interacting with, or restoring it must not unexpectedly redirect text away from the user's target.
- Define and test whether the injection target is the control focused when recording starts or the control focused when insertion occurs.

### Audio and transcription

- Capture live microphone audio. Transcribing a bundled WAV at startup was test scaffolding, not product behavior.
- Perform inference locally with a Whisper-compatible engine and a user-local model.
- Never transmit microphone audio or transcript text as part of normal operation.
- Expose clear handling for missing permission, unavailable microphone, device loss, model failure, cancellation, and transcription failure.
- Decide whether transcription is final-only or incremental. If interim text is inserted, support reliable correction/replacement of the most recent segment.
- Release microphone and model resources on explicit exit.

### Text insertion

- Insert complete transcripts into conventional Win32, WinForms, WPF, and modern Windows text controls.
- Preserve Unicode, long text, line breaks, and punctuation without depending on the active keyboard layout.
- Avoid changing the clipboard during normal operation where practical. If clipboard injection is used as a compatibility fallback, preserve and restore clipboard contents safely.
- Keep insertion behind a replaceable interface. `SendInput`, clipboard paste, and UI Automation are implementation options rather than public requirements.
- Detect and report failed or partial insertion instead of silently claiming success.
- Define whether injection into elevated applications is supported and communicate the boundary clearly.

### Model lifecycle

- Store models under `%LOCALAPPDATA%\wh\models` by default and reuse them offline.
- Before the first model download, show the model name, source, approximate size, and obtain user consent.
- Defaulting to an English `tiny.en` model of roughly 75 MB is reasonable historical behavior, not a permanent product constraint.
- Download to a temporary file, permit cancellation, and finalize atomically only after verification.
- Verify model downloads against a release-controlled expected size and cryptographic digest. A digest generated only after download is not sufficient to authenticate the original transfer.
- A cancelled or failed transfer must not appear installed and must be retryable.
- Candidate future functionality, requiring a product decision: model choice, remembered selection, download progress/speed, model deletion, and model updates.

### Tray and lifecycle

- Keep a resident tray process so reopening is fast.
- Provide Open and Exit tray commands; double-click may open the HUD.
- Define close-button semantics explicitly: minimize to tray or exit.
- Repeated open, close, pause, resume, and exit cycles must not leave hidden or orphaned processes.
- Launch-at-login is an open product decision, not a default requirement.

## UX Requirements

- Use a minimal Windows 11-style dark HUD with one prominent blue microphone control and little secondary chrome.
- Keep the window borderless, compact, fixed-size, draggable, absent from the taskbar, topmost, and non-activating.
- Center it within the working area of the display containing the cursor. Bottom-center placement from early research is superseded.
- Provide visible, accessible feedback for every meaningful state without relying on hidden developer logs.
- Use an audible start chime. A stop chime remains an open decision.
- Omit Settings and Help controls unless they lead to complete workflows.
- Exact historical dimensions (`220x200`, 72-pixel microphone button) are references, not requirements.
- WPF was named in the old vision, but the rewrite may choose another suitable Windows UI framework if it meets the behavior, accessibility, packaging, and focus requirements.

## Privacy and Security

- Audio and transcript processing remain on-device after model acquisition.
- Logs must not contain audio or transcript contents by default.
- Network access must be limited to explicit model/tool/update acquisition and be visible to the user where appropriate.
- Pin or authenticate downloaded dependencies and models using publisher-controlled metadata.
- Store runtime data in user-local locations with ordinary user permissions; do not require administrator rights for normal installation-free use.
- Preserve required third-party copyright and license notices, including those for `whisper.cpp`, if reused.

## Distribution and Runtime

- Distribute exactly one self-contained `wh.exe`; no installer, sidecar DLL, framework installation, Python, or Node.js may be required.
- The executable must contain all managed/native dependencies and built-in assets. Runtime extraction to a user-local cache is allowed.
- Models remain separate, downloaded user data and are not bundled into the distributed executable.
- After a valid model is cached, startup and dictation must work without a network connection.
- The executable must remain relocatable: moving the EXE to a clean directory must not break startup or native-library resolution.
- Native loading must work reliably in ordinary and deterministic-debug extraction locations.
- Repeated startup must not hang or require Task Manager intervention.

## Diagnostics and Failure Behavior

- Write high-signal structured diagnostics to a user-local location.
- Record application version, executable path, runtime/extraction location, model identity, native-library resolution, state transitions, and errors.
- Do not log transcript or audio content by default.
- Fail clearly on broken invariants and developer/configuration errors.
- User-recoverable failures such as network interruption or denied microphone permission should present actionable recovery without corrupting state.
- Logging failure alone must not prevent the user-facing application from starting when a safe fallback is possible.
- Every child process launched by development or test tooling must have a timeout and deterministic cleanup.

## Performance and Compatibility

- Reopening from the tray should feel immediate; exact startup, model-load, and transcription latency budgets must be set during rewrite planning.
- Support Windows x64. Windows ARM64 was intended by the prototype but never validated; decide whether it is required for the first release.
- Test multi-monitor placement and scaling.
- Keep CPU and memory use acceptable during idle, recording, and transcription; measurable budgets remain to be chosen.
- Preserve full transcripts without truncation. The prototype's possible `SendInput` event-batching issue must be covered by long-text tests.

## Build and Developer Workflow

- Provide one-command bootstrap, build, run, and test workflows from PowerShell.
- Bootstrap must be idempotent, check before downloading, prefer appropriate existing tools, and keep any private toolchain removable and repository-local.
- Build native components before publishing the UI and produce exactly one distributable EXE per supported architecture/configuration.
- Keep useful incremental build caches while ensuring the distributable directory contains only the intended EXE. The old demand to destroy every intermediate artifact conflicted with its own incremental-build goal and is not retained.
- Fail early with actionable errors when compilers, SDKs, downloads, native libraries, or expected outputs are missing.
- Keep detailed documentation discoverable from a small number of root entry points.
- Do not preserve old internal names such as `engine.dll` or `wh.dll` as compatibility commitments.

## Acceptance Tests

### Distribution isolation

- Copy only the built EXE to a fresh directory outside the repository.
- With a controlled external model cache, verify startup, native loading, local transcription, focused-control insertion, shutdown, and a second launch.
- Verify that no repository file, sidecar DLL, global SDK, Python installation, or Node.js installation is required.
- Exercise both default runtime extraction and a deterministic debug extraction location.
- Enforce bounded timeouts and terminate all child processes on failure.

### First run and offline use

- Verify informed model-download consent, progress/error/cancellation behavior, atomic finalization, and trusted digest validation.
- After the model is cached, disconnect network access and verify repeated startup and dictation.
- Corrupt or truncate the cached model and verify that the app detects it and offers a safe recovery path.

### Dictation behavior

- Test live microphone start, pause, resume, cancellation, device loss, and explicit exit.
- Test final or incremental transcription according to the chosen policy.
- Test injection into representative Win32, WinForms, WPF, browser, and modern Windows controls.
- Test long text, Unicode outside the BMP, punctuation, line breaks, and correction/replacement.
- Verify that opening the HUD does not steal focus and that target-selection semantics match the documented rule.

### HUD and tray

- Test placement on each monitor at multiple DPI scales.
- Test all visual states, accessible names, keyboard behavior, chime, and microphone toggle.
- Test minimize/reopen buffer reset, tray Open/Exit, repeated lifecycle loops, and absence of orphan processes.

### Build matrix

- Run bootstrap twice to prove idempotency.
- Build and isolate-test every supported architecture and compiler configuration.
- Confirm the distribution directory contains exactly one EXE.
- Verify clean and incremental builds, dependency integrity checks, and useful error output.

## Explicitly Discarded Prototype Behavior

- Looking for `assets/audio/hello.wav` during normal startup.
- Transcribing one fixed WAV, injecting it, and immediately exiting.
- Treating hidden status text as sufficient user feedback.
- Inert Settings and Help buttons.
- Clipboard injection as the normal strategy.
- PowerToys as a required shortcut dependency.
- Exact prototype output directories, DLL names, environment variables, and native ABI.
- Automatic fallback/retry algorithms prescribed by contradictory draft notes.
- Research observations such as "any key stops dictation", `Esc` closing the HUD, and punctuation controls until deliberately accepted as product requirements.

## Open Product Decisions

- Decide between stock Handy, a narrowly maintained Handy fork, and a greenfield rewrite before choosing an architecture.
- Confirm `Win+H` as the default and choose conflict/remapping UX.
- Set supported Windows versions, architectures, and elevated-target policy.
- Choose the UI framework.
- Define microphone selection, permission UX, silence detection, cancellation, and stop conditions.
- Choose final-only versus incremental transcription and correction behavior.
- Define focus-target timing.
- Choose supported languages, default model, model selection, and update policy.
- Define close-button behavior, launch-at-login, and tray notifications.
- Set measurable latency, CPU, and memory targets.
- Choose proxy/retry behavior and the source of trusted model metadata.

## Evidence Provenance

- Newer tree: `C:\Users\maxeo\Programming\wh`, local `main` at `2fa091d8bd39398d85190405d07d0c6969f20ac3` dated 2025-09-20, matching its recorded `origin/main`.
- Newer uncommitted work: native-library search and single-file packaging-path fixes in `ui/WH/NativeBootstrap.cs` and `ui/WH/WH.csproj`.
- Older tree: `C:\Users\maxeo\Programming\wh1`, local `main` at `23dfde9ec2042dcdaabe97032c9b1819cfdef54c` dated 2025-09-13, two commits ahead of its stale recorded `origin/main`.
- Older uncommitted work: nine modified implementation files plus the untracked `.kiro/specs/single-exe-ux-overhaul` requirements, design, and task documents.
- The newer tree's `docs/VISION.md` explicitly claimed authority, so it takes precedence over prototype behavior and conflicting older drafts.
- The older `.kiro` checklist left final workflow validation incomplete; its implementation claims were treated as intent, not proof.
- Historical engine: `whisper.cpp` v1.5.4-era source, MIT licensed.
- Historical model evidence: `ggml-tiny.en.bin`, 77,704,715 bytes, SHA-256 `921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f`.
- Historical test fixture: `hello.wav`, 418,642 bytes, SHA-256 `CE07C361A05DA3DC4CC1F955C229F59BCBE6C9120936E32C20EFF3FFC6B00384`.

The prototype source trees may be deleted after this document is copied into the migration keep state and its SHA-256 hash is verified.
