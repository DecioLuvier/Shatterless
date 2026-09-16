# Determinism & Netcode

*2026-09-02.*

ShatterLess is **P2P deterministic lockstep with rollback** (`netfox` +
Rapier3D). Co-op is a core design pillar, so **every gameplay change is a
netcode change**. If two peers simulate the same tick from the same inputs and
get different state, the game desyncs.

Reference pattern: `../skills/godot-multiplayer-networking/SKILL.md`,
`../skills/godot-adapt-single-to-multiplayer/SKILL.md`.

## The rules

1. **Simulation runs on the network tick, not the frame.** Gameplay logic
   belongs in `_rollback_tick(delta, tick, is_fresh)`, called by a
   `RollbackSynchronizer` node on the entity's root, **not** in `_process` or
   raw `_physics_process`. State that must survive rollback goes in the
   synchronizer's `state_properties`; input goes in `input_properties`.
   `_process` is for view-only cosmetics (viewmodel sway, camera bob, muzzle
   flash fade).

2. **No wall-clock time.** Banned in simulation code:
   - `get_tree().create_timer(...)`
   - `Time.get_ticks_msec()` / `get_ticks_usec()` / `OS.get_system_time_*`
   - `Tween` / `create_tween()` for anything that affects gameplay state
   - `await` on frame/timer signals inside simulation
   Use tick counters instead (`_tick += 1`, compare against a deadline in
   ticks).

3. **No un-seeded randomness.** Banned: `randf()`, `randi()`, `randf_range()`,
   `randomize()`. Use a seeded `RandomNumberGenerator` whose `seed` and
   `state` are listed in the entity's `RollbackSynchronizer.state_properties`
   so rollback saves/restores it like any other state.

4. **All gameplay state must be saved/restored.** Anything a rollback needs to
   rewind — positions, velocities, health, cooldowns (as tick deadlines), RNG
   state, ammo, inventory slots — must be listed in
   `RollbackSynchronizer.state_properties`. State the synchronizer can't see
   = desync on rollback.

5. **Input is polled only on fresh authority ticks.** Inside `_rollback_tick`,
   read `Input.is_action_pressed(...)` only when
   `is_multiplayer_authority()` and `is_fresh` is true, and write the result
   into a property listed in `RollbackSynchronizer.input_properties`. On
   replayed ticks (`is_fresh == false`) the stored input is reused instead of
   re-polling.

6. **Physics is Rapier, and it's deterministic — keep it that way.** Don't mix
   in Godot-Physics nodes for gameplay collision. Fixed tick delta only; never
   feed `delta` from `_process`.

7. **Floats:** same order of operations on every peer. No platform-specific
   fast-math paths, no `is_equal_approx` gates that can diverge.

## `netfox` autoloads and nodes

- `NetworkTime` — owns tick advance / tickrate.
- `NetworkTimeSynchronizer` — syncs the clock across peers.
- `NetworkRollback` — drives rollback replay (`NetworkRollback.tick`, history depth).
- `NetworkEvents` — tick/rollback lifecycle signals.
- `RollbackSynchronizer` (per-entity node, not an autoload) — declares
  `state_properties` / `input_properties` and calls `_rollback_tick` on the
  entity. New networked entities add one of these; don't reach around it to
  send state manually.

## Known violations in the current debug code

`player/player.gd`, `weapons/bullet.gd`, `world/destructible_target.gd` were
written as a **single-player debug sandbox** and are **not rollback-safe yet**.
Before any of this becomes real co-op gameplay it must be ported:

| Location | Non-deterministic construct | Fix |
|---|---|---|
| ~~`player.gd` `_physics_process`~~ | ~~movement driven by engine `delta` + raw `Input`~~ | **Done:** movement moved to `_rollback_tick` via a `RollbackSynchronizer` + `PlayerInput` node (`player/player_input.gd`). Camera look stays frame-driven (view). |
| ~~static `Player` in `TestArena.tscn`~~ | ~~single hardcoded instance, no per-peer spawn~~ | **Done:** `world/TestArena.tscn` uses `player/player_spawner.gd` (`PlayerSpawner`), one avatar per peer via `NetworkEvents`, falls back to a single local avatar with no session running. Body state authority = server (1), input authority = owning peer, `Player.set_local_view()` gates camera/HUD/mouse-capture to the owning machine only. |
| ~~`player.gd` `_fire` / `_start_reload` / `_finish_reload`~~ | ~~ammo/reload not networked, `RELOAD_DURATION` in seconds~~ | **Done:** `_mag`/`_reserve`/`_reloading`/`_reload_deadline_tick` are in `state_properties`; `fire_pressed`/`reload_pressed` are input properties; reload deadline is a tick count (`_reload_ticks`, derived from `NetworkTime.tickrate` once in `_ready`, not wall-clock). |
| `player.gd` `_muzzle_fx` / `_push_click` / `_push_gunshot` | `randf()`, `randf_range()` | Not a desync risk as written: gated behind `is_fresh` in `_fire`/`_finish_reload`, so they never re-run on rollback replay. View/audio only — they don't touch `state_properties`. |
| `player.gd` `_warmup` / `call_deferred` / `await process_frame` | frame-timed | keep as a one-shot cosmetic warmup only; must not gate simulation |
| ~~`bullet.gd`~~ | ~~`create_timer(LIFETIME)`, movement on `_physics_process` delta, `body_entered` signal~~ | **Done:** own `RollbackSynchronizer` (`:global_position`, `:_direction`, `:_ticks_left`, `:_dead`); moves and counts down lifetime in `_rollback_tick`; hit detection polls `get_overlapping_bodies()` instead of the signal; `_rollback_spawn`/`_rollback_despawn` hide/disable instead of `queue_free()` mid-rollback. Cross-peer replication needs no `MultiplayerSpawner`: `fire_pressed` is a broadcast input property, so every peer independently simulates the same shot on the same tick and spawns its own local bullet instance — consistent as long as the firing `Player`'s input is replicated (see spawner row above). |
| ~~`destructible_target.gd`~~ | ~~`queue_free()` on destroy, unnetworked `_health`, `print`~~ | **Done:** own `RollbackSynchronizer` (`:_health`, `:_dead`); destruction goes through `_rollback_despawn`/`_rollback_spawn` instead of `queue_free()`; `take_damage()` is called from the hitting node's tick and calls `NetworkRollback.mutate(self)` (see "Modifying objects during rollback" in the netfox docs) since the change didn't originate from `_rollback_tick`; the `create_tween()` flash is view-only and gated on the caller's `is_fresh`; `print` removed. |

Treat the split as: **networked simulation** (tick, saved, deterministic) vs
**local view** (frame, disposable, may use tweens/random/`Input`).
