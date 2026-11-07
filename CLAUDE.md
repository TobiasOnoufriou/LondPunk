# Project Overview
- **Engine**: Godot 4.7 (GDScript)
- **Genre**: Top-down isometric CRPG (Computer Role-Playing Game)
- **Camera**: Free-Moving Camera with Tilt, Rotate and zoome across the environment using your mouse or controller.

# Build & Run Commands
- Run project: `godot --path .` (or `dotnet run` for C#)
- Run tests: `gut.sh` (or your test runner command)

# Architecture & Design Patterns
- **Nodes over Inheritance**: Prefer composition with Node scenes (e.g., `HitboxComponent`, `HealthComponent`) rather than deep class inheritance.
- **Signals for Decoupling**: UI must never directly call Player/Enemy nodes; use global EventBus singletons (`res://scripts/event_bus.gd`).
- **Autoloads**: Keep global singletons strictly limited to: `EventBus`, `SoundManager`, `SaveManager`.
  - Addon-provided exception: `DialogueManager` (required by `addons/dialogue_manager`).

# Coding Standards (GDScript / C#)
- **Indentation**: 4 spaces (no tabs).
- **Naming Conventions**:
  - Node scenes: `PascalCase` (e.g. `Player.tscn`, `EnemySpawner.tscn`)
  - Scripts: `snake_case.gd` (e.g. `player_controller.gd`)
  - Constants: `UPPER_SNAKE_CASE` (e.g. `MAX_SPEED = 300`)
- **Strong Typing**: Always declare variable types.
  - *Bad*: `var speed = 100`
  - *Good*: `var speed: float = 100.0`
- **Comments**: Use docstrings (`##`) for public methods and signals.

# Folder Structure
res/
├── scenes/       # All .tscn scene files
├── scripts/      # All .gd logic files
├── assets/       # Sprites, audio, fonts (sub-divided by type)
├── levels/       # Tilemaps and level layout scenes
└── data/         # .tres data resources (abilities, status effects, combatant stats)

# Important Rules for Claude
- Do NOT use `get_node()` with long hardcoded paths like `../../Player/Sprite2D`. Use `@export` node references or signals.
- When creating a new system, check `res://scripts/event_bus.gd` first to see if an event already exists.
- Always clean up `Tween` objects and free timers properly to avoid memory leaks.
