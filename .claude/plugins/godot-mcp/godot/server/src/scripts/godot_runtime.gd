#!/usr/bin/env -S godot --script
extends SceneTree

# Runtime harness for the Godot MCP plugin.
#
# Unlike godot_operations.gd (headless scene editing), this script actually BOOTS
# the project's main scene in a real window, lets it run for a few frames, then
# performs one of:
#   - "screenshot": grab the rendered frame and save it as a PNG
#   - "command":    evaluate a GDScript expression against the live main scene
#
# It is passed to Godot with `--script` and never copied into the project, so the
# game stays clean (no autoload, no addon, no .gd files added to res://).
#
# Arg convention matches godot_operations.gd:
#   godot --path <project> --script godot_runtime.gd <operation> <json_params>

var debug_mode := false
var op := ""
var params := {}
var scene_instance: Node = null
var frames_waited := 0
var target_frames := 45
var done := false

func _initialize() -> void:
	var args := OS.get_cmdline_args()
	debug_mode = "--debug-godot" in args

	var script_index := args.find("--script")
	if script_index == -1 or args.size() <= script_index + 3:
		_err("Usage: godot --path <project> --script godot_runtime.gd <operation> <json_params>")
		quit(1)
		return

	op = args[script_index + 2]
	var params_json: String = args[script_index + 3]

	var json := JSON.new()
	if json.parse(params_json) != OK:
		_err("Failed to parse JSON params: " + json.get_error_message())
		quit(1)
		return
	params = json.get_data()
	if typeof(params) != TYPE_DICTIONARY:
		params = {}

	if params.has("wait_frames"):
		target_frames = max(1, int(params["wait_frames"]))

	var main_path := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	if params.has("scene_path") and String(params["scene_path"]) != "":
		main_path = String(params["scene_path"])

	if main_path == "" or not ResourceLoader.exists(main_path):
		_err("No valid scene to run (main_scene='" + main_path + "'). Set a main scene or pass scene_path.")
		quit(1)
		return

	var packed := load(main_path)
	if packed == null:
		_err("Failed to load scene: " + main_path)
		quit(1)
		return

	scene_instance = packed.instantiate()
	get_root().add_child(scene_instance)
	_info("Booted scene: " + main_path)


# SceneTree/MainLoop._process: return TRUE ends the main loop, FALSE keeps it running.
func _process(_delta: float) -> bool:
	if done:
		return true
	frames_waited += 1
	if frames_waited < target_frames:
		return false

	match op:
		"screenshot":
			_do_screenshot()
		"command":
			_do_command()
		_:
			_err("Unknown runtime operation: " + op)

	done = true
	quit()
	return true


func _do_screenshot() -> void:
	var out_path := String(params.get("output_path", ""))
	if out_path == "":
		_err("screenshot: output_path is required")
		return
	var img: Image = get_root().get_texture().get_image()
	if img == null:
		_err("screenshot: could not read viewport texture")
		return
	var e := img.save_png(out_path)
	if e != OK:
		_err("screenshot: save_png failed (err %d) for %s" % [e, out_path])
		return
	print("SCREENSHOT_SAVED:" + out_path)


func _do_command() -> void:
	var code := String(params.get("command", ""))
	if code == "":
		_err("command: 'command' string is required")
		return
	# Exposed names inside the expression: tree, root, scene
	var expr := Expression.new()
	if expr.parse(code, ["tree", "root", "scene"]) != OK:
		_err("command: parse error: " + expr.get_error_text())
		return
	var result: Variant = expr.execute([self, get_root(), scene_instance], scene_instance, true, true)
	if expr.has_execute_failed():
		_err("command: execute failed: " + expr.get_error_text())
		return
	print("COMMAND_RESULT:" + var_to_str(result))


func _info(m: String) -> void:
	print("[INFO] " + m)

func _err(m: String) -> void:
	printerr("[ERROR] " + m)
