# OpenWhispr Reference Notes

This repository uses an Electron + Node.js stack with a Python bridge for Whisper.
The following behaviors are useful references for wh:

- `whisper_bridge.py` wraps the Python `whisper` package and exposes modes for
  transcription and model downloads. Downloads stream progress as JSON lines so
  the UI can report percentage and speed.
- A `WhisperManager` class in `src/helpers/whisper.js` spawns the Python script
  and parses `PROGRESS:` markers from stderr to emit progress updates and allow
  cancellation.
- Models are stored under the user's cache directory and checked for presence
  before each transcription. The manager exposes helper methods like
  `checkModelStatus`, `downloadWhisperModel`, and `deleteWhisperModel` through
  Electron IPC.
- The default global hotkey is a single backtick key. Hotkey registration and
  updates are handled via IPC so the React renderer can configure it.

These patterns inform wh's model management and hotkey services while
keeping the implementation fully native.
