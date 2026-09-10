# Determinism & Netcode

*2026-09-02.*

ShatterLess is **P2P deterministic lockstep with rollback** (`godot-rollback-netcode`
+ Rapier3D). Co-op is a core design pillar, so **every gameplay change is a
netcode change**. If two peers simulate the same tick from the same inputs and
get different state, the game desyncs.

Reference pattern: `../skills/godot-multiplayer-networking/SKILL.md`,
`../skills/godot-adapt-single-to-multiplayer/SKILL.md`.

## The rules

1. **Simulation runs on the network tick, not the frame.** Gameplay logic
   belongs in `_network_process(input)` / the rollback callbacks
   (`_save_state`, `_load_state`, `_get_local_input`, `_network_spawn`, …),
   **not** in `_process` or raw `_physics_process`. `_process` is for
   view-only cosmetics (viewmodel sway, camera bob, muzzle flash fade).

2. **No wall-clock time.** Banned in simulation code:
   - `get_tree().create_timer(...)`
   - `Time.get_ticks_msec()` / `get_ticks_usec()` / `OS.get_system_time_*`
   - `Tween` / `create_tween()` for anything that affects gameplay state
   - `await` on frame/timer signals inside simulation
   Use tick counters instead (`_tick += 1`, compare against a deadline in
   ticks).

3. **No un-seeded randomness.** Banned: `randf()`, `randi()`, `randf_range()`,
   `randomize()`. Use a rollback-safe seeded RNG that is saved and restored
   with game state (the addon's `SyncManager.get_rng()` / a `RandomNumberGenerator`
   whose `seed` and `state` are part of `_save_state`).

4. **All gameplay state must be saved/restored.** Anything a rollback needs to
   rewind goes into `_save_state()` and comes back in `_load_state()`:
   positions, velocities, health, cooldowns (as tick deadlines), RNG state,
   ammo, inventory slots. State the addon can't see = desync on rollback.

5. **Input comes from the addon, not `Input`.** Read actions through
   `_get_local_input()` and act on the `input` dict passed to
   `_network_process`. Direct `Input.is_action_pressed(...)` in simulation is
   only acceptable for view code.

6. **Physics is Rapier, and it's deterministic — keep it that way.** Don't mix
   in Godot-Physics nodes for gameplay collision. Fixed tick delta only; never
   feed `delta` from `_process`.

7. **Floats:** same order of operations on every peer. No platform-specific
   fast-math paths, no `is_equal_approx` gates that can diverge.

## `SyncManager`

Autoload from the addon (`uid://dpiim8is0veq7`). Owns tick advance, input
broadcast, rollback, and (in debug) the `sync_debug` input action bound to a
key. New networked entities register with it and implement the rollback
callbacks. Don't reach around it to send state manually.

## Known violations in the current debug code

`player/player.gd`, `weapons/bullet.gd`, `world/destructible_target.gd` were
written as a **single-player debug sandbox** and are **not rollback-safe yet**.
Before any of this becomes real co-op gameplay it must be ported:

| Location | Non-deterministic construct | Fix |
|---|---|---|
| `player.gd` `_physics_process` | movement driven by engine `delta` + raw `Input` | move to `_network_process`, use fixed tick delta + `input` dict |
| `player.gd` `_fire` / `_muzzle_fx` | `randf()`, `randf_range()`, `_flash_time` in seconds | seeded RNG in saved state; cooldown as tick deadline. Muzzle *visual* can stay in `_process`. |
| `player.gd` `_warmup` / `call_deferred` / `await process_frame` | frame-timed | keep as a one-shot cosmetic warmup only; must not gate simulation |
| `bullet.gd` | `create_timer(LIFETIME)`, movement on `_physics_process` delta | spawn via `_network_spawn`, lifetime as tick count, move in `_network_process`, state saved |
| `destructible_target.gd` | `create_tween()` flash, `print` on destroy | tween is view-only (OK if health/despawn are networked); destruction must be a networked state change |

Treat the split as: **networked simulation** (tick, saved, deterministic) vs
**local view** (frame, disposable, may use tweens/random/`Input`).
