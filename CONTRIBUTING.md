# Contributing

Thanks for taking a look at Cervantes Tactics.

This is an early Godot 4 prototype, so small and focused contributions are the most useful.

## Helpful Contributions

- Bug reports with clear reproduction steps.
- Playtest notes about readability, turn flow, UI clarity, or confusing rules.
- Small Godot 4 compatibility fixes.
- Refactors that reduce complexity without changing gameplay.
- Smoke-test improvements.
- Documentation fixes that help new contributors run the project.

## Before Opening a Pull Request

1. Keep the change focused.
2. Avoid adding private production material, pitch files, soundtrack files, generated exports, or internal handoff notes.
3. Preserve the licensing split described in `CONTENT_LICENSE.md` and `ASSET_LICENSES.md`.
4. If you change gameplay behavior, describe what changed and how you tested it.

## Local Validation

Use Godot 4.6 or newer.

```bash
godot --headless --path /path/to/cervantes-tactics-godot --import
godot --headless --path /path/to/cervantes-tactics-godot --scene res://scenes/MainMenu.tscn --quit-after 5
godot --headless --path /path/to/cervantes-tactics-godot --scene res://scenes/Battle3D.tscn --quit-after 5
```
