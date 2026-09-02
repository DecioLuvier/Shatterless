# Shatterless

## Patch Notes

Follow `MAJOR.MINOR.PATCH`:

- **MAJOR** – breaking changes.
- **MINOR** – new features, backwards compatible.
- **PATCH** – bug fixes and small tweaks.

## [0.1.0] - 2026-09-02

- Start of version control
- Godot 4.7 project (Forward+, C#, Rapier3D as the 3D physics engine).
- First-person debug player (`player/`): WASD movement, mouse look with pitch clamp, jump, and gravity on a `CharacterBody3D`.
- Weapon viewmodel with animations
- HUD: ammo counter and reload progress bar.
- Bullet projectile (`weapons/`): 
- Destructible target (`world/`): health, hit flash, destroyed at 0 HP.
- Test arena scene (`world/TestArena.tscn`), set as the main scene.
- Input map: `move_*`, `jump`, `fire`, `reload`.
- Addons added, but without use: `godot-rapier3d`, `godot-rollback-netcode`.
- Project icon and license.

## [0.1.1] - 2026-09-02
- bug fix godot mcp for linux
- new patch notes style 