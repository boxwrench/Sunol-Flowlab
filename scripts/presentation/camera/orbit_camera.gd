class_name OrbitCamera
extends Camera3D

@export var target: Vector3 = Vector3.ZERO
@export var distance: float = 15.0
@export var yaw: float = 45.0 # Horizontal angle in degrees
@export var pitch: float = -30.0 # Vertical angle in degrees

@export var zoom_speed: float = 1.0
@export var rotate_speed: float = 0.3
@export var pan_speed: float = 0.02

var _initial_target: Vector3
var _initial_distance: float
var _initial_yaw: float
var _initial_pitch: float

var _is_rotating: bool = false
var _is_panning: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_initial_target = target
	_initial_distance = distance
	_initial_yaw = yaw
	_initial_pitch = pitch
	_update_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_rotating = event.pressed
			_last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
			_last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = max(2.0, distance - zoom_speed)
			_update_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = min(150.0, distance + zoom_speed)
			_update_position()
			
	elif event is InputEventMouseMotion:
		var delta: Vector2 = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		
		if _is_rotating:
			yaw -= delta.x * rotate_speed
			pitch = clamp(pitch - delta.y * rotate_speed, -85.0, 5.0) # restrict pitch so we don't go below ground
			_update_position()
		elif _is_panning:
			# Pan camera relative to its current orientation
			var right := global_transform.basis.x
			var up := global_transform.basis.y
			# Project panning to ground plane or use camera basis
			target += (-right * delta.x + up * delta.y) * pan_speed
			_update_position()
			
	elif event is InputEventKey:
		if event.keycode == KEY_R and event.pressed:
			reset_camera()

func reset_camera() -> void:
	target = _initial_target
	distance = _initial_distance
	yaw = _initial_yaw
	pitch = _initial_pitch
	_update_position()

func _update_position() -> void:
	var yaw_rad := deg_to_rad(yaw)
	var pitch_rad := deg_to_rad(pitch)
	
	var offset := Vector3(
		sin(yaw_rad) * cos(pitch_rad),
		sin(pitch_rad),
		cos(yaw_rad) * cos(pitch_rad)
	) * distance
	
	global_position = target + offset
	look_at(target, Vector3.UP)
