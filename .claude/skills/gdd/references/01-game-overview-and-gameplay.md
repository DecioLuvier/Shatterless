# Game Overview & Gameplay

*Source note dated 2026-08-19. Translated from the original Portuguese design notes.*

## Project Overview

- **Game name:** ShatterLess
- **Inspirations:** Lethal Company, Quake, Doors (Roblox)
- **Lore:** In an apocalyptic universe, time travelers spread a virus that
  corrupted parallel realities. The few survivors use time machines to delay
  the destruction. The virus takes a different form in each reality (aliens,
  vampires, etc.), but is always focused on the extinction of all life.
- **Protagonists:** Disposable criminals serving a sentence on the last
  living version of Earth. Declared dead the moment their sentence begins,
  their objective is to collect genetic material from the virus by exploring
  corrupted realities.

## Gameplay

### Room structure

Linear progression toward a checkpoint through numbered rooms. The intent is
to use free asset packs for the scenery: squeeze the maximum number of
elements out of a bundle and build pre-made rooms, and in the end generate a
procedural layout based on a given bundle (Doors-style).

### Inventory management

Limited inventory, 4 slots by default. The intent is that players must
coordinate as a team and split into roles — mechanics should reward doing
so. Initial ideas:

#### Shooter style

- **Ammo Extender:** Takes 1 inventory slot. If the player has a firearm in
  their inventory, it unlocks 3 extra slots reserved for carrying ammo.
- **Compact Laser Sight:** Takes 1 inventory slot. If the player has a
  firearm, it drastically improves accuracy without aiming (hip-fire).
- **Attachable Suppressor:** Takes 1 inventory slot. If the player has a
  firearm, it muffles the shot sound so gunfire no longer draws entities
  from neighboring rooms.

#### Collector style

- **Foldable Cargo Bag:** Takes 1 slot. When activated, it becomes an
  external box with 4 extra slots. Carrying it requires holding it with both
  hands, which prevents simultaneous use of weapons or flashlights.
- **RC Collection Car:** Takes 1 inventory slot. A remote-controlled car
  with its own camera and 2 cargo slots. The player can hide somewhere safe
  and drive it into narrow ducts or dangerous rooms to grab DNA and bring it
  back.
- **Scanner Helmet:** Takes 2 inventory slots. Reveals the silhouette and
  glowing outline of DNA samples and equipment through walls, letting the
  player quickly locate valuable hidden resources in neighboring rooms
  without searching in the dark.

#### Support style

- **Environmental Purifier:** Takes 1 inventory slot. A disposable device
  that neutralizes acid pools, toxic waste, or harmful substances on the
  room floor, turning the dangerous area into clean water and opening a safe
  path for the team.
- **Precision UV Laser:** Takes 1 inventory slot. Emits a focused
  high-intensity beam. Requires keeping the aim **continuously fixed** on
  the entity's weak point: while the laser stays locked on the exact spot,
  the creature remains fully blind and paralyzed, but the effect stops the
  instant the beam moves away.
- **Autonomous Lighting Drone:** Takes 2 inventory slots. While the drone is
  in the inventory, it automatically lights up entire rooms.

#### General

- **Standard Flashlight:** Takes 1 inventory slot. Basic long-range
  directional light source. Lets the player see in total darkness, but must
  be held in hand or kept active in the inventory.
- **Emergency Defibrillator:** Takes 2 inventory slots. Instantly revives a
  downed ally in the middle of combat, bringing them back with partial
  health.
- **Electronic Decoy:** Takes 1 inventory slot. A throwable device that
  emits a loud noise and flashing lights when it hits the ground, diverting
  entities' attention to the impact point for a few seconds.
- **Adrenaline Injection:** Takes 1 inventory slot. Single-use consumable
  that instantly restores stamina and grants a temporary running-speed boost
  to escape critical situations.
- **First Aid Kit:** Takes 1 inventory slot. Medical consumable used to heal
  wounds and restore health for the player or a teammate.
- **Portable Motion Sensor:** Takes 1 inventory slot. A small handheld radar
  that emits audio pings indicating the proximity and direction of living
  creatures in adjacent rooms.

### Entities

Enemies with specific behaviors; players need to understand each one and
devise strategies. The intent is that every enemy fits the bundle and is fun
and unique (Lethal Company-style).
