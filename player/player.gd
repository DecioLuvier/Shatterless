extends CharacterBody3D
## First-person debug player: cylinder body, WASD move, mouse look,
## space to jump, left mouse to fire. The gun is a visible viewmodel
## with idle sway, walk bob and a recoil kick.

const SPEED := 6.0
const JUMP_VELOCITY := 5.0
const MOUSE_SENS := 0.0025
const PITCH_LIMIT := deg_to_rad(85.0)

@export var bullet_scene: PackedScene

const MAG_SIZE := 12
const RESERVE_START := 60
const RESERVE_MAX := 96
const RELOAD_DURATION := 1.7

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _mag := MAG_SIZE
var _reserve := RESERVE_START
var _reloading := false
var _reload_t := 0.0

var _mag_base_pos := Vector3.ZERO
var _mag_base_rot := Vector3.ZERO

var _bob_time := 0.0
var _mouse_delta := Vector2.ZERO
var _sway := Vector3.ZERO
var _recoil := 0.0

var _weapon_base_pos := Vector3.ZERO
var _weapon_base_rot := Vector3.ZERO

var _flash_time := 0.0
var _playback: AudioStreamGeneratorPlayback

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _weapon: Node3D = $Head/Camera3D/WeaponHolder
@onready var _muzzle: Marker3D = $Head/Camera3D/WeaponHolder/Muzzle
@onready var _muzzle_flash: MeshInstance3D = $Head/Camera3D/WeaponHolder/MuzzleFlash
@onready var _flash_light: OmniLight3D = $Head/Camera3D/WeaponHolder/FlashLight
@onready var _gunshot: AudioStreamPlayer3D = $Head/Camera3D/WeaponHolder/GunshotPlayer
@onready var _mag_mesh: MeshInstance3D = $Head/Camera3D/WeaponHolder/MagMesh
@onready var _hud_ammo: Label = $HUD/AmmoLabel
@onready var _hud_bar: ProgressBar = $HUD/ReloadBar


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_weapon_base_pos = _weapon.position
	_weapon_base_rot = _weapon.rotation
	_mag_base_pos = _mag_mesh.position
	_mag_base_rot = _mag_mesh.rotation
	_update_hud()
	_gunshot.play()
	_playback = _gunshot.get_stream_playback()
	call_deferred("_warmup")


## Force one-time shader / physics / audio allocation so the FIRST real
## shot does not hitch.
func _warmup() -> void:
	if bullet_scene != null:
		var b := bullet_scene.instantiate()
		add_child(b)
		b.global_position = _muzzle.global_position
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(b):
			b.queue_free()
	_muzzle_flash.visible = true
	_flash_light.light_energy = 0.01
	_push_gunshot(0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_muzzle_flash.visible = false
	_flash_light.light_energy = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_head.rotate_x(-event.relative.y * MOUSE_SENS)
		_head.rotation.x = clampf(_head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
		_mouse_delta += event.relative
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_fire()
	elif event.is_action_pressed("reload"):
		_start_reload()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED

	move_and_slide()


func _process(delta: float) -> void:
	if _reloading:
		_reload_t += delta / RELOAD_DURATION
		_hud_bar.value = clampf(_reload_t, 0.0, 1.0)
		if _reload_t >= 1.0:
			_finish_reload()
	_animate_weapon(delta)
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash_light.light_energy = lerpf(_flash_light.light_energy, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		if _flash_time <= 0.0:
			_muzzle_flash.visible = false
			_flash_light.light_energy = 0.0


func _animate_weapon(delta: float) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and planar_speed > 0.5

	# Walk bob
	if moving:
		_bob_time += delta * 10.0
	else:
		_bob_time += delta * 2.0
	var bob_amount := 0.02 if moving else 0.004
	var bob := Vector3(
		cos(_bob_time * 0.5) * bob_amount,
		-absf(sin(_bob_time)) * bob_amount,
		0.0
	)

	# Idle / look sway from recent mouse motion
	var target_sway := Vector3(-_mouse_delta.x, _mouse_delta.y, 0.0) * 0.00035
	target_sway.x = clampf(target_sway.x, -0.04, 0.04)
	target_sway.y = clampf(target_sway.y, -0.04, 0.04)
	_sway = _sway.lerp(target_sway, clampf(delta * 12.0, 0.0, 1.0))
	_mouse_delta = Vector2.ZERO

	# Recoil decay
	_recoil = lerpf(_recoil, 0.0, clampf(delta * 9.0, 0.0, 1.0))

	# Reload choreography: dip + roll the weapon toward the player while the
	# magazine drops out, then snaps back in with a chamber kick at the end.
	var reload_pos := Vector3.ZERO
	var reload_rot := Vector3.ZERO
	if _reloading:
		var p := clampf(_reload_t, 0.0, 1.0)
		var dip := sin(clampf(p / 0.92, 0.0, 1.0) * PI)
		reload_pos += Vector3(0.02, -0.085, -0.015) * dip
		reload_rot += Vector3(0.55 * dip, -0.18 * dip, 0.75 * dip)
		var mag_off := smoothstep(0.08, 0.4, p) if p < 0.5 else 1.0 - smoothstep(0.55, 0.88, p)
		_mag_mesh.position = _mag_base_pos + Vector3(0.0, -0.13, 0.0) * mag_off
		_mag_mesh.rotation = _mag_base_rot + Vector3(0.45 * mag_off, 0.0, 0.0)
		if p > 0.9:
			var snap := sin((p - 0.9) / 0.1 * PI)
			reload_pos += Vector3(0.0, 0.0, 0.03) * snap
			reload_rot += Vector3(-0.25 * snap, 0.0, 0.0)
	else:
		_mag_mesh.position = _mag_base_pos
		_mag_mesh.rotation = _mag_base_rot

	_weapon.position = _weapon_base_pos + bob + _sway + Vector3(0.0, 0.0, _recoil * 0.35) + reload_pos
	_weapon.rotation = _weapon_base_rot + Vector3(
		-_sway.y * 6.0 + _recoil * 0.9,
		_sway.x * 6.0,
		_sway.x * 4.0
	) + reload_rot


func _fire() -> void:
	if bullet_scene == null:
		push_warning("Player has no bullet_scene assigned")
		return
	if _reloading:
		return
	if _mag <= 0:
		_push_click()
		_start_reload()
		return
	_mag -= 1
	_update_hud()
	var bullet := bullet_scene.instantiate()
	var container: Node = get_tree().current_scene
	if container == null:
		container = get_parent()
	container.add_child(bullet)
	# Aim: shots follow where the camera looks, never the animated viewmodel.
	var aim_dir := -_camera.global_transform.basis.z
	bullet.global_position = _muzzle.global_position
	bullet.launch(aim_dir)
	_recoil = minf(_recoil + 0.038, 0.08)
	_muzzle_fx()
	if _mag <= 0:
		_start_reload()


func _start_reload() -> void:
	if _reloading:
		return
	if _mag >= MAG_SIZE or _reserve <= 0:
		return
	_reloading = true
	_reload_t = 0.0
	_hud_bar.value = 0.0
	_hud_bar.visible = true
	_update_hud()


func _finish_reload() -> void:
	var need := MAG_SIZE - _mag
	var take := mini(need, _reserve)
	_mag += take
	_reserve -= take
	_reloading = false
	_reload_t = 0.0
	_hud_bar.visible = false
	_mag_mesh.position = _mag_base_pos
	_mag_mesh.rotation = _mag_base_rot
	_push_click()
	_update_hud()


func _update_hud() -> void:
	if _reloading:
		_hud_ammo.text = "RELOADING"
	else:
		_hud_ammo.text = "%d / %d" % [_mag, _reserve]


## Short mechanical click for dry-fire and mag-in, reusing the synth path.
func _push_click() -> void:
	if _playback == null:
		_playback = _gunshot.get_stream_playback()
	if _playback == null:
		return
	var sr := (_gunshot.stream as AudioStreamGenerator).mix_rate
	var dur := 0.05
	var frames := mini(int(sr * dur), _playback.get_frames_available())
	for i in frames:
		var t := float(i) / sr
		var env := pow(1.0 - t / dur, 5.0)
		var s := (randf() * 2.0 - 1.0) * 0.25 * env
		_playback.push_frame(Vector2(s, s))


func _muzzle_fx() -> void:
	# Visual flash: brief additive quad + light pulse, randomised each shot.
	_muzzle_flash.visible = true
	_muzzle_flash.rotation.z = randf() * TAU
	_muzzle_flash.scale = Vector3.ONE * randf_range(0.75, 1.35)
	_flash_light.light_energy = 2.2
	_flash_time = 0.05
	_push_gunshot(0.4)


## Synthesised gunshot pushed into the stream generator (no asset file).
func _push_gunshot(volume: float) -> void:
	if _playback == null:
		_playback = _gunshot.get_stream_playback()
	if _playback == null:
		return
	var sr := (_gunshot.stream as AudioStreamGenerator).mix_rate
	var dur := 0.16
	var total := int(sr * dur)
	var frames := mini(total, _playback.get_frames_available())
	for i in frames:
		var t := float(i) / sr
		var env := pow(1.0 - t / dur, 2.4)
		var noise := (randf() * 2.0 - 1.0) * 0.6
		var body := sin(t * TAU * 85.0) * 0.5
		var crack := sin(t * TAU * 320.0) * 0.2 * pow(1.0 - t / dur, 6.0)
		var s := (noise + body + crack) * env * volume
		_playback.push_frame(Vector2(s, s))
