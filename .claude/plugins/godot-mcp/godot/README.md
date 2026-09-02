# godot (MCP plugin)

Project-local Claude Code plugin for the ShatterLess repo. It bundles a Godot MCP
server and registers it automatically — no separate `claude mcp add` step.

## What's inside

- **MCP server** at `server/` — a fork of
  [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) (MIT).
  Registered via `.mcp.json` in this plugin, so enabling the plugin is enough.
- **Two extra tools** on top of the upstream set:
  - `capture_screenshot` — boots the project's main scene in a real window,
    renders a few frames, and returns a PNG of the running game.
  - `send_game_command` — boots the main scene and evaluates a GDScript
    expression against it (`tree`, `root`, `scene` are in scope), returning the
    printed output and the result.

Both extra tools run through `server/src/scripts/godot_runtime.gd`, which is
passed to Godot with `--script`. **Nothing is copied into the Godot project** —
no autoload, no `addons/` entry, no `.gd` files added to `res://`. Each call
boots a fresh, stateless instance.

## Tool list

| Tool | Purpose |
|---|---|
| `launch_editor` | Open the Godot editor for a project |
| `run_project` / `get_debug_output` / `stop_project` | Run in debug mode, stream stdout/stderr |
| `get_godot_version` / `list_projects` / `get_project_info` | Environment + project metadata |
| `create_scene` / `add_node` / `load_sprite` / `save_scene` | Headless scene editing |
| `export_mesh_library` | Export a scene as a `MeshLibrary` |
| `get_uid` / `update_project_uids` | Godot 4.4+ UID helpers |
| `capture_screenshot` | **new** — PNG of the running game |
| `send_game_command` | **new** — evaluate GDScript against the running scene |

### `capture_screenshot`

| Param | Req | Notes |
|---|---|---|
| `projectPath` | yes | Godot project directory |
| `scenePath` | no | `res://` scene to boot instead of the configured main scene |
| `outputPath` | no | absolute PNG path (defaults to a temp file) |
| `waitFrames` | no | frames to render before capturing (default 45) |

### `send_game_command`

| Param | Req | Notes |
|---|---|---|
| `projectPath` | yes | Godot project directory |
| `command` | yes | GDScript expression; scope: `tree` (SceneTree), `root` (Window), `scene` (main scene root) |
| `scenePath` | no | scene to boot instead of the main scene |
| `waitFrames` | no | frames to render before running (default 45) |

Examples:

```
scene.get_node("Player").global_position
scene.get_tree().get_nodes_in_group("enemies").size()
scene.some_method(1, 2)
```

## Config

`.mcp.json` pins `GODOT_PATH` to the mono build on this machine:

```
C:\Users\luvier\Documents\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe
```

Edit that file to point at a different Godot binary. Set `DEBUG` to `true` there
for verbose server logging on stderr.

## Rebuilding the server

```
cd server
npm install
npm run build      # tsc -> build/, then copies the .gd helpers into build/scripts
```

`build/` is committed so the plugin works without a build step; rerun the above
after editing anything under `server/src/`.
