extends CharacterBody3D



@onready
var BODY = get_node("Body")
@onready
var ANIMATION: AnimationPlayer = get_node("Body/AnimationPlayer")
@onready
var CAMERA: Camera3D = get_node("../Camera3D")
@onready
var DEATH_AREA: Area3D = get_node("../DeathArea")

@onready
var BOSS_AREA: Area3D = get_node("../BossArea")
@onready
var BOSS_AREA_LEFT: CollisionShape3D = get_node("../Barrier/BossAreaLeft")
@onready
var BOSS_AREA_RIGHT: CollisionShape3D = get_node("../Barrier/BossAreaRight")

# *Built in constants

# *Movement and speed
const SPEED = 2.5
const SPRINT_MULTIPLIER = 2
const SNEAK_MULTIPLIER = 0.5
const SLOWDOWN = 0.5
const GROUND = 0.2
const AIR = 0.05
const MIN_WALK_SPEED = 0.01
const MIN_RUN_SPEED = 3.75
const MIN_SPRINT_SPEED = 7.5
const FLOOR_MAX_ANGLE = deg_to_rad(65)
const SLIDE_SPEED = 0.4

# *Jumping
const SNEAK_JUMP_VELOCITY = 2.5
const JUMP_VELOCITY = 5.0
const BIG_JUMP_VELOCITY = 6.0
const JUMP_MAX_WAIT_TIME = 2
const JUMP_MAX_TIME = 10

# *Rotation
const ROTATION_SPEED = 10
const ANGLE_DEFAULT = 90
const DIRECTION_DEFAULT = LRDirection.RIGHT

# *Camera
const CAMERA_SPEED = 0.1
const MAX_X_OFFSET = 1.5
const MAX_Y_OFFSET = 1
const CAMERA_X_OFFSET = 8
const CAMERA_Y_OFFSET = 6
const CAMERA_AUTO_SPEED = 0.1

# *Time
const DEATH_DELAY = 30

# *Objects
const NAN_VECTOR3 = Vector3(NAN, NAN, NAN)

# Movement
var enable_z_movement := false
var angle := ANGLE_DEFAULT
var time_off_ground := 0
var slide_time := 0
var jump_time := 0
var direction := DIRECTION_DEFAULT
var sprinting := false
var sneaking := false 
var jumping := false
var death_time := 0

# Camera
var camera_min_x := CAMERA_X_OFFSET
var camera_max_x := INF
var camera_min_y := CAMERA_Y_OFFSET
var camera_max_y := INF
var camera_target: Vector3 = NAN_VECTOR3

var event: GameEvent = GameEvent.NORMAL

enum LRDirection {
	LEFT, RIGHT
}

enum GameEvent {
	NORMAL,
	DEATH,
	BOSS
}

const IDLE = "idle"
const WALKING = "walking"
const RUNNING = "running"
const SPRINTING = "sprinting"
const CROUCHING = "crouching"
const SNEAKING = "sneaking"
const JUMPING = "jumping"
const SPRINT_JUMPING = "sprint_jumping"
const FALLING = "falling"
const SLIDING = "sliding"

func unlock_camera():
	camera_target = NAN_VECTOR3
func lock_camera(target = CAMERA.position):
	if target is Node3D:
		target = target.position
	camera_target = Vector3(target)

func spawn():
	unlock_camera()

func move_camera():
	if camera_target.is_finite():
		CAMERA.position.x = move_toward(CAMERA.position.x, camera_target.x, CAMERA_AUTO_SPEED)
		CAMERA.position.y = move_toward(CAMERA.position.y, camera_target.y, CAMERA_AUTO_SPEED)
	else:
		if position.x - CAMERA.position.x > MAX_X_OFFSET:
			CAMERA.position.x += (position.x - CAMERA.position.x - MAX_X_OFFSET) * CAMERA_SPEED
		elif position.x - CAMERA.position.x < -MAX_X_OFFSET:
			CAMERA.position.x += (position.x - CAMERA.position.x + MAX_X_OFFSET) * CAMERA_SPEED
		if CAMERA.position.x < camera_min_x: CAMERA.position.x = camera_min_x
		if CAMERA.position.x > camera_max_x: CAMERA.position.x = camera_max_x
		if CAMERA.position.y < camera_min_y: CAMERA.position.y = camera_min_y
		if CAMERA.position.y > camera_max_y: CAMERA.position.y = camera_max_y
		
		if position.y - CAMERA.position.y > MAX_Y_OFFSET:
			CAMERA.position.y += (position.y - CAMERA.position.y - MAX_Y_OFFSET) * CAMERA_SPEED
		elif position.y - CAMERA.position.y < -MAX_Y_OFFSET:
			CAMERA.position.y += (position.y - CAMERA.position.y + MAX_Y_OFFSET) * CAMERA_SPEED

func set_appearance():
	var speed: int = abs(velocity.x)
	if is_on_floor():
		if slide_time > 0:
			ANIMATION.current_animation = SLIDING
		elif sprinting and speed > MIN_SPRINT_SPEED:
			ANIMATION.current_animation = SPRINTING
		elif sneaking:
			if speed > MIN_WALK_SPEED:
				ANIMATION.current_animation = SNEAKING
			else:
				ANIMATION.current_animation = CROUCHING
		elif speed > MIN_RUN_SPEED:
			ANIMATION.current_animation = RUNNING
		elif speed > MIN_WALK_SPEED:
			ANIMATION.current_animation = WALKING
		else:
			ANIMATION.current_animation = IDLE
	else:
		if abs(velocity.y) > 0 and jumping:
			if sprinting and speed > MIN_SPRINT_SPEED:
				ANIMATION.current_animation = SPRINT_JUMPING
			else:
				ANIMATION.current_animation = JUMPING
		elif time_off_ground < 2:
			ANIMATION.current_animation = FALLING

func trigger_events():
	if DEATH_AREA.overlaps_body(self):
		lock_camera()
		death_time = 1
		
	if BOSS_AREA.overlaps_body(self):
		lock_camera(BOSS_AREA)
		BOSS_AREA_LEFT.disabled = false
		

func _ready():
	floor_max_angle = FLOOR_MAX_ANGLE
	spawn()

func _physics_process(delta: float) -> void:
	if death_time > 0:
		velocity += get_gravity() * delta
		move_and_slide()
		death_time += 1
		if death_time > DEATH_DELAY:
			get_tree().reload_current_scene()
		
	var on_floor := is_on_floor()
	var gravity := get_gravity()
	var speed_multiplier := GROUND if on_floor else AIR
	
	# Add the gravity.
	if on_floor:
		time_off_ground = 0
	else:
		time_off_ground += 1
	velocity += gravity * delta
	
	


	# Get the input direction and handle the movement/deceleration.
	var input_x := Input.get_axis("left", "right")
	var input_z := Input.get_axis("up", "down")
	sneaking = Input.is_action_pressed("down")
	var input_run = Input.is_action_pressed("run")
	sprinting = not sneaking and input_run
	jumping = (Input.is_action_just_pressed("jump") and time_off_ground < JUMP_MAX_WAIT_TIME) or (Input.is_action_pressed("jump") and 0 < jump_time and jump_time < JUMP_MAX_TIME)
	var big_jumping := jumping and sneaking and input_run

	var moving: bool = abs(velocity.x) > MIN_WALK_SPEED

	if sprinting:
		input_x *= SPRINT_MULTIPLIER
	if sneaking:
		input_x *= SNEAK_MULTIPLIER
		

	# Handle jump.
	if jumping:
		jump_time += 1
		velocity.y = (BIG_JUMP_VELOCITY if big_jumping and not moving and sign(velocity.x) == sign(input_x) else SNEAK_JUMP_VELOCITY) if sneaking else JUMP_VELOCITY
	else:
		jump_time = 0
		

	# Direction and sliding
	if on_floor:
		if input_x < 0:
			direction = LRDirection.LEFT
		elif input_x > 0:
			direction = LRDirection.RIGHT
		var normal = get_floor_normal()
		print(normal)
		if normal.y > abs(normal.x) or (normal.y > 0 and sneaking):
			normal.y = -normal.y
			velocity += normal * SLIDE_SPEED
			slide_time += 1
		else:
			slide_time = 0

	if direction == LRDirection.LEFT and angle > -90:
		@warning_ignore("narrowing_conversion")
		angle = move_toward(angle, -90, ROTATION_SPEED)
	elif direction == LRDirection.RIGHT and angle < 90:
		@warning_ignore("narrowing_conversion")
		angle = move_toward(angle, 90, ROTATION_SPEED)
	
	# X movement
	velocity.x -= velocity.x * SLOWDOWN * speed_multiplier
	if input_x:
		velocity.x += input_x * SPEED * speed_multiplier
	elif sneaking:
		velocity.x *= SNEAK_MULTIPLIER
	if jumping and big_jumping and moving:
		velocity.x = BIG_JUMP_VELOCITY * SPRINT_MULTIPLIER * sign(input_x)

	# Z movement (normally disabled)
		velocity.z = move_toward(velocity.z, 0, SLOWDOWN * speed_multiplier)
	if enable_z_movement and input_z:
		velocity.z += input_z * SPEED * speed_multiplier

	
	BODY.rotation_degrees.y = 180 + angle
	move_and_slide()
	
	# Rendering
	set_appearance()
	move_camera()
	
func _process(delta):
	trigger_events()
