# wh

`wh` is a proposed private, local Windows dictation tool: invoke it while a text field is focused, speak, and insert the locally transcribed result at the caret.

The September 2025 prototype has been intentionally retired. Its useful product requirements, constraints, lessons, and unresolved decisions were extracted into [REQUIREMENTS.md](REQUIREMENTS.md). No current implementation or release is provided by this repository.

## Start Here

Before writing new code, evaluate [cjpais/Handy](https://github.com/cjpais/handy). Handy is an actively developed, offline, open-source dictation application that already works on Windows and is deliberately designed to be forkable.

The preferred order is:

1. Use stock Handy if configuration satisfies the requirements.
2. Maintain a focused Handy fork if only bounded changes are needed.
3. Build `wh` from scratch only if the first two options cannot meet the requirements cleanly.

See [REQUIREMENTS.md](REQUIREMENTS.md) for the complete decision brief and acceptance criteria.
