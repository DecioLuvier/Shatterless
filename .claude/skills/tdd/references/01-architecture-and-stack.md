# Architecture & Stack

*Facts verified against the repo on 2026-09-02.*

## Engine

- **Godot 4.7**, Forward Plus renderer.
- Windows rendering driver forced to **D3D12** (`rendering/rendering_device/driver.windows="d3d12"`).
- Main scene: `res://source/world/TestArena.tscn` (a debug arena, not a real level).

## Language — GDScript is the working language today

- The GDD lists "Godot C#" as the stack, and the project *is* a .NET project
  (`Shatterless.csproj`, `Shatterless.sln`, `config/features` includes `"C#"`,
  `assembly_name="Shatterless"`).
- **But every gameplay script in the repo is GDScript**
  (`source/player/player.gd`, `source/weapons/bullet.gd`,
  `source/world/destructible_target.gd`). There is no `.cs` file.
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
| `netfox` | P2P deterministic lockstep + rollback | Editor plugin enabled. Provides the `NetworkTime`, `NetworkTimeSynchronizer`, `NetworkRollback`, `NetworkEvents` autoloads and the `RollbackSynchronizer` node. See `02-determinism-and-netcode.md`. |
| `godot-rapier3d` | Deterministic 3D physics | `project.godot` sets `3d/physics_engine="Rapier3D"`. Use Rapier bodies/queries, not the Godot-Physics defaults. |

## Autoloads

| Name | Source | Purpose |
|---|---|---|
| `NetworkTime` | `res://addons/netfox/network-time.gd` (netfox addon) | Owns the network tick / tickrate. |
| `NetworkTimeSynchronizer` | `res://addons/netfox/network-time-synchronizer.gd` (netfox addon) | Syncs tick/clock across peers. |
| `NetworkRollback` | `res://addons/netfox/rollback/network-rollback.gd` (netfox addon) | Drives rollback replay. |
| `NetworkEvents` | `res://addons/netfox/network-events.gd` (netfox addon) | Tick/rollback lifecycle signals. |

Networked entities use a `RollbackSynchronizer` node (`state_properties` /
`input_properties` exported arrays) and implement `_rollback_tick(delta, tick,
is_fresh)`. All simulation is driven from there, **not** `_process`/
`_physics_process` wall-clock.

Add new autoloads sparingly and document them here (see
`../skills/godot-autoload-architecture/SKILL.md` for the pattern).

## Repo layout

Hybrid layout: type-level split at the root for shared/infra concerns,
feature-first folders under `source/` for gameplay, each holding its scene +
script(s) + `.uid` files together:

```
source/
  player/    player.tscn + player.gd + player_input.gd + player_spawner.gd
  weapons/   bullet.tscn + bullet.gd
  world/     TestArena.tscn, destructible_target.tscn + .gd
autoload/    network_bootstrap.gd, network_hud.gd   (our own autoloads only)
ui/          network_menu.tscn + .gd                (reusable UI, not gameplay)
addons/      godot-rapier3d, netfox                  (git-ignored)
.claude/     agents/, plugins/                       (tooling, not shipped)
```

Keep this shape: a new gameplay system gets its own folder under `source/`
with the scene and script side by side. No central `scripts/` or `scenes/`
dump. Only promote something out of `source/` (to `ui/`, `autoload/`) once
it's genuinely shared across more than one feature.

## Conventions

- **Typed GDScript, tabs, no comments.** Names carry the intent; a comment
  is only acceptable for a non-obvious invariant (e.g. why rollback state
  must restore before simulate) — never a restatement of what the code does.
  Private members prefixed `_`; the unprefixed surface is the public API
  (`launch()`, `take_damage()`). Tuning values as `const` SCREAMING_SNAKE_CASE
  at the top; `@export` for scene-wired deps, `@onready` for child refs.
- **Files `snake_case`, nodes `PascalCase`.** Existing exception:
  `source/world/TestArena.tscn` — leave it, new scenes use `snake_case`.
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
  local view, drop `print` debug lines, move it out of `source/world/` into
  its own feature folder under `source/`.

## Build / run

- Open in the Godot 4.7 editor; it triggers the .NET build via the csproj.
- The `developer` agent verifies changes through the **godot MCP**
  (`run_project`, optionally with `instanceId` for a second native instance —
  e.g. netfox host/client → `get_debug_output` → `get_screenshot` →
  `stop_project`), never by assertion that it "should work". No
  input-simulation tools exist (no click/key/gamepad) — verification is
  read-only (logs, errors, screenshots). See `../../developer.md`.
- `.gitignore` already covers `.godot/`, `bin/`, `obj/`, `*.pck`, exports.
