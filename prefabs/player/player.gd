extends CharacterBody3D

const MAX_SPEED_AIR = 1.2
const MAX_SPEED_GROUND = 6.0
const MAX_ACCELERATION = 10 * MAX_SPEED_GROUND
const GRAVITY = 15.34
const STOP_SPEED = 2.5
const JUMP_IMPULSE = sqrt(2 * GRAVITY * 0.85)
const JUMP_FRAME_WINDOW = 4 ## Frame leniency before the player is counted as "on the ground" again

## Vertial camera constraints
const CAMERA_CONSTRAINT_UP = 80
const CAMERA_CONSTRAINT_DOWN = -90

## Things that will be in settings
var mouse_sensitivity = 0.2
var fov = 90 :
	set(value):
		fov = value
		player_camera.fov = fov

## Grapple variables (in case we wanna do upgrades or something
var grapple_range: float = 15.0 :
	set(value):
		grapple_range = value
		grapple_cast.target_position.z = -grapple_range
var grapple_speed: float = 60.0

var grapple_pos: Vector3 = Vector3.ZERO
var grapple_mesh: MeshInstance3D
var is_grappling: bool = false

var jump_frame_timer: int = 0
var friction: float = 6.0

@onready var head: Node3D = $Head
@onready var player_camera: Camera3D = %PlayerCamera
@onready var player_synchronizer: MultiplayerSynchronizer = %PlayerSynchronizer
@onready var grapple_cast: RayCast3D = $Head/PlayerCamera/GrappleCast
@onready var crosshair: Control

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int(), true) # Idk why the engine wants this in _enter_tree so badly but it does

func _ready() -> void:
	get_tree().current_scene.connect("crosshair_changed", _crosshair_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player_camera.fov = fov
	grapple_cast.target_position.z = -grapple_range

	# We can't have just ANYONE taking over our player
	if is_multiplayer_authority():
		player_camera.current = true

		if Network.connected_players.has(name.to_int()):
			%Name.text = Network.connected_players[name.to_int()].name
		else:
			%Name.text = Network.player_info.name

func _crosshair_changed(value) -> void:
	crosshair = value

func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority(): return

	# Get player input
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var wish_direction: Vector3 = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var wish_jump: bool = Input.is_action_just_pressed("jump")

	# This gives a couple frames of leniency when bhopping
	if jump_frame_timer > 0:
		jump_frame_timer -= 1

	# Source movement makes me horny
	if is_on_floor():
		if wish_jump:
			velocity.y = JUMP_IMPULSE
			velocity = accelerate(wish_direction, MAX_SPEED_AIR, delta)
			wish_jump = false
			jump_frame_timer = JUMP_FRAME_WINDOW
		elif jump_frame_timer == 0: # Frame leniency cuz i'm a pussy
			var speed = velocity.length()

			if speed != 0:
				var control = max(STOP_SPEED, speed)
				var drop = control * friction * delta

				velocity *= max(speed - drop, 0) / speed
			velocity = accelerate(wish_direction, MAX_SPEED_GROUND, delta)
	else:
		velocity.y -= GRAVITY * delta
		velocity = accelerate(wish_direction, MAX_SPEED_AIR, delta) # Where all the magic happens :3

	if grapple_cast.is_colliding() or is_grappling:
		var grapple_length: float = global_position.distance_to(grapple_pos)
		if crosshair and crosshair.name == "GrappleHook" and grapple_pos:
			crosshair.outer_element_distance = grapple_length / grapple_range * 40

		if is_grappling:
			var grapple_direction: Vector3 = global_position.direction_to(grapple_pos)
			var grapple_velocity: Vector3 = grapple_direction * grapple_speed

			var grapple_difference: Vector3 = (grapple_velocity - velocity)
			#var grapple_time: float = grapple_length / grapple_speed
			#var grapple_velocity: Vector3 = grapple_direction * (grapple_length / grapple_time)

			velocity += grapple_difference * delta
		else:
			grapple_pos = grapple_cast.get_collision_point()
	else:
		grapple_pos = Vector3.ZERO
		crosshair.outer_element_distance = 60

	move_and_slide()

func accelerate(wish_dir: Vector3, max_speed: float, delta):
	var current_speed = velocity.dot(wish_dir)

	var add_speed = clamp(max_speed - current_speed, 0, MAX_ACCELERATION * delta)

	return velocity + add_speed * wish_dir

func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority(): return

	# Camera movement
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player_camera.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		head.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))

		player_camera.rotation_degrees.x = clamp(player_camera.rotation_degrees.x, CAMERA_CONSTRAINT_DOWN, CAMERA_CONSTRAINT_UP)

	# Grapple
	if event.is_action_pressed("grapple") and grapple_pos:
		is_grappling = true
		if crosshair and crosshair.name == "GrappleHook":
			crosshair.inner_element_distance = 5
		if grapple_pos and not grapple_mesh:
			draw_grapple(grapple_pos)

	if event.is_action_released("grapple"):
		if grapple_mesh:
			grapple_mesh.queue_free()
		if crosshair and crosshair.name == "GrappleHook":
			crosshair.inner_element_distance = 10
		is_grappling = false

## Mostly just for testing
func draw_grapple(pos: Vector3) -> void:
	grapple_mesh = MeshInstance3D.new()
	grapple_mesh.mesh = SphereMesh.new()
	grapple_mesh.mesh.height = 0.2
	grapple_mesh.mesh.radius = 0.1
	get_tree().current_scene.add_child(grapple_mesh)
	grapple_mesh.global_position = pos
