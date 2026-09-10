# Technology & Design Pillars

*Source note dated 2026-08-26. Translated from the original Portuguese design notes.*

## Design Pillars

- **3D perspective:** Avoids the need for advanced pixel art while still
  achieving a strong visual appeal.
- **Co-op multiplayer:** Focus on cooperative matches to raise the fun
  factor — Backrooms-style example.
- **Arcade style:** Less focus on story, more focus on being FUN and CASUAL.
- **Procedural roguelike:** Maximum content reuse so the game does not depend
  on large hand-built maps.
- **High difficulty:** Player retention driven by challenge.
- **Asset strategy:** Use of free third-party resources.
  - Animations: Mixamo.com
  - Aesthetic: godotshaders.com (PSX/CRT filters and Quake-style look)
  - Assets: elbolilloduro.itch.io

## Technology Stack

- **Godot C#:** Main game engine.
- **Godot Rollback Netcode:** P2P deterministic lockstep networking.
- **Rapier:** Deterministic physics.
- **Blender:** Level design and map construction.
- **Wave Function Collapse:** Procedural generation algorithm.

## Notes for implementation work

- Networking model is deterministic lockstep with rollback — gameplay code
  must stay deterministic (fixed tick, no wall-clock, no un-seeded RNG in
  simulation). See `addons/godot-rollback-netcode` and the `SyncManager`
  autoload.
- Physics engine is Rapier3D (already set in `project.godot`).
- Prefer the repo's `godot-*` skills for engine-specific patterns
  (procedural generation / WFC, multiplayer, physics-3d, genre-horror,
  inventory-system, etc.).
