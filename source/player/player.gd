extends CharacterBody3D

const SPEED := 6.0
const JUMP_VELOCITY := 5.0

const MAG_SIZE := 12
const RESERVE_MAX := 96
const RELOAD_TICKS := 51

@export var bullet_scene: PackedScene = preload("res://source/weapons/bullet.tscn")

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _prev_jump_held := false
var _prev_fire_held := false

var _mag := MAG_SIZE
var _reserve := RESERVE_MAX - MAG_SIZE
var _reloading := false
var _reload_ticks_left := 0

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _input: PlayerInput = $Input
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _weapon: Node3D = $Head/Camera3D/WeaponHolder
@onready var _muzzle: Marker3D = $Head/Camera3D/WeaponHolder/Muzzle
@onready var _muzzle_flash: MeshInstance3D = $Head/Camera3D/WeaponHolder/MuzzleFlash
@onready var _flash_light: OmniLight3D = $Head/Camera3D/WeaponHolder/FlashLight
@onready var _mag_mesh: MeshInstance3D = $Head/Camera3D/WeaponHolder/MagMesh
@onready var _hud: CanvasLayer = $HUD
@onready var _hud_ammo: Label = $HUD/AmmoLabel
@onready var _hud_bar: ProgressBar = $HUD/ReloadBar

var _weapon_base_pos := Vector3.ZERO
var _weapon_base_rot := Vector3.ZERO
var _mag_base_pos := Vector3.ZERO
var _mag_base_rot := Vector3.ZERO
var _bob_time := 0.0
var _mouse_delta := Vector2.ZERO
var _sway := Vector3.ZERO
var _recoil := 0.0
var _flash_time := 0.0

var _is_local_view := false


func set_local_view(is_local: bool) -> void:
	_is_local_view = is_local
	_camera.current = is_local
	_mesh.visible = not is_local
	_hud.visible = is_local


func _ready() -> void:
	add_to_group("player")
	_camera.current = _is_local_view
	_hud.visible = _is_local_view
	_weapon_base_pos = _weapon.position
	_weapon_base_rot = _weapon.rotation
	_mag_base_pos = _mag_mesh.position
	_mag_base_rot = _mag_mesh.rotation
	_update_hud()
	if _is_local_view:
		_mesh.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_local_view:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += event.relative
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _rollback_tick(delta: float, _tick: int, _is_fresh: bool) -> void:
	rotation.y = _input.yaw
	_head.rotation.x = _input.pitch

	var jump_edge := _input.jump_pressed and not _prev_jump_held
	_prev_jump_held = _input.jump_pressed

	if not is_on_floor():
		velocity.y -= _gravity * delta
	if jump_edge and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var dir := (transform.basis * Vector3(_input.movement.x, 0.0, _input.movement.y)).normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

	_tick_weapon(_is_fresh)


func _tick_weapon(is_fresh: bool) -> void:
	var fire_edge := _input.fire_pressed and not _prev_fire_held
	_prev_fire_held = _input.fire_pressed

	if _reloading:
		_reload_ticks_left -= 1
		if _reload_ticks_left <= 0:
			_finish_reload()
		return

	if _input.reload_pressed and _mag < MAG_SIZE and _reserve > 0:
		_start_reload()
		return

	if fire_edge:
		if _mag <= 0:
			_start_reload()
			return
		_mag -= 1
		if is_fresh:
			_spawn_bullet()
			_muzzle_fx()
		if _mag <= 0:
			_start_reload()


func _spawn_bullet() -> void:
	if bullet_scene == null:
		return
	var bullet := bullet_scene.instantiate()
	var container: Node = get_tree().current_scene
	if container == null:
		container = get_parent()
	container.add_child(bullet)
	bullet.global_position = _muzzle.global_position
	bullet.launch(-_camera.global_transform.basis.z)


func _start_reload() -> void:
	_reloading = true
	_reload_ticks_left = RELOAD_TICKS


func _finish_reload() -> void:
	var need := MAG_SIZE - _mag
	var take := mini(need, _reserve)
	_mag += take
	_reserve -= take
	_reloading = false


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash_light.light_energy = lerpf(_flash_light.light_energy, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		if _flash_time <= 0.0:
			_muzzle_flash.visible = false
			_flash_light.light_energy = 0.0

	if not _is_local_view:
		return

	_update_hud()

	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and planar_speed > 0.5

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

	var target_sway := Vector3(-_mouse_delta.x, _mouse_delta.y, 0.0) * 0.00035
	target_sway.x = clampf(target_sway.x, -0.04, 0.04)
	target_sway.y = clampf(target_sway.y, -0.04, 0.04)
	_sway = _sway.lerp(target_sway, clampf(delta * 12.0, 0.0, 1.0))
	_mouse_delta = Vector2.ZERO

	_recoil = lerpf(_recoil, 0.0, clampf(delta * 9.0, 0.0, 1.0))

	var reload_pos := Vector3.ZERO
	var reload_rot := Vector3.ZERO
	if _reloading:
		var p := 1.0 - clampf(float(_reload_ticks_left) / float(RELOAD_TICKS), 0.0, 1.0)
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


func _muzzle_fx() -> void:
	_recoil = minf(_recoil + 0.038, 0.08)
	_muzzle_flash.visible = true
	_muzzle_flash.rotation.z = randf() * TAU
	_muzzle_flash.scale = Vector3.ONE * randf_range(0.75, 1.35)
	_flash_light.light_energy = 2.2
	_flash_time = 0.05


func _update_hud() -> void:
	if _reloading:
		_hud_ammo.text = "RELOADING"
		_hud_bar.visible = true
		_hud_bar.value = 1.0 - clampf(float(_reload_ticks_left) / float(RELOAD_TICKS), 0.0, 1.0)
	else:
		_hud_ammo.text = "%d / %d" % [_mag, _reserve]
		_hud_bar.visible = false
