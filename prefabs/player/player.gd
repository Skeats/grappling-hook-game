extends CharacterBody3D

const MAX_SPEED_AIR = 2.0
const MAX_SPEED_GROUND = 6.0
const MAX_ACCELERATION = 10 * MAX_SPEED_GROUND
const GRAVITY = 15.34
const STOP_SPEED = 2.5
const JUMP_IMPULSE = sqrt(2 * GRAVITY * 0.85)
const JUMP_FRAME_WINDOW = 4

const SPRINT_MODIFIER = 1.25

const MOUSE_SENSITIVITY = 0.2
const CAMERA_CONSTRAINT_UP = 80
const CAMERA_CONSTRAINT_DOWN = -90

const FOV = 90
const SPRINT_FOV = FOV + 5
const SPRINT_FOV_SCALING = 0.1

# Grapple constants
const GRAPPLE_SPEED = 0.85
const GRAPPLE_RANGE = 15

var grapple_pos: Vector3 = Vector3.ZERO
var grapple_mesh: MeshInstance3D

var jump_frame_timer: int = 0
var friction: float = 6.0

@onready var head: Node3D = $Head
@onready var player_camera: Camera3D = %PlayerCamera

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player_camera.fov = FOV

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("left", "right", "forward", "backward")

	var wish_direction: Vector3 = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var wish_jump: bool = Input.is_action_just_pressed("jump")

	if jump_frame_timer > 0:
		jump_frame_timer -= 1

	if is_on_floor():
		if wish_jump:
			velocity.y = JUMP_IMPULSE
			velocity = accelerate(wish_direction, MAX_SPEED_AIR, delta)
			wish_jump = false
			jump_frame_timer = JUMP_FRAME_WINDOW
		elif jump_frame_timer == 0:
			var speed = velocity.length()

			if speed != 0:
				var control = max(STOP_SPEED, speed)
				var drop = control * friction * delta

				velocity *= max(speed - drop, 0) / speed
			velocity = accelerate(wish_direction, MAX_SPEED_GROUND, delta)
	else:
		velocity.y -= GRAVITY * delta
	velocity = accelerate(wish_direction, MAX_SPEED_AIR, delta)

	# Apply the grapple force
	if grapple_pos:
		var grapple_direction: Vector3 = global_position.direction_to(grapple_pos)
		var grapple_length: float = global_position.distance_to(grapple_pos)
		var grapple_time: float = grapple_length / GRAPPLE_SPEED
		var grapple_velocity: Vector3 = grapple_direction * (grapple_length / grapple_time)

		velocity += grapple_velocity

	#print("Wish velocity: %s" % wish_velocity)
	print("Speed: %s" % velocity.length())
	move_and_slide()

func accelerate(wish_dir: Vector3, max_speed: float, delta):
	var current_speed = velocity.dot(wish_dir)

	var add_speed = clamp(max_speed - current_speed, 0, MAX_ACCELERATION * delta)

	return velocity + add_speed * wish_dir

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player_camera.rotate_x(deg_to_rad(-event.relative.y * MOUSE_SENSITIVITY))
		head.rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENSITIVITY))

		player_camera.rotation_degrees.x = clamp(player_camera.rotation_degrees.x, CAMERA_CONSTRAINT_DOWN, CAMERA_CONSTRAINT_UP)

	if event.is_action_pressed("grapple"):
		grapple_pos = try_send_grapple()
		if grapple_pos and not grapple_mesh:
			draw_grapple(grapple_pos)

	if event.is_action_released("grapple"):
		if grapple_mesh:
			grapple_mesh.queue_free()
		grapple_pos = Vector3.ZERO

	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.is_released():
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func try_send_grapple() -> Vector3:
	var space_state = get_world_3d().direct_space_state

	var end = player_camera.global_position + -player_camera.global_transform.basis.z * GRAPPLE_RANGE
	var query = PhysicsRayQueryParameters3D.create(player_camera.global_position, end)
	query.collision_mask = 0b10
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	else:
		return Vector3.ZERO

func draw_grapple(pos: Vector3) -> void:
	grapple_mesh = MeshInstance3D.new()
	grapple_mesh.mesh = SphereMesh.new()
	grapple_mesh.mesh.height = 0.2
	grapple_mesh.mesh.radius = 0.1
	get_tree().current_scene.add_child(grapple_mesh)
	grapple_mesh.global_position = pos
