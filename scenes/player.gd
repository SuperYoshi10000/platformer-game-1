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
@onready
var BOSS: Node3D = get_node("%Boss")

# *Movement and speed
const SPEED = 2.5
const SPRINT_MULTIPLIER = 2
const SNEAK_MULTIPLIER = 0.5
const HIT_SPEED_MULTIPLIER = 2.5
const SLOWDOWN = 0.5
const GROUND = 0.2
const AIR = 0.05
const MIN_WALK_SPEED = 0.01
const MIN_RUN_SPEED = 3.75
const MIN_SPRINT_SPEED = 7.5
const FLOOR_MAX_ANGLE = deg_to_rad(65)
const SLIDE_NORMAL_MULTIPLIER = 0.5
const SLIDE_SPEED = 1.0
const DEBUG = false

# *Jumping
const SNEAK_JUMP_VELOCITY = 2.5
const JUMP_VELOCITY = 5.0
const BIG_JUMP_VELOCITY = 6.0
const JUMP_MAX_WAIT_TIME = 2
const JUMP_MAX_TIME = 10

# *Rotation
const ROTATION_SPEED = 10
const ANGLE_DEFAULT = 90
const DIRECTION_DEFAULT = 'r'

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
var enable_movement := true
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
var hit_time := 0

# Camera
var camera_min_x := CAMERA_X_OFFSET
var camera_max_x := INF
var camera_min_y := CAMERA_Y_OFFSET
var camera_max_y := INF
var camera_target: Vector3 = NAN_VECTOR3

var event: GameEvent = GameEvent.NORMAL

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
const HIT = "hit"

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
	if hit_time > 0:
		ANIMATION.current_animation = HIT
		return
	var speed: int = abs(velocity.x)
	if death_time > 0:
		if is_on_floor():
			ANIMATION.current_animation = HIT
		else:
			pass
	elif slide_time > 0:
		ANIMATION.current_animation = SLIDING
	elif is_on_floor():
		if sprinting and speed > MIN_SPRINT_SPEED:
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

func kill():
	lock_camera()
	death_time = 1

func knock(v := Vector3.UP):
	velocity = v
	enable_movement = false
	hit_time = 1

func trigger_events():
	if DEATH_AREA.overlaps_body(self):
		kill()
		
	if BOSS_AREA.overlaps_body(self):
		lock_camera(BOSS_AREA)
		BOSS_AREA_LEFT.disabled = false
		

func _ready():
	if DEBUG:
		position.x = 321
	floor_max_angle = FLOOR_MAX_ANGLE
	spawn()

func _physics_process(delta: float) -> void:
	if death_time > 0:
		velocity += get_gravity() * delta
		move_and_slide()
		death_time += 1
		if death_time > DEATH_DELAY:
			get_tree().reload_current_scene()
		return
		
	var on_floor := is_on_floor()
	var gravity := get_gravity()
	var speed_multiplier := GROUND if on_floor else AIR
	
	# Gravity
	if on_floor:
		if hit_time > 1:
			hit_time = 0
			enable_movement = true
		time_off_ground = 0
	else:
		time_off_ground += 1
	velocity += gravity * delta

	# Input
	var sliding = slide_time > 0
	var input_x := Input.get_axis("left", "right") if enable_movement else 0.0
	var input_z := Input.get_axis("up", "down") if enable_movement else 0.0
	
	sneaking = Input.is_action_pressed("down") and enable_movement
	var actually_sneaking = sneaking and not sliding
	var input_run = Input.is_action_pressed("run") and enable_movement
	sprinting = not sneaking and input_run
	
	var just_jumped := Input.is_action_just_pressed("jump") and time_off_ground < JUMP_MAX_WAIT_TIME
	var continue_jump := Input.is_action_pressed("jump") and 0 < jump_time and jump_time < JUMP_MAX_TIME
	jumping = enable_movement and (just_jumped or continue_jump)
	var big_jumping := jumping and actually_sneaking and input_run

	var moving: bool = abs(velocity.x) > MIN_WALK_SPEED

	if sprinting:
		input_x *= SPRINT_MULTIPLIER
	if actually_sneaking:
		input_x *= SNEAK_MULTIPLIER

	if hit_time > 0:
		hit_time += 1

	# Jumping
	if jumping:
		jump_time += 1
		velocity.y = (BIG_JUMP_VELOCITY if big_jumping and not moving and sign(velocity.x) == sign(input_x) else SNEAK_JUMP_VELOCITY) if sneaking else JUMP_VELOCITY
	else:
		jump_time = 0
		

	# Direction and sliding
	if on_floor:
		# Direction
		if input_x < 0:
			direction = 'l'
		elif input_x > 0:
			direction = 'r'
		# Sliding
		var normal = get_floor_normal()
		if (abs(normal.y) < abs(normal.x) and velocity.y < 0) or (abs(normal.x) > abs(normal.y) * SLIDE_NORMAL_MULTIPLIER and sneaking):
			normal.y = -normal.y
			velocity += normal * SLIDE_SPEED
			slide_time += 1
		else:
			if sliding and (abs(velocity.x) < 0.1 * MIN_WALK_SPEED or not sneaking):
				slide_time = 0

	if direction == 'l' and angle > -90:
		@warning_ignore("narrowing_conversion")
		angle = move_toward(angle, -90, ROTATION_SPEED)
	elif direction == 'r' and angle < 90:
		@warning_ignore("narrowing_conversion")
		angle = move_toward(angle, 90, ROTATION_SPEED)
	
	# X movement
	velocity.x -= velocity.x * SLOWDOWN * speed_multiplier
	if input_x and not sliding:
		velocity.x += input_x * SPEED * speed_multiplier
	elif actually_sneaking and on_floor:
		velocity.x *= SNEAK_MULTIPLIER
	# Long jumpings
	if jumping and big_jumping and moving:
		velocity.x = BIG_JUMP_VELOCITY * SPRINT_MULTIPLIER * sign(input_x)

	# Z movement (normally disabled)
		velocity.z = move_toward(velocity.z, 0, SLOWDOWN * speed_multiplier)
	if enable_z_movement and input_z:
		velocity.z += input_z * SPEED * speed_multiplier

	
	BODY.rotation_degrees.y = 180 + angle
	move_and_slide()
	
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider(0)
		var normal = collision.get_normal()
		if collider is CharacterBody3D:
			# Normal enemy
			if collider.has_node("enemy1"):
				if normal.x == 0 and normal.y > 0: # Hit from top
					collider.kill()
				else:
					ANIMATION.current_animation = HIT
					kill()
					velocity.y = 0
					velocity += normal
					break
			# Level 1 Boss
			if collider.has_node("boss_1"):
				if BOSS.phase == 0:
					if normal.x == 0: # Hit from top
						BOSS.start()
				elif BOSS.phase == 2:
					if normal.x == 0 and normal.y > 0: # Hit from top
						collider.hit()
						velocity.y = BIG_JUMP_VELOCITY
						velocity.x = sign(velocity.x) * HIT_SPEED_MULTIPLIER
					else:
						ANIMATION.current_animation = HIT
						kill()
						velocity.y = 0
						velocity += normal
						break
					pass
	
	# Rendering
	set_appearance()
	move_camera()
	
func _process(delta):
	trigger_events()
