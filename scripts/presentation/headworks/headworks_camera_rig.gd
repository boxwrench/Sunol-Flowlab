class_name HeadworksCameraRig
extends Camera3D

@export var pan_speed: float = 1.0
@export var key_pan_speed: float = 30.0 # units per second
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 10.0
@export var max_zoom: float = 150.0

# Current camera height/zoom
@export var height: float = 80.0
@export var target: Vector3 = Vector3(0.0, 0.0, 0.0)

var _is_dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	current = true
	_update_camera()

func _process(delta: float) -> void:
	var key_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		key_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		key_input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		key_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		key_input.x += 1.0
	
	if key_input != Vector2.ZERO:
		key_input = key_input.normalized()
		target.x += key_input.x * key_pan_speed * delta
		target.z += key_input.y * key_pan_speed * delta
		_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_dragging = true
				_last_mouse_pos = event.position
			else:
				_is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				height = max(min_zoom, height - zoom_speed * 5.0)
				_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				height = min(max_zoom, height + zoom_speed * 5.0)
				_update_camera()

	elif event is InputEventMouseMotion:
		if _is_dragging:
			var mouse_delta: Vector2 = event.position - _last_mouse_pos
			_last_mouse_pos = event.position
			
			var drag_scale := height / 800.0
			target.x -= mouse_delta.x * pan_speed * drag_scale
			target.z -= mouse_delta.y * pan_speed * drag_scale
			_update_camera()

func _update_camera() -> void:
	global_position = Vector3(target.x, height, target.z)
	look_at(target, Vector3.FORWARD)
