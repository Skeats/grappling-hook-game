extends CharacterBody3D

const WALK_SPEED = 5.0
const SPRINT_MODIFIER = 1.25
const ACCELERATION = 0.65
const AIR_ACCELERATION = 0.25
const JUMP_VELOCITY = 6.5

const MOUSE_SENSITIVITY = 0.2
const CAMERA_CONSTRAINT_UP = 80
const CAMERA_CONSTRAINT_DOWN = -90

# Grapple constants
const GRAPPLE_SPEED = 0.85
const GRAPPLE_RANGE = 15

var grapple_pos: Vector3 = Vector3.ZERO
var grapple_mesh: MeshInstance3D

@onready var head: Node3D = $Head
@onready var player_camera: Camera3D = %PlayerCamera

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("left", "right", "forward", "backward")

	# The unit vector pointing in the direction that the player would like to go, based on their input and
	# the direction that the camera is facing.
	var wish_direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# The horizontal velocity that the player wants to go
	var wish_velocity := wish_direction * WALK_SPEED

	# Preserve the current velocity by putting it in wish velocity
	wish_velocity.y = velocity.y

	# Sprint acceleration
	if Input.is_action_pressed("sprint") and is_on_floor():
		wish_velocity *= SPRINT_MODIFIER

	# Jump impulse
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y += JUMP_VELOCITY

	# Apply the grapple force
	if grapple_pos:
		var grapple_direction = global_position.direction_to(grapple_pos)
		var grapple_length = global_position.distance_to(grapple_pos)
		var grapple_time = grapple_length / GRAPPLE_SPEED
		var grapple_velocity = grapple_direction * (grapple_length / grapple_time)

		velocity += grapple_velocity

	# Add the gravity.
	if not is_on_floor():
		# This allows the velocity to be preserved if the player isn't giving a direction (inertia)
		# and reduces the players movement in the air
		if wish_velocity:
			velocity = velocity.move_toward(wish_velocity, AIR_ACCELERATION)
		velocity += get_gravity() * 1.5 * delta
	else:
		velocity = velocity.move_toward(wish_velocity, ACCELERATION)

	#print("Wish velocity: %s" % wish_velocity)
	#print("Velocity: %s" % velocity)
	move_and_slide()

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
		print("Grapple intersected with object at %s" % result.position)
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
