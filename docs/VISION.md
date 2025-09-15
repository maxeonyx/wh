# VISION.md (Requirements and Constraints)

This document is authoritative. Implementations must conform. Any change requires explicit approval.

## Product Vision

A tiny Windows HUD ("wh - Whisper on Windows HUD") that enables local speech-to-text using Whisper, closely mimicking Windows built-in dictation UX while keeping transcription on-device. The HUD injects transcribed text into whichever text field is currently focused.

## UX Fundamentals

- Form: Minimal pop-up HUD centered on the monitor under the current cursor.
- State: Recording on by default at launch; user can toggle off.
- Affordances: Single prominent Record button (blue). Minimal or no other controls.
- Feedback: Chime when recording turns on.
- Look: WPF with Windows 11 styling, dark mode.
- Presence: App resides in the system tray to minimize startup time; buffer resets on minimize-to-tray and on reopen.

## Core Behavior

- ASR: Use Whisper (local model).
- Text injection: Transcribed text goes to the currently focused control (similar to Windows dictation).

## Packaging and Distribution

- Single-file download: Distribute as one `.exe` (no sidecar assets; include all UI files and all native libraries in the executable).
- Model management: Download the Whisper model on first startup (the model is not bundled inside the downloaded `.exe`).

