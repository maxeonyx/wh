# wh Plan

## Architecture
- **UI (`ui/`)**: WPF frontend providing the HUD, hotkey registration, audio capture, and model management.
- **whisper.cpp (`engine/`)**: built from source into a native library during `build.ps1`.
- The native library is marked as a `<NativeLibrary>` in `wh.csproj` so `dotnet publish` embeds it into the single-file executable.
- `EngineService` invokes the native functions for model loading and transcription.
- Models download on demand to `%LOCALAPPDATA%/wh/models`.

## Toolchain
- `scripts/bootstrap.ps1` downloads portable CMake, Ninja, and the .NET SDK into `.toolchain/` and fetches whisper.cpp.
- `scripts/build.ps1` builds the native code and publishes a self-contained `wh.exe` to `dist/`.
- `scripts/clean-toolchain.ps1` removes the `.toolchain/` directory.

## Hotkey
- Default global hotkey is `Win+H`.
- `scripts/hotkey-helper.ps1` guides remapping via PowerToys when necessary.

## References
- Review `docs/open-whispr-notes.md` and the upstream [OpenWhispr](https://github.com/HeroTools/open-whispr) project for inspiration.
