# Architecture & Stack

*Facts verified against the repo on 2026-09-02.*

## Engine

- **Godot 4.7**, Forward Plus renderer.
- Windows rendering driver forced to **D3D12** (`rendering/rendering_device/driver.windows="d3d12"`).
- Main scene: `res://world/TestArena.tscn` (a debug arena, not a real level).

## Language — GDScript is the working language today

- The GDD lists "Godot C#" as the stack, and the project *is* a .NET project
  (`Shatterless.csproj`, `Shatterless.sln`, `config/features` includes `"C#"`,
  `assembly_name="Shatterless"`).
- **But every gameplay script in the repo is GDScript** (`player/player.gd`,
  `weapons/bullet.gd`, `world/destructible_target.gd`). There is no `.cs` file.
- **Decision (2026-09-02):** write new gameplay code in **GDScript** to match
  what exists. Do not introduce C# scripts without an explicit call from the
  user — mixing the two adds a marshalling boundary and complicates the
  rollback addon integration. The .NET project files stay (harmless, and the
  editor expects them once `"C#"` is in `config/features`).
- If the project ever commits to C#, that is a deliberate port, tracked as its
  own task, not a per-file drift.

## Addons (vendored, git-ignored)

`.gitignore` excludes `addons/*/*` (only `.gitkeep` is kept), so addons are
**not committed** — each dev restores them locally.

| Addon | Role | Notes |
|---|---|---|
| `godot-rollback-netcode` | P2P deterministic lockstep + rollback | Editor plugin enabled. Provides the `SyncManager` autoload. See `02-determinism-and-netcode.md`. |
| `godot-rapier3d` | Deterministic 3D physics | `project.godot` sets `3d/physics_engine="Rapier3D"`. Use Rapier bodies/queries, not the Godot-Physics defaults. |

## Autoloads

| Name | Source | Purpose |
|---|---|---|
| `SyncManager` | `uid://dpiim8is0veq7` (rollback-netcode addon) | Owns the network tick, rollback, input capture. All simulation is driven from its callbacks, **not** `_process`/`_physics_process` wall-clock. |

Add new autoloads sparingly and document them here (see
`../skills/godot-autoload-architecture/SKILL.md` for the pattern).

## Repo layout

Feature-first folders at the repo root, each holding its scene + script(s) +
`.uid` files together:

```
player/    player.tscn + player.gd
weapons/   bullet.tscn + bullet.gd
world/     TestArena.tscn, destructible_target.tscn + .gd
addons/    godot-rapier3d, godot-rollback-netcode   (git-ignored)
.claude/   agents/, plugins/  (tooling, not shipped)
```

Keep this shape: a new system gets its own root folder with the scene and
script side by side. No central `scripts/` or `scenes/` dump.

## Conventions

- **Typed GDScript, tabs, `##` header comment** on every script. Private
  members prefixed `_`; the unprefixed surface is the public API
  (`launch()`, `take_damage()`). Tuning values as `const` SCREAMING_SNAKE_CASE
  at the top; `@export` for scene-wired deps, `@onready` for child refs.
- **Files `snake_case`, nodes `PascalCase`.** Existing exception:
  `world/TestArena.tscn` — leave it, new scenes use `snake_case`.
- **Cross-node contact via groups + duck typing:** `add_to_group("player")`,
  `body.is_in_group("player")`, `body.has_method("take_damage")`. A
  "damageable" is anything with `take_damage(amount: int) -> void`.
  `class_name` only when another script references the type.
- Prefer `push_warning` / `push_error` over silent failure — the MCP verify
  step treats them as failures on purpose.
- **Synthesise simple SFX/placeholders in code** instead of shipping a file
  (`player.gd` builds its gunshot with an `AudioStreamGenerator`). Real
  assets: free only — Mixamo / godotshaders.com / elbolilloduro.itch.io,
  kept inside their feature folder.
- **Promoting sandbox code to a real system:** port to rollback-safe
  simulation (`02-determinism-and-netcode.md`), split networked state from
  local view, drop `print` debug lines, move it out of `world/` into its own
  feature folder.

## Build / run

- Open in the Godot 4.7 editor; it triggers the .NET build via the csproj.
- The `developer` agent verifies changes through the **godot MCP**
  (`run_project` → `get_debug_output` → `send_game_command` →
  `capture_screenshot` → `stop_project`), never by assertion that it "should
  work". See `../../developer.md`.
- `.gitignore` already covers `.godot/`, `bin/`, `obj/`, `*.pck`, exports.
